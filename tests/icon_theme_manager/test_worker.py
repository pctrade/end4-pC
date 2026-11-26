from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
WORKER = ROOT / "scripts" / "theming" / "icon-theme-worker.py"

from helpers import (  # noqa: E402
    make_theme,
    manifest_payload,
    request_payload,
    selection_payload,
    svg,
    write_json,
)


class WorkerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.stack = ExitStack()
        self.tmp = self.stack.enter_context(tempfile.TemporaryDirectory())
        self.root = Path(self.tmp)
        self.home = self.root / "home"
        self.data = self.root / "data"
        self.icons = self.data / "icons"
        self.state = self.root / "state"
        self.empty = self.root / "empty"
        for path in (self.home, self.icons, self.state, self.empty):
            path.mkdir(parents=True, exist_ok=True)
        self.stack.enter_context(
            patch.dict(
                os.environ,
                {
                    "HOME": str(self.home),
                    "XDG_DATA_HOME": str(self.data),
                    "XDG_DATA_DIRS": str(self.empty),
                    "XDG_STATE_HOME": str(self.root / "xdg-state"),
                },
            )
        )
        self.base = make_theme(
            self.icons,
            "Tela-dark",
            {"16/places/folder.svg": svg(extra='<rect fill="#5292e2"/>')},
        )
        self.record = self.root / "activate.log"
        self.manager = self.root / "fake-manager.sh"
        self.manager.write_text(
            "#!/usr/bin/env bash\n"
            f'printf "%s\\n" "$*" >> "{self.record}"\n'
            "exit 0\n",
            encoding="utf-8",
        )
        self.manager.chmod(0o755)

    def tearDown(self) -> None:
        self.stack.close()

    # ------------------------------------------------------------------ helpers
    def write_state(
        self,
        *,
        request_id: str = "req-1",
        selection_id: str = "sel-1",
        out: str = "Tela-Dynamic-Dark-e53935",
        accent: str = "#e53935",
        keep: int = 6,
    ) -> dict:
        request = request_payload(
            request_id=request_id,
            selection_id=selection_id,
            theme="Tela",
            base="Tela-dark",
            base_path=self.base,
            out=out,
            accent=accent,
            keep=keep,
        )
        write_json(self.state / "request.json", request)
        write_json(self.state / "selection.json", selection_payload(selection_id=selection_id))
        return request

    def run_worker(self) -> subprocess.CompletedProcess:
        return subprocess.run(
            [
                sys.executable,
                str(WORKER),
                "--request-file",
                str(self.state / "request.json"),
                "--icons-dir",
                str(self.icons),
                "--state-dir",
                str(self.state),
                "--debounce",
                "0",
                "--manager",
                str(self.manager),
            ],
            check=False,
            capture_output=True,
            text=True,
        )

    def activations(self) -> list[str]:
        if not self.record.exists():
            return []
        return [line for line in self.record.read_text().splitlines() if line.strip()]

    # -------------------------------------------------------------------- tests
    def test_generates_and_activates(self) -> None:
        self.write_state()
        result = self.run_worker()
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)

        out_dir = self.icons / "Tela-Dynamic-Dark-e53935"
        manifest = json.loads((out_dir / ".icon-theme-meta.json").read_text())
        self.assertTrue(manifest["generated"])
        self.assertEqual(manifest["adapter"], "tela")
        self.assertEqual(manifest["base"], "Tela-dark")
        self.assertEqual(manifest["accent"], "#e53935")

        folder = (out_dir / "16/places/folder.svg").read_text()
        self.assertIn(".ColorScheme-Highlight { color:#e53935; }", folder)
        self.assertIn('<rect fill="#5292e2"/>', folder, "source data untouched by adapter test fixture")

        self.assertEqual(
            self.activations(),
            ["--activate Tela-Dynamic-Dark-e53935 --request-id req-1 --selection-id sel-1"],
        )
        status = json.loads((self.state / "status.json").read_text())
        self.assertEqual(status["active"], "Tela-Dynamic-Dark-e53935")
        self.assertIsNone(status["pending"])

    def test_stale_selection_does_not_generate(self) -> None:
        self.write_state(selection_id="sel-old")
        write_json(self.state / "selection.json", selection_payload(selection_id="sel-new"))
        result = self.run_worker()
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.icons / "Tela-Dynamic-Dark-e53935").exists())
        self.assertEqual(self.activations(), [])

    def test_same_request_is_not_processed_twice(self) -> None:
        self.write_state()
        self.assertEqual(self.run_worker().returncode, 0)
        self.assertEqual(self.run_worker().returncode, 0)
        self.assertEqual(len(self.activations()), 1)

    def test_cache_hit_does_not_rebuild(self) -> None:
        self.write_state()
        self.assertEqual(self.run_worker().returncode, 0)
        manifest_path = self.icons / "Tela-Dynamic-Dark-e53935/.icon-theme-meta.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["createdAt"] = "2000-01-01T00:00:00Z"
        write_json(manifest_path, manifest)

        self.write_state(request_id="req-2", selection_id="sel-2")
        self.assertEqual(self.run_worker().returncode, 0)
        self.assertEqual(
            json.loads(manifest_path.read_text())["createdAt"],
            "2000-01-01T00:00:00Z",
        )
        self.assertEqual(len(self.activations()), 2)

    def test_invalid_request_is_rejected(self) -> None:
        self.write_state()
        request_path = self.state / "request.json"
        request = json.loads(request_path.read_text())
        request["accent"] = "not-a-hex"
        write_json(request_path, request)
        result = self.run_worker()
        self.assertEqual(result.returncode, 4)
        self.assertFalse((self.icons / "Tela-Dynamic-Dark-e53935").exists())
        status = json.loads((self.state / "status.json").read_text())
        self.assertEqual(status["state"], "error")

    def test_prune_keeps_newest_and_protected(self) -> None:
        for index, suffix in enumerate(("111111", "222222", "333333", "444444"), start=1):
            directory = self.icons / f"Tela-Dynamic-Dark-{suffix}"
            directory.mkdir()
            write_json(
                directory / ".icon-theme-meta.json",
                manifest_payload(
                    base="Tela-dark",
                    base_path=self.base,
                    out=directory.name,
                    accent=f"#{suffix}",
                    created_at=f"2020-01-0{index}T00:00:00Z",
                ),
            )

        self.write_state(keep=2)
        self.assertEqual(self.run_worker().returncode, 0)
        remaining = {
            entry.name
            for entry in self.icons.iterdir()
            if entry.is_dir() and entry.name.startswith("Tela-Dynamic")
        }
        self.assertEqual(
            remaining,
            {"Tela-Dynamic-Dark-e53935", "Tela-Dynamic-Dark-444444"},
        )

    def test_prune_protects_currently_active_theme(self) -> None:
        active = self.icons / "Tela-Dynamic-Dark-111111"
        old = self.icons / "Tela-Dynamic-Dark-222222"
        for index, directory in enumerate((active, old), start=1):
            directory.mkdir()
            write_json(
                directory / ".icon-theme-meta.json",
                manifest_payload(
                    base="Tela-dark",
                    base_path=self.base,
                    out=directory.name,
                    accent=f"#11111{index}",
                    created_at=f"2020-01-0{index}T00:00:00Z",
                ),
            )
        write_json(
            self.state / "status.json",
            {"format": 1, "state": "idle", "active": active.name},
        )
        self.write_state(
            request_id="req-new",
            selection_id="sel-new",
            out="Tela-Dynamic-Dark-e53935",
            keep=1,
        )
        self.assertEqual(self.run_worker().returncode, 0)

        remaining = {
            entry.name
            for entry in self.icons.iterdir()
            if entry.is_dir() and entry.name.startswith("Tela-Dynamic")
        }
        self.assertIn(active.name, remaining, "the live theme must never be pruned")
        self.assertIn("Tela-Dynamic-Dark-e53935", remaining)
        self.assertNotIn(old.name, remaining)

    def test_invalid_existing_target_is_replaced(self) -> None:
        target = self.icons / "Tela-Dynamic-Dark-e53935"
        target.mkdir()
        (target / "junk.txt").write_text("stale")
        self.write_state()
        self.assertEqual(self.run_worker().returncode, 0)
        self.assertFalse((target / "junk.txt").exists())
        self.assertTrue((target / ".icon-theme-meta.json").is_file())

    def test_cancelled_request_is_not_built(self) -> None:
        self.write_state()
        request_path = self.state / "request.json"
        request = json.loads(request_path.read_text())
        request["cancelled"] = True
        write_json(request_path, request)
        result = self.run_worker()
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.icons / "Tela-Dynamic-Dark-e53935").exists())


if __name__ == "__main__":
    unittest.main()
