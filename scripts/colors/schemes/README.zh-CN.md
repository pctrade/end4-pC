# 自定义配色方案

一个配色方案就是一个 JSON 文件。内置方案位于本目录，你自己的方案放在
`~/.config/illogical-impulse/schemes/`（同名文件会覆盖内置方案）。

最简单的方式：**设置 > 界面 > 配色方案 > 添加方案**，选择你的 `.json` 文件，会自动校验并安装。
也可以复制 [`_template.json`](_template.json)，修改后放入上述目录，再点击 **重新加载**。

## 格式

| 字段 | 含义 |
|---|---|
| `name` | 列表中显示的名称 |
| `defaults` | 默认使用的强调色名称：`primary`、`secondary`、`tertiary`（必须同时存在于两种模式的 `accents` 中） |
| `dark` / `light` | 每种模式一个块，两者都必须提供 |

每个模式块包含：

| 字段 | 含义 |
|---|---|
| `surface` | 主背景色 |
| `surface_dim`、`surface_bright` | 更暗 / 更亮的背景变体 |
| `surface_container_lowest` … `surface_container_highest` | 面板层级，从最接近背景到最凸起 |
| `on_surface`、`on_surface_variant` | 文字和图标（普通 / 弱化） |
| `outline`、`outline_variant` | 边框和分隔线 |
| `error` | 错误和危险操作的颜色 |
| `on_accent` | 绘制在强调色之上的文字颜色（需与强调色有足够对比度） |
| `accents` | 用户可在设置中选为"强调色"和"次要色"的命名颜色 |
| `term` | 16 个终端颜色（ANSI 0–15）。其中 0 和 7 会被 `surface` 和 `on_surface` 替换，用作终端背景和文字 |

## 完整示例

复制后修改数值，保存为 `my-scheme.json`：

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

所有颜色均为 `#RRGGBB`。以 `_` 开头的文件不会出现在列表中。
其余颜色（容器色、fixed 色、inverse 色）会自动推导。

在终端中检查文件：`python3 ../named_scheme.py --validate my-scheme.json`
