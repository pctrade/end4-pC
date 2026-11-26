# Translating the shell

Every text in the shell is written in English and wrapped in `Translation.tr("...")`. A language is one JSON file in this folder whose **keys are the English texts** and whose **values are your translation**:

```json
{
  "Interface Language": "Idioma de la interfaz",
  "Dark/Light toggle": "Alternar oscuro/claro"
}
```

File names are locale codes (`es_MX.json`, `zh_CN.json`, `pt_BR.json`...). Any file you add shows up in **Settings > General > Language** after a reload. If your system language has no file of its own, the shell uses another file of the same language (for example `es_AR` uses `es_MX`), and English otherwise. Texts missing from a file just stay in English.

## Three ways to translate

**1. Let Gemini do it (fastest).** Settings > General > Language > type a locale code such as `fr_FR` > *Generate*. It needs a Gemini API key, takes about 2 minutes, and saves the result to `~/.config/illogical-impulse/translations/`, so it survives updates. You can edit that file by hand afterwards.

**2. Translate by hand.**
```bash
cp en_US.json fr_FR.json      # then translate the values, keep the keys untouched
```
Put your file in `~/.config/illogical-impulse/translations/` to keep it private, or here to contribute it back.

**3. Use the maintenance tools** to find what is missing or outdated:
```bash
cd tools
./manage-translations.sh status          # how complete each language is
./manage-translations.sh check -l fr_FR  # missing and stale keys, read-only
./manage-translations.sh update -l fr_FR # add the missing keys, remove the stale ones
```
More details in [tools/README.md](tools/README.md).

## Tips

- Keep placeholders like `%1` exactly where they are: `"Hello, %1!"` -> `"Hola, %1!"`.
- Keep `\n` line breaks, and keep texts short; the interface has little room.
- A value ending in `/*keep*/` is never removed by the cleaning tools (use it for texts built at runtime).
- Files must be UTF-8 and valid JSON. If a file is broken the shell prints an error and falls back to English.
