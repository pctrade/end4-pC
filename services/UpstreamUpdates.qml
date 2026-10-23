pragma Singleton
import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Watches repos for new commits and pings the user exactly once per new
 * version, with actionable notification buttons:
 *  - "upstream": the end4-pC config repo (Config.options.updates.upstreamRepoUrl)
 *  - "fixes":    an optional secondary fork (Config.options.updates.fixesRepoUrl)
 *
 * Deduping survives quickshell reloads: last-notified SHAs and skipped
 * versions are persisted in ~/.local/state/quickshell/user/repo-updates.json.
 * A notification returning no action (dismissed/timeout) is not re-sent for
 * the same version. "Merge now" performs a single fetch + merge of the
 * latest head into the local checkout (not commit-by-commit) and then posts
 * a short "what's new" summary. New SHAs re-arm notifications.
 */
Singleton {
    id: root

    readonly property var sources: [
        {
            key: "upstream",
            label: "end4-pC (upstream)",
            url: Config.options.updates.upstreamRepoUrl,
            enabled: Config.options.updates.notifyUpstreamUpdates && Config.options.updates.upstreamRepoUrl.length > 0
        },
        {
            key: "fixes",
            label: "end4-pC fixes repo",
            url: Config.options.updates.fixesRepoUrl,
            enabled: Config.options.updates.notifyFixesRepo && Config.options.updates.fixesRepoUrl.length > 0
        }
    ]

    readonly property string shellDir: Quickshell.shellPath("")

    property string localSha: ""
    // Sequential per-source pipeline state
    property int checkIndex: -2 // -2 idle, -1 resolving local HEAD, >=0 running a source
    property string pendingRemoteSha: ""
    property string pendingSourceKey: ""

    function check() {
        if (!Config.ready) return;
        const runSources = root.sources.filter(s => s.enabled);
        if (runSources.length === 0) return;
        if (root.checkIndex !== -2) return; // already running
        root.checkIndex = -1;
        localHeadProc.running = true;
    }

    function sourceByKey(key) {
        return root.sources.find(s => s.key === key);
    }

    function lastNotifiedFor(key) {
        return key === "upstream" ? state.lastNotifiedUpstream : state.lastNotifiedFixes;
    }

    function isIgnored(key, sha) {
        return (key === "upstream" ? state.ignoredUpstream : state.ignoredFixes).includes(sha);
    }

    function rememberNotified(key, sha) {
        if (key === "upstream") state.lastNotifiedUpstream = sha;
        else state.lastNotifiedFixes = sha;
        stateWriteTimer.restart();
    }

    function rememberSkipped(key, sha) {
        const prop = (key === "upstream") ? state.ignoredUpstream : state.ignoredFixes;
        const list = prop.slice();
        if (!list.includes(sha)) {
            list.push(sha);
            while (list.length > 30) list.shift();
        }
        if (key === "upstream") state.ignoredUpstream = list;
        else state.ignoredFixes = list;
        root.rememberNotified(key, sha);
    }

    function sourceDone() {
        // Continue with the next enabled source after the current one resolves
        const next = root.checkIndex + 1;
        root.checkIndex = -2;
        const enabled = root.sources.filter(s => s.enabled);
        const baseIndex = root.sources.indexOf(enabled[0] ?? null);
        if (next - baseIndex >= enabled.length) return;
        root.checkSource(enabled[next - baseIndex]);
    }

    function checkSource(source) {
        root.checkIndex = root.sources.indexOf(source);
        root.pendingSourceKey = source.key;
        root.pendingRemoteSha = "";
        remoteProc.running = true;
    }

    // --- Local HEAD ------------------------------------------------------
    Process {
        id: localHeadProc
        command: ["bash", "-c", `git -C '${root.shellDir}' rev-parse HEAD 2>/dev/null`]
        stdout: SplitParser {
            onRead: data => {
                const sha = data.trim();
                if (sha.length === 40) root.localSha = sha;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (root.localSha === "") {
                // Not a git checkout; skip silently
                root.checkIndex = -2;
                return;
            }
            const enabled = root.sources.filter(s => s.enabled);
            if (enabled.length === 0) { root.checkIndex = -2; return; }
            root.checkSource(enabled[0]);
        }
    }

    // --- Fetch the tip SHA of the current source --------------------------
    Process {
        id: remoteProc
        command: {
            const url = root.sourceByKey(root.pendingSourceKey)?.url ?? "";
            return ["bash", "-c", `git ls-remote '${url}' HEAD 2>/dev/null | cut -f1`];
        }
        stdout: SplitParser {
            onRead: data => {
                const sha = data.trim();
                if (sha.length === 40) root.pendingRemoteSha = sha;
            }
        }
        onExited: (exitCode, exitStatus) => {
            const source = root.sourceByKey(root.pendingSourceKey);
            if (source && root.pendingRemoteSha.length === 40)
                root.evaluate(source, root.pendingRemoteSha);
            else
                root.sourceDone();
        }
    }

    function evaluate(source, remoteSha) {
        // Containment test: ping only when the remote head is NOT already in local history
        containProc.command = ["bash", "-c",
            `git -C '${root.shellDir}' merge-base --is-ancestor '${remoteSha}' HEAD >/dev/null 2>&1 && echo contained || echo not-contained`];
        containProc.running = true;
    }

    // --- Containment ------------------------------------------------------
    Process {
        id: containProc
        stdout: StdioCollector {
            onStreamFinished: {
                const source = root.sourceByKey(root.pendingSourceKey);
                const sha = root.pendingRemoteSha;
                if (!source || sha === "" || root.localSha === "") { root.sourceDone(); return; }
                const contained = text.trim() === "contained";
                if (!contained
                    && sha !== root.lastNotifiedFor(source.key)
                    && !root.isIgnored(source.key, sha)) {
                    root.sendNotification(source, sha); // continues in notifProc when it exits
                } else {
                    root.sourceDone();
                }
            }
        }
    }

    // --- Notification with actions ----------------------------------------
    Process {
        id: notifProc
        property string key: ""
        property string sha: ""
        property string label: ""
        stdout: StdioCollector {
            onStreamFinished: {
                notifProc.readChoice(text);
            }
        }
        function readChoice(chosen) {
            const c = chosen.trim().toLowerCase();
            const source = root.sourceByKey(notifProc.key);
            const sha = notifProc.sha;
            if (source && c === "merge") {
                root.startMerge(source, sha);
            } else if (source && c === "skip") {
                root.rememberSkipped(source.key, sha);
                root.sourceDone();
            } else {
                root.sourceDone(); // dismissed / timeout: stay silent for this version
            }
        }
        onExited: (exitCode, exitStatus) => { /* stdout handled above */ }
    }

    function sendNotification(source, sha) {
        notifProc.key = source.key;
        notifProc.sha = sha;
        notifProc.label = source.label;
        // notify-send prints the chosen action key ("merge"/"skip") when the
        // user clicks one of the buttons in the notification popup.
        notifProc.command = ["notify-send",
            "-a", "Shell",
            "-t", "600000",
            "-r", "772101",
            "-A", "merge=Merge now",
            "-A", "skip=Skip this version",
            `${source.label}: update available`,
            `New commits up to ${sha.slice(0, 7)}.\n"Merge now" pulls the latest version in one go; "Skip" ignores it.`];
        notifProc.running = true;
        root.rememberNotified(source.key, sha);
    }

    // --- Merge the latest head (single merge, not commit-by-commit) -------
    Process {
        id: mergeProc
        property string key: ""
        property string sha: ""
        property string oldSha: ""
        stdout: StdioCollector { id: mergeOut }
        stderr: StdioCollector { id: mergeErr }
        onExited: (exitCode, exitStatus) => {
            const source = root.sourceByKey(mergeProc.key);
            if (!source) { root.sourceDone(); return; }
            if (exitCode === 0) {
                whatNewProc.oldSha = mergeProc.oldSha;
                whatNewProc.key = mergeProc.key;
                whatNewProc.running = true;
            } else {
                const err = mergeErr.text.trim().split("\n").slice(-3).join("\n");
                Quickshell.execDetached(["notify-send", "-a", "Shell", "-u", "critical",
                    `${source.label}: merge failed`,
                    err.length > 0 ? err : "Git reported an error; see the logs."]);
                root.sourceDone();
            }
        }
    }

    Process {
        id: whatNewProc
        property string key: ""
        property string oldSha: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const source = root.sourceByKey(whatNewProc.key);
                const commits = text.trim();
                const body = (commits.length > 0)
                    ? `What's new:\n${commits}`
                    : "Merged to the latest version.";
                Quickshell.execDetached(["notify-send", "-a", "Shell",
                    `${source.label}: updated to latest`, body]);
                root.sourceDone();
            }
        }
    }

    function startMerge(source, sha) {
        mergeProc.key = source.key;
        mergeProc.sha = sha;
        mergeProc.oldSha = root.localSha;
        mergeProc.command = ["bash", "-c",
            `if [ -n "$(git -C '${root.shellDir}' status --porcelain)" ]; then echo DIRTY >&2; exit 32; fi\n`
            + `git -C '${root.shellDir}' fetch '${source.url}' HEAD 2>&1 && `
            + `git -C '${root.shellDir}' merge --no-edit '${sha}'`];
        mergeProc.running = true;
    }

    // --- Persisted state ---------------------------------------------------
    FileView {
        id: stateFile
        path: `${Directories.state}/user/repo-updates.json`
        watchChanges: false
        onAdapterUpdated: stateWriteTimer.restart()
        onLoaded: root.check()

        JsonAdapter {
            id: state
            property string lastNotifiedUpstream: ""
            property string lastNotifiedFixes: ""
            property list<var> ignoredUpstream: []
            property list<var> ignoredFixes: []
        }
    }

    Timer {
        id: stateWriteTimer
        interval: 100
        onTriggered: stateFile.writeAdapter()
    }

    // --- Scheduling ---------------------------------------------------------
    Timer {
        interval: 3 * 60 * 1000
        running: Config.ready
        repeat: false
        onTriggered: root.check()
    }

    Timer {
        interval: Math.max(30, Config.options.updates.upstreamCheckInterval) * 60 * 1000
        running: Config.ready
        repeat: true
        onTriggered: root.check()
    }

    // --- IPC ------------------------------------------------------------------
    IpcHandler {
        target: "upstream"
        function check() { root.check() }
        function merge(source: string) {
            const s = root.sourceByKey(source);
            if (s && root.pendingRemoteSha !== "")
                root.startMerge(s, root.pendingRemoteSha);
        }
        function skip(source: string) {
            if (root.pendingRemoteSha !== "")
                root.rememberSkipped(source, root.pendingRemoteSha);
        }
    }
}
