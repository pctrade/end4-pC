# Custom color schemes

A color scheme is one JSON file. Built-in ones live in this folder; yours go in
`~/.config/illogical-impulse/schemes/` (a file there with the same name as a built-in one replaces it).

The easiest way: **Settings > Interface > Color Schemes > Add scheme**, pick your `.json` and it is validated and installed.
Or copy [`_template.json`](_template.json), edit it and drop it into the folder above, then press **Reload**.

## Format

| Field | Meaning |
|---|---|
| `name` | Name shown in the list |
| `defaults` | Accent names used by default: `primary`, `secondary`, `tertiary` (must exist in `accents` of both modes) |
| `dark` / `light` | One block per mode. Both are required |

Each mode block:

| Field | Meaning |
|---|---|
| `surface` | Main background |
| `surface_dim`, `surface_bright` | Darker / lighter background variants |
| `surface_container_lowest` … `surface_container_highest` | Panel layers, from the one closest to the background to the most raised |
| `on_surface`, `on_surface_variant` | Text and icons (normal / muted) |
| `outline`, `outline_variant` | Borders and dividers |
| `error` | Error and destructive color |
| `on_accent` | Text drawn on top of accent colors (must contrast with them) |
| `accents` | Named colors the user can pick as Accent and Secondary in Settings |
| `term` | 16 terminal colors (ANSI 0–15). 0 and 7 are replaced by `surface` and `on_surface` for the terminal background and text |

## Full example

Copy it, change the values and save it as `my-scheme.json`:

```json
{
    "name": "My scheme",
    "defaults": {
        "primary": "cyan",
        "secondary": "blue",
        "tertiary": "purple"
    },
    "dark": {
        "surface_dim": "#242933",
        "surface": "#2e3440",
        "surface_bright": "#434c5e",
        "surface_container_lowest": "#242933",
        "surface_container_low": "#2b303b",
        "surface_container": "#3b4252",
        "surface_container_high": "#434c5e",
        "surface_container_highest": "#4c566a",
        "on_surface": "#eceff4",
        "on_surface_variant": "#d8dee9",
        "outline": "#7b88a1",
        "outline_variant": "#4c566a",
        "error": "#bf616a",
        "on_accent": "#2e3440",
        "accents": {
            "red": "#bf616a",
            "orange": "#d08770",
            "yellow": "#ebcb8b",
            "green": "#a3be8c",
            "teal": "#8fbcbb",
            "cyan": "#88c0d0",
            "blue": "#81a1c1",
            "purple": "#b48ead"
        },
        "term": [
            "#3b4252",
            "#bf616a",
            "#a3be8c",
            "#ebcb8b",
            "#81a1c1",
            "#b48ead",
            "#88c0d0",
            "#e5e9f0",
            "#4c566a",
            "#bf616a",
            "#a3be8c",
            "#ebcb8b",
            "#81a1c1",
            "#b48ead",
            "#8fbcbb",
            "#eceff4"
        ]
    },
    "light": {
        "surface_dim": "#d8dee9",
        "surface": "#eceff4",
        "surface_bright": "#eceff4",
        "surface_container_lowest": "#f8f9fb",
        "surface_container_low": "#e5e9f0",
        "surface_container": "#d8dee9",
        "surface_container_high": "#cdd3df",
        "surface_container_highest": "#c1c8d6",
        "on_surface": "#2e3440",
        "on_surface_variant": "#4c566a",
        "outline": "#7b88a1",
        "outline_variant": "#c1c8d6",
        "error": "#a8434f",
        "on_accent": "#eceff4",
        "accents": {
            "red": "#a8434f",
            "orange": "#b8603f",
            "yellow": "#a98021",
            "green": "#6a8a52",
            "teal": "#4f8a89",
            "cyan": "#3f8aa0",
            "blue": "#5e81ac",
            "purple": "#8a6784"
        },
        "term": [
            "#e5e9f0",
            "#a8434f",
            "#6a8a52",
            "#a98021",
            "#5e81ac",
            "#8a6784",
            "#3f8aa0",
            "#4c566a",
            "#d8dee9",
            "#a8434f",
            "#6a8a52",
            "#a98021",
            "#5e81ac",
            "#8a6784",
            "#4f8a89",
            "#2e3440"
        ]
    }
}
```

All colors are `#RRGGBB`. Files starting with `_` are ignored by the list.
Everything else (containers, fixed colors, inverse colors) is derived automatically.

Check a file from a terminal: `python3 ../named_scheme.py --validate my-scheme.json`
