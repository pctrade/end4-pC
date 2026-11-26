# カスタムカラースキーム

カラースキームは 1 つの JSON ファイルです。内蔵のものはこのフォルダにあり、自作のものは
`~/.config/illogical-impulse/schemes/` に置きます（内蔵と同じ名前のファイルは内蔵を上書きします）。

いちばん簡単な方法：**設定 > インターフェース > カラースキーム > スキームを追加** で `.json` を選ぶと、検証されてインストールされます。
または [`_template.json`](_template.json) をコピーして編集し、上のフォルダに置いて **再読み込み** を押してください。

## フォーマット

| フィールド | 意味 |
|---|---|
| `name` | リストに表示される名前 |
| `defaults` | 既定で使うアクセント名：`primary`、`secondary`、`tertiary`（両モードの `accents` に存在する必要があります） |
| `dark` / `light` | モードごとに 1 ブロック。両方必須です |

各モードのブロック：

| フィールド | 意味 |
|---|---|
| `surface` | メインの背景色 |
| `surface_dim`、`surface_bright` | より暗い / 明るい背景のバリエーション |
| `surface_container_lowest` … `surface_container_highest` | パネルの階層（背景に最も近いものから最も浮いたものまで） |
| `on_surface`、`on_surface_variant` | 文字とアイコン（通常 / 控えめ） |
| `outline`、`outline_variant` | 枠線と区切り線 |
| `error` | エラーや破壊的操作の色 |
| `on_accent` | アクセント色の上に描く文字色（十分なコントラストが必要） |
| `accents` | 設定で「アクセント」「セカンダリ」として選べる名前付きの色 |
| `term` | ターミナルの 16 色（ANSI 0〜15）。0 と 7 はターミナルの背景と文字として `surface` と `on_surface` に置き換えられます |

## 完全な例

コピーして値を変更し、`my-scheme.json` として保存してください：

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

すべての色は `#RRGGBB` です。`_` で始まるファイルはリストに表示されません。
それ以外（コンテナ色、fixed 色、inverse 色）は自動で導出されます。

ターミナルでの確認：`python3 ../named_scheme.py --validate my-scheme.json`
