"""Same-user provider process detection shared by the usage helpers.

Provider clients do not all expose a common foreground process name. Some
applications launch a native CLI, some launch an ACP adapter through Node or
Npx, and some launch Codex's app-server as a stdio child. This module uses the
command arguments and executable names of those children without connecting to
their stdin/stdout streams.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional


@dataclass(frozen=True)
class ProcessInfo:
    pid: int
    parent_pid: int
    arguments: tuple[str, ...]
    command_name: str
    executable: str = ""

    @property
    def command(self) -> str:
        return " ".join(self.arguments)

    @property
    def names(self) -> set[str]:
        # Bare positional arguments such as `python watcher.py codex` are not
        # processes. Only treat executable-looking arguments as names; provider
        # selectors passed after a script must go through an explicit flag.
        values = {
            Path(argument).name.lower()
            for argument in self.arguments
            if "/" in argument or "\\" in argument
        }
        if self.command_name:
            values.add(self.command_name.lower())
        if self.executable:
            values.add(Path(self.executable).name.lower())
        return {value.removesuffix(".exe") for value in values if value}


_PROVIDER_ALIASES: dict[str, set[str]] = {
    "codex": {"codex", "openai", "openai-codex"},
    "claude": {"claude", "claude-code", "anthropic"},
    "kimi": {"kimi", "kimi-code", "moonshot"},
    "zai": {"zai", "z.ai", "zcode", "glm", "zhipu"},
    "cursor": {"cursor", "cursor-agent", "anysphere"},
}

_EXACT_PROCESS_NAMES: dict[str, set[str]] = {
    "codex": {
        "codex",
        "codex-acp",
        "codex-agent",
        "codex-agent-acp",
        "openai-codex",
    },
    "claude": {
        "claude",
        "claude-code",
        "claude-agent-acp",
        "claude-code-acp",
        "anthropic-claude",
    },
    "kimi": {
        "kimi",
        "kimi-code",
        "kimi-agent-acp",
        "kimi-code-acp",
    },
    "zai": {
        "zcode",
        "zcode-acp",
        "zai",
        "zai-acp",
        "glm",
        "glm-acp",
    },
    "cursor": {
        "cursor",
        "cursor-agent",
    },
}

_PATH_MARKERS: dict[str, tuple[str, ...]] = {
    "codex": (
        "/@openai/codex",
        "/codex-acp",
        "codex-agent-acp",
        "openai-codex",
    ),
    "claude": (
        "claude-code",
        "claude-agent-acp",
        "@anthropic-ai",
        "anthropic/claude",
    ),
    "kimi": (
        "/.kimi-code/",
        "/kimi-code/",
        "kimi-agent-acp",
        "@moonshot",
    ),
    "zai": (
        "/zcode/",
        "zcode-acp",
        "zai-acp",
        "@zai",
        "glm-acp",
    ),
    # Avoid ~/.config/Cursor path hits (crashpad/helpers). Match the app + agent.
    "cursor": (
        "/usr/share/cursor/",
        "/cursor/resources/app/",
        "cursor.mjs",
        "/cursor-agent",
        "cursor-agent",
    ),
}

_PROVIDER_FLAGS = {
    "--provider",
    "--model-provider",
    "--agent",
    "--agent-name",
    "--acp-agent",
    "--backend",
    "--engine",
}


def _parent_pid(pid: int) -> Optional[int]:
    try:
        contents = (Path("/proc") / str(pid) / "stat").read_text(encoding="utf-8")
        end = contents.rfind(")")
        fields = contents[end + 2 :].split()
        return int(fields[1]) if len(fields) > 1 else None
    except (OSError, ValueError):
        return None


def _ancestors() -> set[int]:
    result: set[int] = set()
    pid = os.getpid()
    while pid > 1 and pid not in result:
        result.add(pid)
        parent = _parent_pid(pid)
        if parent is None:
            break
        pid = parent
    return result


def _arguments(pid: int) -> list[str]:
    try:
        raw = (Path("/proc") / str(pid) / "cmdline").read_bytes()
    except OSError:
        return []
    return [part.decode("utf-8", "replace") for part in raw.split(b"\0") if part]


def _command_name(pid: int) -> str:
    try:
        return (Path("/proc") / str(pid) / "comm").read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def _executable(pid: int) -> str:
    try:
        return os.readlink(Path("/proc") / str(pid) / "exe")
    except OSError:
        return ""


def _processes() -> list[ProcessInfo]:
    current_uid = os.getuid()
    ancestors = _ancestors()
    try:
        entries = list(Path("/proc").iterdir())
    except OSError:
        return []

    processes: list[ProcessInfo] = []
    for entry in entries:
        if not entry.name.isdigit():
            continue
        pid = int(entry.name)
        if pid in ancestors:
            continue
        try:
            if entry.stat().st_uid != current_uid:
                continue
        except OSError:
            continue
        arguments = _arguments(pid)
        command_name = _command_name(pid)
        executable = _executable(pid)
        if not arguments and not command_name and not executable:
            continue
        parent_pid = _parent_pid(pid) or 0
        processes.append(ProcessInfo(pid, parent_pid, tuple(arguments), command_name, executable))
    return processes


def _flag_values(arguments: tuple[str, ...]) -> list[str]:
    values: list[str] = []
    for index, argument in enumerate(arguments):
        normalized = argument.lower()
        if "=" in normalized:
            flag, value = normalized.split("=", 1)
            if flag in _PROVIDER_FLAGS:
                values.append(value)
        elif normalized in _PROVIDER_FLAGS and index + 1 < len(arguments):
            values.append(arguments[index + 1].lower())
    return values


def _has_provider_flag(provider: str, arguments: tuple[str, ...]) -> bool:
    aliases = _PROVIDER_ALIASES.get(provider, {provider})
    return any(value in aliases for value in _flag_values(arguments))


def antigravity_process_kind(
    arguments: list[str] | tuple[str, ...],
    executable: str = "",
) -> Optional[str]:
    names = {
        Path(argument).name.lower().removesuffix(".exe")
        for argument in arguments
        if "/" in argument or "\\" in argument
    }
    if arguments:
        names.add(Path(arguments[0]).name.lower().removesuffix(".exe"))
    if executable:
        names.add(Path(executable).name.lower().removesuffix(".exe"))
    command = " ".join((*arguments, executable)).lower()

    if names & {"agy", "antigravity-cli", "antigravity_cli", "antigravity-cli.exe"}:
        return "cli"
    if "antigravity" in names:
        return "app"

    language_server = any(
        name in {
            "language_server",
            "language_server_macos",
            "language_server_macos_arm",
            "language-server",
        }
        for name in names
    ) or "language_server" in command or "language-server" in command
    if not language_server or "antigravity" not in command:
        return None
    if "antigravity-ide" in command or "antigravity ide" in command:
        return "ide"
    return "app"


def _matches(provider: str, process: ProcessInfo) -> bool:
    if provider == "antigravity":
        return antigravity_process_kind(process.arguments, process.executable) is not None

    names = process.names
    command = " ".join((process.executable, process.command)).lower()
    # Sandbox/helper binaries mention Cursor paths but are not the IDE/agent.
    if provider == "cursor":
        if (
            "cursorsandbox" in names
            or "cursorsandbox" in command
            or "chrome_crashpad_handler" in names
        ):
            return False
        # Do not treat `--user-data-dir=.../Cursor` basenames as the app.
        primary = {
            process.command_name.lower().removesuffix(".exe"),
            Path(process.executable).name.lower().removesuffix(".exe") if process.executable else "",
        }
        if primary & _EXACT_PROCESS_NAMES.get("cursor", set()):
            return True
        if any(marker in command for marker in _PATH_MARKERS.get("cursor", ())):
            return True
        return _has_provider_flag("cursor", process.arguments)

    if names & _EXACT_PROCESS_NAMES.get(provider, set()):
        return True
    if any(marker in command for marker in _PATH_MARKERS.get(provider, ())):
        return True
    if _has_provider_flag(provider, process.arguments):
        return True

    # Codex is commonly launched as `node .../codex app-server`, so retain an
    # explicit app-server check even when the wrapper's basename is generic.
    if provider == "codex" and "app-server" in process.arguments:
        return any("codex" in argument.lower() for argument in process.arguments)
    return False


def provider_processes(provider: str) -> list[ProcessInfo]:
    return [process for process in _processes() if _matches(provider, process)]


def provider_statuses(providers: Iterable[str]) -> dict[str, bool]:
    requested = tuple(dict.fromkeys(providers))
    statuses = {provider: False for provider in requested}
    if not statuses:
        return statuses

    for process in _processes():
        for provider in statuses:
            if not statuses[provider] and _matches(provider, process):
                statuses[provider] = True
        if all(statuses.values()):
            break
    return statuses


def provider_is_running(provider: str) -> bool:
    return bool(provider_processes(provider))
