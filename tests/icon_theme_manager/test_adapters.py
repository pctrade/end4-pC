from __future__ import annotations

import hashlib
import os
import sys
import tempfile
import unittest
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "theming"))

from icon_theme_adapters.base import GENERATED_RE, AdapterError  # noqa: E402
from icon_theme_adapters.generic import GenericAdapter  # noqa: E402
from icon_theme_adapters.papirus import PapirusAdapter, nearest_color  # noqa: E402
from icon_theme_adapters.qogir import QogirAdapter  # noqa: E402
from icon_theme_adapters.tela import TelaAdapter  # noqa: E402

from helpers import make_theme, svg  # noqa: E402


class Sandbox(unittest.TestCase):
    def setUp(self) -> None:
        self.stack = ExitStack()
        self.tmp = self.stack.enter_context(tempfile.TemporaryDirectory())
        self.root = Path(self.tmp)
        self.home = self.root / "home"
        self.data = self.root / "data"
        self.icons = self.data / "icons"
        self.empty = self.root / "empty"
        for path in (self.home, self.icons, self.empty):
            path.mkdir(parents=True, exist_ok=True)
        self.stack.enter_context(
            patch.dict(
                os.environ,
                {
                    "HOME": str(self.home),
                    "XDG_DATA_HOME": str(self.data),
                    "XDG_DATA_DIRS": str(self.empty),
                },
            )
        )

    def tearDown(self) -> None:
        self.stack.close()

    def build(self, adapter, source: Path, accent: str = "#e53935") -> Path:
        target = self.root / "built"
        adapter.recolor(source, target, accent)
        return target


class TelaAdapterTests(Sandbox):
    def setUp(self) -> None:
        super().setUp()
        self.folder = '<rect fill="#5294e2"/><rect fill="#ff9800"/>'
        self.source = make_theme(
            self.icons,
            "Tela-dark",
            {
                "16/places/folder.svg": svg(extra=self.folder),
                "16/apps/brand.svg": b'<svg><rect fill="#ff9800"/><rect fill="#4285f4"/></svg>\n',
            },
            symlinks={"16/symbolic/brand.svg": "../apps/brand.svg"},
        )

    def test_rule_and_literal_are_recolored(self) -> None:
        before = hashlib.sha256((self.source / "16/places/folder.svg").read_bytes()).hexdigest()
        built = self.build(TelaAdapter(), self.source)

        folder = (built / "16/places/folder.svg").read_text()
        self.assertIn(".ColorScheme-Highlight { color:#e53935; }", folder)
        self.assertIn('<rect fill="#e53935"/>', folder)
        self.assertIn("#ff9800", folder, "brand orange must be preserved")

        brand = (built / "16/apps/brand.svg").read_text()
        self.assertIn("#ff9800", brand)
        self.assertIn("#4285f4", brand, "unrelated brand blue must be preserved")

        after = hashlib.sha256((self.source / "16/places/folder.svg").read_bytes()).hexdigest()
        self.assertEqual(before, after, "source theme must never be modified")

    def test_index_is_copied_and_symbolic_link_stays_inside(self) -> None:
        built = self.build(TelaAdapter(), self.source)
        self.assertFalse((built / "index.theme").is_symlink())
        self.assertTrue((built / "index.theme").is_file())
        self.assertTrue((built / "16/symbolic/brand.svg").is_symlink())
        link = os.readlink(built / "16/symbolic/brand.svg")
        self.assertFalse(link.startswith("/"), link)
        self.assertTrue((built / "16/symbolic/brand.svg").exists())
        self.assertTrue(
            str((built / "16/symbolic/brand.svg").resolve()).startswith(str(built.resolve()))
        )

    def test_sibling_theme_assets_are_materialized(self) -> None:
        # Tela-dark gets most app assets via symlinks to the sibling Tela theme.
        sibling = make_theme(
            self.icons,
            "Tela",
            {"16/status/sibling.svg": svg(extra='<rect fill="#5294e2"/>')},
        )
        (self.source / "16/status").symlink_to(sibling / "16/status")
        built = self.build(TelaAdapter(), self.source)

        target = built / "16/status/sibling.svg"
        self.assertTrue(target.is_file())
        self.assertFalse(target.is_symlink())
        self.assertIn('<rect fill="#e53935"/>', target.read_text())

    def test_escaping_symlink_is_skipped(self) -> None:
        outside = self.root / "outside.svg"
        outside.write_bytes(svg())
        (self.source / "16/places/escape.svg").symlink_to(outside)
        built = self.build(TelaAdapter(), self.source)
        self.assertFalse((built / "16/places/escape.svg").exists())

    def test_light_variant_leaves_literal_brand_blue(self) -> None:
        light = make_theme(
            self.icons,
            "Tela-light",
            {
                "16/places/folder.svg": svg(
                    rule="#4285f4",
                    extra='<rect fill="#4285f4"/><rect fill="#ff9800"/>',
                )
            },
        )
        built = self.build(TelaAdapter(), light)
        text = (built / "16/places/folder.svg").read_text()
        self.assertIn(".ColorScheme-Highlight { color:#e53935; }", text)
        self.assertIn('<rect fill="#4285f4"/>', text)
        self.assertIn("#ff9800", text)


class PapirusAdapterTests(Sandbox):
    def setUp(self) -> None:
        super().setUp()
        self.source = make_theme(
            self.icons,
            "Papirus-Dark",
            {
                "16/places/folder.svg": svg(extra='<rect fill="#5294e2"/>'),
                "16/apps/app.svg": svg(extra='<rect fill="#5294e2"/><rect fill="#ff9800"/>'),
            },
        )

    def test_places_literals_change_apps_do_not(self) -> None:
        built = self.build(PapirusAdapter(), self.source)
        places = (built / "16/places/folder.svg").read_text()
        app = (built / "16/apps/app.svg").read_text()
        self.assertIn('<rect fill="#e53935"/>', places)
        self.assertIn(".ColorScheme-Highlight { color:#e53935; }", places)
        self.assertIn('<rect fill="#5294e2"/>', app)
        self.assertIn(".ColorScheme-Highlight { color:#e53935; }", app)
        self.assertIn("#ff9800", app)

    def test_nearest_color(self) -> None:
        self.assertEqual(nearest_color("#e53935"), "red")
        self.assertEqual(nearest_color("#5294e2"), "blue")


class CapabilityTests(Sandbox):
    def test_generic_and_qogir_do_not_recolor(self) -> None:
        theme = make_theme(self.icons, "Qogir-dark", {"16/places/folder.svg": svg()})
        self.assertEqual(QogirAdapter().info.capability, "none")
        self.assertFalse(GenericAdapter().supports_dynamic(theme))
        self.assertFalse(QogirAdapter().supports_dynamic(theme))
        with self.assertRaises(AdapterError):
            GenericAdapter().recolor(theme, self.root / "x", "#e53935")

    def test_generated_name_pattern(self) -> None:
        self.assertTrue(GENERATED_RE.match("Tela-Dynamic-Dark-e53935"))
        self.assertTrue(GENERATED_RE.match("Tela-Dynamic-Light-e53935"))
        self.assertTrue(GENERATED_RE.match("Tela-Dynamic-e53935"))
        self.assertFalse(GENERATED_RE.match("Tela-Dynamic-Dark-E53935"))
        self.assertFalse(GENERATED_RE.match("../Tela-Dynamic-Dark-e53935"))


if __name__ == "__main__":
    unittest.main()
