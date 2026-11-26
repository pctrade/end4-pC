# シェルの翻訳

シェル内のすべての文字列は英語で書かれ、`Translation.tr("...")` で囲まれています。1 つの言語は、このフォルダにある 1 つの JSON ファイルで、**キーが英語の原文、値が翻訳**です：

```json
{
  "Interface Language": "インターフェース言語",
  "Dark/Light toggle": "ダーク/ライト切り替え"
}
```

ファイル名はロケールコードです（`es_MX.json`、`zh_CN.json`、`pt_BR.json` など）。追加したファイルは再読み込み後に **設定 > 一般 > 言語** に表示されます。システム言語専用のファイルがない場合は、同じ言語の別ファイルを使い（例：`es_AR` は `es_MX`）、それもなければ英語になります。ファイルにない文字列は英語のままです。

## 翻訳の 3 つの方法

**1. Gemini に任せる（最速）。** 設定 > 一般 > 言語 > `fr_FR` のようなロケールコードを入力 > *Generate*。Gemini の API キーが必要で、約 2 分かかり、結果は `~/.config/illogical-impulse/translations/` に保存されるのでアップデートで消えません。あとから手で編集できます。

**2. 手で翻訳する。**
```bash
cp en_US.json fr_FR.json      # 値を翻訳し、キーはそのままにする
```
自分用なら `~/.config/illogical-impulse/translations/` に、プロジェクトに貢献するならここに置きます。

**3. メンテナンスツールで** 不足や古い項目を確認します：
```bash
cd tools
./manage-translations.sh status          # 各言語の進捗
./manage-translations.sh check -l fr_FR  # 不足・古いキー（読み取り専用）
./manage-translations.sh update -l fr_FR # 不足を追加し、古いキーを削除
```
詳しくは [tools/README.md](tools/README.md) を参照してください。

## ヒント

- `%1` などのプレースホルダーはそのまま残します：`"Hello, %1!"` -> `"こんにちは、%1！"`。
- `\n` の改行は残し、文は短くしてください。画面の余白が小さいためです。
- `/*keep*/` で終わる値は、クリーニングツールで削除されません（実行時に組み立てる文字列に使います）。
- ファイルは UTF-8 で、有効な JSON である必要があります。壊れている場合はエラーを出して英語に戻ります。
