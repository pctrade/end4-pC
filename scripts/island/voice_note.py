#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["faster-whisper>=1.0"]
# ///
"""Transcribes a recorded voice note and prints the text.

Typing a long reply is slow; saying it is not. The recording itself is done by the shell script that calls this
(parecord), so this only has to turn a wav into text. The model runs locally — nothing is uploaded — and is
cached after the first run.

Usage: voice_note.py <wav path> [language]
"""

import sys

from faster_whisper import WhisperModel

MODEL = "base"


def main():
    if len(sys.argv) < 2:
        return 1
    path = sys.argv[1]
    language = sys.argv[2] if len(sys.argv) > 2 else "pt"

    model = WhisperModel(MODEL, device="cpu", compute_type="int8")
    segments, _info = model.transcribe(path, language=language, vad_filter=True)
    text = " ".join(segment.text.strip() for segment in segments).strip()
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
