from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
MANAGER = ROOT / "scripts" / "theming" / "icon-theme-manager.sh"

from helpers import make_theme, manifest_payload, request_payload, selection_payload, svg, write_json  # noqa: E402


class ManagerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.stack = ExitStack()
        self.tmp = self.stack.enter_context(tempfile.TemporaryDirectory())
        self.root = Path(self.tmp)
        self.home = self.root / "home"
        self.config = self.root / "config"
        self.data = self.root / "data"
        self.state_home = self.root / "xdg-state"
        self.icons = self.data / "icons"
        self.state = self.state_home / "quickshell/user/generated/icons"
        self.empty = self.root / "empty"
        for path in (self.home, self.config, self.icons, self.state, self.empty):
            path.mkdir(parents=True, exist_ok=True)

        self.stack.enter_context(
            patch.dict(
                os.environ,
                {
                    "HOME": str(self.home),
                    "XDG_CONFIG_HOME": str(self.config),
                    "XDG_DATA_HOME": str(self.data),
                    "XDG_DATA_DIRS": str(self.empty),
                    "XDG_STATE_HOME": str(self.state_home),
                },
            )
        )

        self.base = make_theme(
            self.icons,
            "Tela-dark",
            {"16/places/folder.svg": svg(extra='<rect fill="#5294e2"/>')},
        )
        make_theme(
            self.icons,
            "Tela-light",
            {"16/places/folder.svg": svg(rule="#4285f4")},
        )
        self.scss = self.state_home / "quickshell/user/generated/material_colors.scss"
        self.scss.write_text("$primary: #e53935;\n", encoding="utf-8")

        self.apply_log = self.root / "apply.log"
        self.apply_script = self.root / "fake-apply.sh"
        self.apply_script.write_text(
            "#!/usr/bin/env bash\n" f'printf "%s\\n" "$*" >> "{self.apply_log}"\n' "exit 0\n",
            encoding="utf-8",
        )
        self.apply_script.chmod(0o755)

        self.kmyc = self.config / "kde-material-you-colors/config.conf"
        self.write_config(dynamic=False)

    def tearDown(self) -> None:
        self.stack.close()

    # ------------------------------------------------------------------ helpers
    def write_config(self, *, dynamic: bool, follow: bool = True, override: bool = True, theme: str = "Tela") -> None:
        path = self.config / "illogical-impulse/config.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        write_json(
            path,
            {
                "appearance": {
                    "icons": {
                        "theme": theme,
                        "followScheme": follow,
                        "dynamicColor": dynamic,
                        "preventBreezeOverride": override,
                        "keepGenerated": 6,
                    }
                }
            },
        )

    def write_kmyc(self, light: str = "breeze-plus", dark: str = "breeze-plus-dark") -> None:
        self.kmyc.parent.mkdir(parents=True, exist_ok=True)
        self.kmyc.write_text(
            "[CUSTOM]\n"
            f"iconslight = {light}\n"
            f"iconsdark = {dark}\n",
            encoding="utf-8",
        )

    def run_manager(self, *args: str, no_spawn: bool = True) -> subprocess.CompletedProcess:
        env = {
            **os.environ,
            "ICON_MANAGER_APPLY_CMD": str(self.apply_script),
            "ICON_MANAGER_NO_SPAWN": "1" if no_spawn else "0",
        }
        return subprocess.run(
            ["bash", str(MANAGER), *args],
            check=False,
            capture_output=True,
            text=True,
            env=env,
        )

    def applied(self) -> list[str]:
        if not self.apply_log.exists():
            return []
        return [line for line in self.apply_log.read_text().splitlines() if line.strip()]

    def status(self) -> dict:
        return json.loads((self.state / "status.json").read_text())

    def selection(self) -> dict:
        return json.loads((self.state / "selection.json").read_text())

    def make_generated(self, out: str = "Tela-Dynamic-Dark-e53935") -> Path:
        directory = self.icons / out
        directory.mkdir(parents=True, exist_ok=True)
        write_json(
            directory / ".icon-theme-meta.json",
            manifest_payload(base="Tela-dark", base_path=self.base, out=out),
        )
        return directory

    # -------------------------------------------------------------------- tests
    def test_dynamic_off_applies_base_theme(self) -> None:
        result = self.run_manager("--apply", "--mode", "dark")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.applied(), ["--set-icons Tela-dark"])
        status = self.status()
        self.assertEqual(status["state"], "idle")
        self.assertEqual(status["active"], "Tela-dark")
        self.assertFalse((self.icons / "Tela-Dynamic-Dark-e53935").exists())

    def test_dynamic_on_queues_generation(self) -> None:
        self.write_config(dynamic=True)
        result = self.run_manager("--apply", "--mode", "dark")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.applied(), ["--set-icons Tela-dark"])
        request = json.loads((self.state / "request.json").read_text())
        self.assertEqual(request["out"], "Tela-Dynamic-Dark-e53935")
        self.assertEqual(request["adapter"], "tela")
        self.assertEqual(request["accent"], "#e53935")
        self.assertFalse(request["cancelled"])
        status = self.status()
        self.assertEqual(status["state"], "queued")
        self.assertEqual(status["pending"]["out"], "Tela-Dynamic-Dark-e53935")

    def test_generated_cache_is_used_immediately(self) -> None:
        self.write_config(dynamic=True)
        self.make_generated()
        result = self.run_manager("--apply", "--mode", "dark")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.applied(), ["--set-icons Tela-Dynamic-Dark-e53935"])
        self.assertEqual(self.status()["active"], "Tela-Dynamic-Dark-e53935")
        self.assertFalse((self.state / "request.json").exists())

    def test_override_on_syncs_and_off_does_not(self) -> None:
        self.write_kmyc()
        self.write_config(dynamic=False)
        self.assertEqual(self.run_manager("--apply", "--mode", "dark").returncode, 0)
        contents = self.kmyc.read_text()
        self.assertIn("iconslight = Tela-light", contents)
        self.assertIn("iconsdark = Tela-dark", contents)
        original = (self.state / "kmyc-original").read_text()
        self.assertIn("iconslight = breeze-plus", original)

        self.write_config(dynamic=False, override=False)
        self.kmyc.write_text(
            "[CUSTOM]\niconslight = user-choice\niconsdark = user-choice-dark\n",
            encoding="utf-8",
        )
        self.assertEqual(self.run_manager("--apply", "--mode", "dark").returncode, 0)
        self.assertIn("iconslight = user-choice", self.kmyc.read_text())

    def test_restore_returns_original_values(self) -> None:
        self.write_kmyc()
        self.assertEqual(self.run_manager("--apply", "--mode", "dark").returncode, 0)
        result = self.run_manager("--restore-kmyc")
        self.assertEqual(result.returncode, 0, result.stderr)
        contents = self.kmyc.read_text()
        self.assertIn("iconslight = breeze-plus", contents)
        self.assertIn("iconsdark = breeze-plus-dark", contents)
        self.assertIn("managed = false", (self.state / "kmyc-state").read_text())
        self.assertEqual(self.applied()[-1], "--set-icons breeze-plus-dark")

    def test_restore_handles_duplicate_keys(self) -> None:
        self.write_kmyc()
        self.assertEqual(self.run_manager("--apply", "--mode", "dark").returncode, 0)
        with self.kmyc.open("a", encoding="utf-8") as handle:
            handle.write("iconslight = appended\n")
        self.assertEqual(self.run_manager("--restore-kmyc").returncode, 0)
        # The last active occurrence is the effective one for configparser.
        active = [
            line.split("=", 1)[1].strip()
            for line in self.kmyc.read_text().splitlines()
            if line.strip().startswith("iconslight")
        ]
        self.assertEqual(active[-1], "breeze-plus")

    def test_restore_uses_effective_original_value(self) -> None:
        self.kmyc.parent.mkdir(parents=True, exist_ok=True)
        self.kmyc.write_text(
            "[CUSTOM]\niconslight = first\niconslight = effective\niconsdark = dark\n",
            encoding="utf-8",
        )
        self.assertEqual(self.run_manager("--apply", "--mode", "dark").returncode, 0)
        self.assertIn("iconslight = effective", (self.state / "kmyc-original").read_text())
        self.assertEqual(self.run_manager("--restore-kmyc").returncode, 0)
        active = [
            line.split("=", 1)[1].strip()
            for line in self.kmyc.read_text().splitlines()
            if line.strip().startswith("iconslight")
        ]
        self.assertEqual(active[-1], "effective")

    def test_restore_removes_keys_that_were_absent(self) -> None:
        self.kmyc.parent.mkdir(parents=True, exist_ok=True)
        self.kmyc.write_text("[CUSTOM]\nlight = true\n", encoding="utf-8")
        self.assertEqual(self.run_manager("--apply", "--mode", "dark").returncode, 0)
        self.assertIn("iconslight = Tela-light", self.kmyc.read_text())
        self.assertEqual(self.run_manager("--restore-kmyc").returncode, 0)
        contents = self.kmyc.read_text()
        self.assertNotIn("iconslight", contents)
        self.assertNotIn("iconsdark", contents)
        self.assertIn("light = true", contents)

    def test_post_kde_reapplies_generated_theme(self) -> None:
        self.write_kmyc()
        self.write_config(dynamic=True)
        out = "Tela-Dynamic-Dark-e53935"
        self.make_generated(out)
        result = self.run_manager("--post-kde", "--mode", "dark")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.applied(), [f"--set-icons {out}"])
        contents = self.kmyc.read_text()
        self.assertIn(f"iconsdark = {out}", contents)
        self.assertIn("iconslight = Tela-light", contents)

    def test_post_kde_is_noop_when_override_off(self) -> None:
        self.write_kmyc()
        self.write_config(dynamic=False, override=False)
        before = self.kmyc.read_text()
        result = self.run_manager("--post-kde", "--mode", "dark")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(before, self.kmyc.read_text())
        self.assertEqual(self.applied(), [])

    def test_stale_activation_is_rejected(self) -> None:
        self.write_config(dynamic=True)
        out = "Tela-Dynamic-Dark-e53935"
        self.make_generated(out)
        write_json(self.state / "selection.json", selection_payload(selection_id="sel-b"))
        write_json(
            self.state / "request.json",
            request_payload(
                request_id="req-a",
                selection_id="sel-a",
                theme="Tela",
                base="Tela-dark",
                base_path=self.base,
                out=out,
            ),
        )
        result = self.run_manager(
            "--activate", out, "--request-id", "req-a", "--selection-id", "sel-a"
        )
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.applied(), [])

    def test_current_activation_succeeds(self) -> None:
        self.write_config(dynamic=True)
        out = "Tela-Dynamic-Dark-e53935"
        self.make_generated(out)
        write_json(self.state / "selection.json", selection_payload(selection_id="sel-a"))
        write_json(
            self.state / "request.json",
            request_payload(
                request_id="req-a",
                selection_id="sel-a",
                theme="Tela",
                base="Tela-dark",
                base_path=self.base,
                out=out,
            ),
        )
        result = self.run_manager(
            "--activate", out, "--request-id", "req-a", "--selection-id", "sel-a"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.applied(), [f"--set-icons {out}"])
        self.assertEqual(self.status()["active"], out)

    def test_unsupported_adapter_stays_on_base(self) -> None:
        make_theme(self.icons, "Qogir-dark", {"16/places/folder.svg": svg()})
        self.write_config(dynamic=True, theme="Qogir")
        result = self.run_manager("--apply", "--mode", "dark")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.applied(), ["--set-icons Qogir-dark"])
        self.assertEqual(self.status()["state"], "unsupported")
        request = json.loads((self.state / "request.json").read_text())
        self.assertTrue(request["cancelled"])

    def test_follow_scheme_off_uses_static_theme(self) -> None:
        make_theme(self.icons, "Tela", {"16/places/folder.svg": svg()})
        self.write_config(dynamic=False, follow=False)
        result = self.run_manager("--apply", "--mode", "dark")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.applied(), ["--set-icons Tela"])
        self.assertEqual(self.selection()["mode"], "static")
        self.assertEqual(self.status()["mode"], "static")


if __name__ == "__main__":
    unittest.main()
