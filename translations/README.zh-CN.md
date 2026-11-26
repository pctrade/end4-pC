# 翻译界面

界面中的所有文字都以英文书写，并包裹在 `Translation.tr("...")` 中。一种语言就是本目录下的一个 JSON 文件：**键是英文原文，值是你的译文**：

```json
{
  "Interface Language": "界面语言",
  "Dark/Light toggle": "深色/浅色切换"
}
```

文件名是区域代码（`es_MX.json`、`zh_CN.json`、`pt_BR.json`……）。新增的文件在重新加载后会出现在 **设置 > 常规 > 语言** 中。如果系统语言没有对应文件，会使用同一语言的其他文件（例如 `es_AR` 使用 `es_MX`），否则使用英文。文件中缺少的文字会保持英文。

## 三种翻译方式

**1. 让 Gemini 自动翻译（最快）。** 设置 > 常规 > 语言 > 输入区域代码（如 `fr_FR`）> *Generate*。需要 Gemini API 密钥，大约 2 分钟，结果保存到 `~/.config/illogical-impulse/translations/`，更新时不会丢失。之后可以手动修改。

**2. 手动翻译。**
```bash
cp en_US.json fr_FR.json      # 然后翻译值，保持键不变
```
放在 `~/.config/illogical-impulse/translations/` 中仅自己使用，放在此处则可贡献回项目。

**3. 使用维护工具**查看缺失或过时的条目：
```bash
cd tools
./manage-translations.sh status          # 各语言的完成度
./manage-translations.sh check -l fr_FR  # 缺失和过时的键（只读）
./manage-translations.sh update -l fr_FR # 添加缺失的键，删除过时的键
```
更多说明见 [tools/README.md](tools/README.md)。

## 提示

- 保持 `%1` 等占位符不变：`"Hello, %1!"` -> `"你好，%1！"`。
- 保留 `\n` 换行，并尽量简短，界面空间有限。
- 以 `/*keep*/` 结尾的值不会被清理工具删除（用于运行时拼接的文字）。
- 文件必须是 UTF-8 且为有效的 JSON。文件损坏时界面会报错并回退到英文。
