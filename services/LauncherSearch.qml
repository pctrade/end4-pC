pragma Singleton

import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."

Singleton {
    id: root

    property string query: ""

    function ensurePrefix(prefix) {
        if ([Config.options.search.prefix.action, Config.options.search.prefix.app, Config.options.search.prefix.clipboard, Config.options.search.prefix.emojis, Config.options.search.prefix.symbols, Config.options.search.prefix.math, Config.options.search.prefix.shellCommand, Config.options.search.prefix.webSearch,].some(i => root.query.startsWith(i))) {
            root.query = prefix + root.query.slice(1);
        } else {
            root.query = prefix + root.query;
        }
    }
    
    // https://specifications.freedesktop.org/menu/latest/category-registry.html
    property list<string> mainRegisteredCategories: ["AudioVideo", "Development", "Education", "Game", "Graphics", "Network", "Office", "Science", "Settings", "System", "Utility"]
    property list<string> appCategories: DesktopEntries.applications.values.reduce((acc, entry) => {
        for (const category of entry.categories) {
            if (!acc.includes(category) && mainRegisteredCategories.includes(category)) {
                acc.push(category);
            }
        }
        return acc;
    }, []).sort()

    // Load user action scripts from ~/.config/illogical-impulse/actions/
    // Uses FolderListModel to auto-reload when scripts are added/removed
    property var userActionScripts: {
        const actions = [];
        for (let i = 0; i < userActionsFolder.count; i++) {
            const fileName = userActionsFolder.get(i, "fileName");
            const filePath = userActionsFolder.get(i, "filePath");
            if (fileName && filePath) {
                const actionName = fileName.replace(/\.[^/.]+$/, ""); // strip extension
                actions.push({
                    action: actionName,
                    execute: ((path) => (args) => {
                        Quickshell.execDetached([path, ...(args ? args.split(" ") : [])]);
                    })(FileUtils.trimFileProtocol(filePath.toString()))
                });
            }
        }
        return actions;
    }

    FolderListModel {
        id: userActionsFolder
        folder: Qt.resolvedUrl(Directories.userActions)
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
    }

    property var searchActions: [
        {
            action: "accentcolor",
            execute: args => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch", "--color", ...(args != '' ? [`${args}`] : [])]);
            }
        },
        {
            action: "dark",
            execute: () => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "dark", "--noswitch"]);
            }
        },
        {
            action: "konachanwallpaper",
            execute: () => {
                Quickshell.execDetached([Quickshell.shellPath("scripts/colors/random/random_konachan_wall.sh")]);
            }
        },
        {
            action: "light",
            execute: () => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "light", "--noswitch"]);
            }
        },
        {
            action: "superpaste",
            execute: args => {
                if (!/^(\d+)/.test(args.trim())) {
                    // Invalid if doesn't start with numbers
                    Quickshell.execDetached(["notify-send", Translation.tr("Superpaste"), Translation.tr("Usage: <tt>%1superpaste NUM_OF_ENTRIES[i]</tt>\nSupply <tt>i</tt> when you want images\nExamples:\n<tt>%1superpaste 4i</tt> for the last 4 images\n<tt>%1superpaste 7</tt> for the last 7 entries").arg(Config.options.search.prefix.action), "-a", "Shell"]);
                    return;
                }
                const syntaxMatch = /^(?:(\d+)(i)?)/.exec(args.trim());
                const count = syntaxMatch[1] ? parseInt(syntaxMatch[1]) : 1;
                const isImage = !!syntaxMatch[2];
                Cliphist.superpaste(count, isImage);
            }
        },
        {
            action: "todo",
            execute: args => {
                Todo.addTask(args);
            }
        },
        {
            action: "wallpaper",
            execute: () => {
                Hyprland.dispatch(`hl.dsp.global("quickshell:wallpaperSelectorToggle")`)
            }
        },
        {
            action: "wipeclipboard",
            execute: () => {
                Quickshell.execDetached(["bash", "-c", "rm -f ~/.cache/cliphist/db"]);
            }
        },
        {
            action: "unsplash",
            execute: args => {
                if (!args || args.trim().length === 0) {
                    Quickshell.execDetached(["notify-send", "Unsplash", Translation.tr("Usage: /unsplash YOUR_API_KEY"), "-a", "Shell"]);
                    return;
                }
                KeyringStorage.setNestedField(["apiKeys", "unsplash"], args.trim());
                Quickshell.execDetached(["notify-send", "Unsplash", Translation.tr("API key saved!"), "-a", "Shell"]);
            }
        },
        {
            action: "wallhaven",
            execute: args => {
                if (!args || args.trim().length === 0) {
                    Quickshell.execDetached(["notify-send", "Wallhaven", Translation.tr("Usage: /wallhaven YOUR_API_KEY"), "-a", "Shell"]);
                    return;
                }
                KeyringStorage.setNestedField(["apiKeys", "wallhaven"], args.trim());
                Quickshell.execDetached(["notify-send", "Wallhaven", Translation.tr("API key saved!"), "-a", "Shell"]);
            }
        },
        {
            action: "pexels",
            execute: args => {
                if (!args || args.trim().length === 0) {
                    Quickshell.execDetached(["notify-send", "Pexels", Translation.tr("Usage: /pexels YOUR_API_KEY"), "-a", "Shell"]);
                    return;
                }
                KeyringStorage.setNestedField(["apiKeys", "pexels"], args.trim());
                Quickshell.execDetached(["notify-send", "Pexels", Translation.tr("API key saved!"), "-a", "Shell"]);
            }
        },
        {
            action: "openweather",
            execute: args => {
                if (!args || args.trim().length === 0) {
                    Quickshell.execDetached(["notify-send", "OpenWeather", Translation.tr("Usage: /openweather YOUR_API_KEY"), "-a", "Shell"]);
                    return;
                }
                KeyringStorage.setNestedField(["apiKeys", "openweather"], args.trim());
                Quickshell.execDetached(["notify-send", "OpenWeather", Translation.tr("API key saved!"), "-a", "Shell"]);
                Weather.getData();
            }
        },
    ]

    // Combined built-in and user actions
    property var allActions: searchActions.concat(userActionScripts)

    property string mathResult: ""
    property string helperScriptPath: FileUtils.trimFileProtocol(Quickshell.shellPath("scripts/super_menu_helper.py"))
    readonly property var helperCommand: ["env", "QS_OMNI_HISTORY=" + (Config.options.search.omni.enableBrowserHistory ? "1" : "0"), "python3", helperScriptPath]
    property var fileSearchResults: []
    property string lastFileQuery: ""
    property var spotifySearchResults: []
    property string lastSpotifyQuery: ""
    property var spotifyHistoryResults: []
    property string lastSpotifyHistoryQuery: ""
    property var smartSuggestions: []
    property string lastSuggestionQuery: ""

    onQueryChanged: {
        if (Config.options.search.omni.enableFileSearch && root.query.startsWith("/")) {
            fileSearchTimer.restart();
        } else if (Config.options.search.omni.enableSpotify && /^[pqPQ](\s+.*)?$/.test(root.query)) {
            spotifyHistoryTimer.restart();
            const songQ = root.query.replace(/^[pqPQ]\s*/, "").trim();
            if (songQ.length > 0) {
                spotifySearchTimer.restart();
            }
        } else if (Config.options.search.omni.enableBrowserHistory && root.query.trim().length > 0) {
            suggestionTimer.restart();
        }
    }

    Timer {
        id: spotifyHistoryTimer
        interval: 20
        onTriggered: {
            if (Config.options.search.omni.enableSpotify && /^[pqPQ](\s+.*)?$/.test(root.query)) {
                const isPlay = root.query[0].toLowerCase() === "p";
                const songQ = root.query.replace(/^[pqPQ]\s*/, "").trim();
                spotifyHistoryProc.search(isPlay, songQ);
            }
        }
    }

    Process {
        id: spotifyHistoryProc
        property string targetQuery: ""
        function search(isPlay, q) {
            spotifyHistoryProc.running = false;
            spotifyHistoryProc.targetQuery = q.toLowerCase();
            spotifyHistoryProc.command = [...root.helperCommand, "spotify-history", isPlay ? "play" : "queue", q];
            spotifyHistoryProc.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.spotifyHistoryResults = JSON.parse(data);
                    root.lastSpotifyHistoryQuery = spotifyHistoryProc.targetQuery;
                } catch (e) {
                    root.spotifyHistoryResults = [];
                }
            }
        }
    }

    Timer {
        id: suggestionTimer
        interval: 180
        onTriggered: {
            const q = root.query.trim();
            if (Config.options.search.omni.enableBrowserHistory && q.length > 0 && !q.startsWith("/")) {
                suggestionProc.search(q);
            }
        }
    }

    Process {
        id: suggestionProc
        property string targetQuery: ""
        function search(q) {
            suggestionProc.running = false;
            suggestionProc.targetQuery = q.toLowerCase();
            suggestionProc.command = [
                ...root.helperCommand,
                "suggestions",
                q,
                Config.options.search.omni.enableBrowserHistory ? "1" : "0",
                Config.options.search.omni.enableSpotify ? "1" : "0",
            ];
            suggestionProc.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.smartSuggestions = JSON.parse(data);
                    root.lastSuggestionQuery = suggestionProc.targetQuery;
                } catch (e) {
                    root.smartSuggestions = [];
                }
            }
        }
    }

    Timer {
        id: fileSearchTimer
        interval: 120
        onTriggered: {
            if (Config.options.search.omni.enableFileSearch && root.query.startsWith("/")) {
                fileSearchProc.search(root.query);
            }
        }
    }

    Process {
        id: fileSearchProc
        property string targetQuery: ""
        function search(q) {
            fileSearchProc.running = false;
            fileSearchProc.targetQuery = q;
            fileSearchProc.command = [...root.helperCommand, "file-search", q];
            fileSearchProc.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.fileSearchResults = JSON.parse(data);
                    root.lastFileQuery = fileSearchProc.targetQuery;
                } catch (e) {
                    root.fileSearchResults = [];
                }
            }
        }
    }

    Timer {
        id: spotifySearchTimer
        interval: 180
        onTriggered: {
            if (Config.options.search.omni.enableSpotify && /^[pqPQ]\s+.+/.test(root.query)) {
                const songQ = root.query.replace(/^[pqPQ]\s+/, "").trim();
                if (songQ.length > 0) {
                    spotifySearchProc.search(songQ);
                }
            }
        }
    }

    Process {
        id: spotifySearchProc
        property string targetSongQuery: ""
        function search(sq) {
            spotifySearchProc.running = false;
            spotifySearchProc.targetSongQuery = sq.toLowerCase();
            spotifySearchProc.command = [...root.helperCommand, "spotify-search", sq];
            spotifySearchProc.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.spotifySearchResults = JSON.parse(data);
                    root.lastSpotifyQuery = spotifySearchProc.targetSongQuery;
                } catch (e) {
                    root.spotifySearchResults = [];
                }
            }
        }
    }

    property bool clipboardWorkSafetyActive: {
        const enabled = Config.options.workSafety.enable.clipboard;
        const sensitiveNetwork = (StringUtils.stringListContainsSubstring(Network.networkName.toLowerCase(), Config.options.workSafety.triggerCondition.networkNameKeywords));
        return enabled && sensitiveNetwork;
    }

    function containsUnsafeLink(entry) {
        if (entry == undefined)
            return false;
        const unsafeKeywords = Config.options.workSafety.triggerCondition.linkKeywords;
        return StringUtils.stringListContainsSubstring(entry.toLowerCase(), unsafeKeywords);
    }

    Timer {
        id: nonAppResultsTimer
        interval: Config.options.search.nonAppResultDelay
        onTriggered: {
            let expr = root.query;
            if (expr.startsWith(Config.options.search.prefix.math)) {
                expr = expr.slice(Config.options.search.prefix.math.length);
            }
            mathProc.calculateExpression(expr);
        }
    }

    Process {
        id: mathProc
        property list<string> baseCommand: ["qalc", "-t"]
        function calculateExpression(expression) {
            mathProc.running = false;
            mathProc.command = baseCommand.concat(expression);
            mathProc.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                root.mathResult = data;
            }
        }
    }

    function normalize(text) {
        return (text ?? "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").trim();
    }

    function startsWithKeyword(query, keywords) {
        return keywords.some(k => (query.length >= 3 && k.startsWith(query)) || query === k || query.startsWith(k + " "));
    }

    // Seconds in "5 min", "1h30", "90s", "2,5 h"; a bare number counts as minutes (or seconds right after minutes)
    function parseDuration(text) {
        const re = /(\d+(?:[.,]\d+)?)\s*(horas?|hours?|hrs?|h|minutos?|minutes?|mins?|m|segundos?|seconds?|secs?|seg|s)?(?![a-z])/g;
        let total = 0;
        let lastUnit = "";
        let match;
        while ((match = re.exec(text)) !== null) {
            const value = parseFloat(match[1].replace(",", "."));
            let unit = match[2] ?? "";
            if (unit === "") unit = lastUnit === "h" ? "m" : lastUnit === "m" ? "s" : "m";
            else unit = unit[0] === "h" ? "h" : unit[0] === "m" ? "m" : "s";
            total += value * (unit === "h" ? 3600 : unit === "m" ? 60 : 1);
            lastUnit = unit;
        }
        return Math.round(total);
    }

    // "7:30", "7h30", "19h" -> seconds until the next time the clock shows it
    function parseClock(text) {
        const match = /(?:^|\s)(\d{1,2})\s*(?::|h)\s*(\d{2})?(?![\d])/.exec(text);
        if (!match) return -1;
        const hours = parseInt(match[1]);
        const minutes = parseInt(match[2] ?? "0");
        if (hours > 23 || minutes > 59) return -1;
        const now = new Date();
        const target = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hours, minutes, 0);
        if (target <= now) target.setDate(target.getDate() + 1);
        return Math.round((target - now) / 1000);
    }

    function formatDuration(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = seconds % 60;
        return [h > 0 ? `${h} h` : "", m > 0 ? `${m} min` : "", s > 0 && h === 0 ? `${s} s` : ""].filter(Boolean).join(" ") || "0 s";
    }

    function startCountdown(seconds) {
        TimerService.resetCountdown();
        TimerService.addCountdownMinutes(seconds / 60);
        TimerService.toggleCountdown();
    }

    function quickResult(props) {
        return resultComp.createObject(null, Object.assign({
            iconType: LauncherSearchResult.IconType.Material,
            verb: Translation.tr("Run")
        }, props));
    }

    function quickToolResults(rawQuery) {
        const query = root.normalize(rawQuery);
        const results = [];
        if (query === "") return results;
        const words = query.replace(/^(\S+)\s*/, "");
        const durationOnly = /^\d+(?:[.,]\d+)?\s*(?:horas?|hours?|hrs?|h|minutos?|minutes?|mins?|m|segundos?|seconds?|secs?|seg|s)(?:\s*\d+\s*(?:minutos?|mins?|m|segundos?|secs?|seg|s)?)*$/.test(query);

        if (durationOnly || root.startsWithKeyword(query, ["timer", "temporizador", "contagem", "countdown"])) {
            const seconds = root.parseDuration(durationOnly ? query : words);
            if (seconds > 0) {
                results.push(root.quickResult({
                    name: Translation.tr("Start a %1 timer").arg(root.formatDuration(seconds)),
                    type: Translation.tr("Timer"), iconName: "timer", verb: Translation.tr("Start"),
                    execute: () => root.startCountdown(seconds)
                }));
            }
            if (TimerService.countdownRunning || TimerService.countdownDuration > 0) {
                results.push(root.quickResult({
                    name: TimerService.countdownRunning ? Translation.tr("Pause timer") : Translation.tr("Resume timer"),
                    type: Translation.tr("Timer"), iconName: TimerService.countdownRunning ? "pause" : "play_arrow",
                    execute: () => TimerService.toggleCountdown()
                }));
                results.push(root.quickResult({
                    name: Translation.tr("Add %1 to the timer").arg("1 min"),
                    type: Translation.tr("Timer"), iconName: "more_time",
                    execute: () => TimerService.addCountdownMinutes(1)
                }));
                results.push(root.quickResult({
                    name: Translation.tr("Cancel timer"),
                    type: Translation.tr("Timer"), iconName: "timer_off",
                    execute: () => TimerService.resetCountdown()
                }));
            } else if (seconds <= 0) {
                for (const minutes of [1, 5, 10, 25]) {
                    results.push(root.quickResult({
                        name: Translation.tr("Start a %1 timer").arg(`${minutes} min`),
                        type: Translation.tr("Timer"), iconName: "timer", verb: Translation.tr("Start"),
                        comment: Translation.tr("Tip: type \"timer 7 min\" or just \"7m\""),
                        execute: () => root.startCountdown(minutes * 60)
                    }));
                }
            }
        }

        // Stopwatch (reads the ticking time only while paused, so the list is not rebuilt every 10 ms)
        if (root.startsWithKeyword(query, ["cronometro", "stopwatch"])) {
            const running = TimerService.stopwatchRunning;
            const hasTime = !running && TimerService.stopwatchTime > 0;
            results.push(root.quickResult({
                name: running ? Translation.tr("Pause stopwatch") : hasTime ? Translation.tr("Resume stopwatch") : Translation.tr("Start stopwatch"),
                type: Translation.tr("Stopwatch"), iconName: running ? "pause" : "avg_pace",
                execute: () => TimerService.toggleStopwatch()
            }));
            if (running) {
                results.push(root.quickResult({
                    name: Translation.tr("Record lap"),
                    type: Translation.tr("Stopwatch"), iconName: "flag",
                    execute: () => TimerService.stopwatchRecordLap()
                }));
            }
            if (running || hasTime) {
                results.push(root.quickResult({
                    name: Translation.tr("Reset stopwatch"),
                    type: Translation.tr("Stopwatch"), iconName: "restart_alt",
                    execute: () => TimerService.stopwatchReset()
                }));
            }
        }

        if (root.startsWithKeyword(query, ["pomodoro", "foco", "focus"])) {
            results.push(root.quickResult({
                name: TimerService.pomodoroRunning ? Translation.tr("Pause pomodoro") : Translation.tr("Start pomodoro"),
                comment: Translation.tr("%1 focus · %2 break").arg(root.formatDuration(TimerService.focusTime)).arg(root.formatDuration(TimerService.breakTime)),
                type: Translation.tr("Pomodoro"), iconName: TimerService.pomodoroRunning ? "pause" : "self_improvement",
                execute: () => TimerService.togglePomodoro()
            }));
            results.push(root.quickResult({
                name: Translation.tr("Reset pomodoro"),
                type: Translation.tr("Pomodoro"), iconName: "restart_alt",
                execute: () => TimerService.resetPomodoro()
            }));
        }

        if (root.startsWithKeyword(query, ["alarme", "despertador", "alarm", "acordar"])) {
            const clockSeconds = root.parseClock(words);
            const seconds = clockSeconds >= 0 ? clockSeconds : root.parseDuration(words.replace(/^(em|in|daqui a)\s+/, ""));
            if (seconds > 0) {
                const at = new Date(Date.now() + seconds * 1000);
                results.push(root.quickResult({
                    name: Translation.tr("Alarm at %1").arg(Qt.formatTime(at, "hh:mm")),
                    comment: Translation.tr("Rings in %1").arg(root.formatDuration(seconds - seconds % 60 || seconds)),
                    type: Translation.tr("Alarm"), iconName: "alarm", verb: Translation.tr("Set"),
                    execute: () => root.startCountdown(seconds)
                }));
            } else {
                results.push(root.quickResult({
                    name: Translation.tr("Type a time, e.g. \"alarm 7:30\""),
                    type: Translation.tr("Alarm"), iconName: "alarm", verb: "",
                    execute: () => {}
                }));
            }
        }

        // Reminder: a notification later, scheduled with systemd so it survives closing the shell
        if (root.startsWithKeyword(query, ["lembrar", "lembrete", "lembre", "remind", "reminder"])) {
            const atClock = /(?:^|\s)(as|at)\s+\d/.test(words);
            const seconds = atClock ? root.parseClock(words) : root.parseDuration((/(?:em|in|daqui a)\s+([\d.,]+\s*[a-z]*(?:\s*\d+\s*[a-z]*)?)/.exec(words) ?? [, ""])[1]);
            const text = rawQuery.replace(/^\s*\S+\s*/, "")
                .replace(/(?:^|\s)(?:em|in|daqui a)\s+[\d.,]+\s*[a-zA-Z]*(?:\s*\d+\s*[a-zA-Z]*)?/i, " ")
                .replace(/(?:^|\s)(?:às|as|at)\s+\d{1,2}\s*(?::|h)\s*\d{0,2}/i, " ")
                .replace(/^\s*(de|to|que)\s+/i, "").replace(/\s+/g, " ").trim();
            if (seconds > 0) {
                const message = text || Translation.tr("Reminder");
                results.push(root.quickResult({
                    name: Translation.tr("Remind \"%1\" in %2").arg(message).arg(root.formatDuration(seconds)),
                    comment: Translation.tr("At %1").arg(Qt.formatTime(new Date(Date.now() + seconds * 1000), "hh:mm")),
                    type: Translation.tr("Reminder"), iconName: "notifications_active", verb: Translation.tr("Schedule"),
                    execute: () => {
                        Quickshell.execDetached(["systemd-run", "--user", "--collect", `--on-active=${seconds}s`, "--timer-property=AccuracySec=1s",
                            "sh", "-c", 'notify-send -a Shell -u critical -i alarm "$0" "$1"; pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga',
                            Translation.tr("Reminder"), message]);
                        Quickshell.execDetached(["notify-send", "-a", "Shell", "-i", "alarm", Translation.tr("Reminder scheduled"),
                            `${message} · ${Qt.formatTime(new Date(Date.now() + seconds * 1000), "hh:mm")}`]);
                    }
                }));
            } else {
                results.push(root.quickResult({
                    name: Translation.tr("Type when, e.g. \"remind in 10 min take out the cake\""),
                    type: Translation.tr("Reminder"), iconName: "notifications_active", verb: "",
                    execute: () => {}
                }));
            }
        }

        if (root.startsWithKeyword(query, ["nao perturbe", "dnd", "do not disturb", "silenciar notificacoes"])) {
            results.push(root.quickResult({
                name: Notifications.silent ? Translation.tr("Turn off Do Not Disturb") : Translation.tr("Turn on Do Not Disturb"),
                type: Translation.tr("Notifications"), iconName: Notifications.silent ? "notifications" : "do_not_disturb_on",
                execute: () => Notifications.silent = !Notifications.silent
            }));
        }

        return results;
    }

    property list<var> results: {
        // Search results are handled here
        ////////////////// Skip? //////////////////
        if (root.query == "")
            return [];

        ///////////// Special cases ///////////////
        if (root.query.startsWith(Config.options.search.prefix.clipboard)) {
            // Clipboard
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.clipboard);
            const clipboardResults = Cliphist.fuzzyQuery(searchString).map((entry, index, array) => {
                const mightBlurImage = Cliphist.entryIsImage(entry) && root.clipboardWorkSafetyActive;
                let shouldBlurImage = mightBlurImage;
                if (mightBlurImage) {
                    shouldBlurImage = shouldBlurImage && (root.containsUnsafeLink(array[index - 1]) || root.containsUnsafeLink(array[index + 1]));
                }
                const type = `#${entry.match(/^\s*(\S+)/)?.[1] || ""}`;
                const pinned = Cliphist.isPinned(entry);
                return resultComp.createObject(null, {
                    rawValue: entry,
                    name: StringUtils.cleanCliphistEntry(entry),
                    verb: "",
                    type: type,
                    clipboard: true,
                    pinned: pinned,
                    execute: () => {
                        Cliphist.copy(entry);
                    },
                    actions: [resultComp.createObject(null, {
                            name: pinned ? Translation.tr("Unpin") : Translation.tr("Pin"),
                            iconName: pinned ? "keep_off" : "keep",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                Cliphist.togglePin(entry);
                            }
                        }), resultComp.createObject(null, {
                            name: Translation.tr("Delete"),
                            iconName: "delete",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                Cliphist.deleteEntry(entry);
                            }
                        })],
                    blurImage: shouldBlurImage
                });
            }).filter(Boolean);
            const lostPins = Cliphist.missingPins(searchString).map(pin => resultComp.createObject(null, {
                rawValue: `${pin.id}\t${pin.text}`,
                name: pin.text,
                verb: "",
                type: `#${pin.id}`,
                clipboard: true,
                pinned: true,
                execute: () => {
                    Quickshell.clipboardText = pin.content && pin.content !== "" ? pin.content : pin.text;
                },
                actions: [resultComp.createObject(null, {
                    name: Translation.tr("Unpin"),
                    iconName: "keep_off",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        Cliphist.removePin(pin);
                    }
                })]
            }));
            return [...lostPins, ...clipboardResults.filter(result => result.pinned), ...clipboardResults.filter(result => !result.pinned)];
        } else if (root.query.startsWith(Config.options.search.prefix.emojis)) {
            // Emojis
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.emojis);
            return Emojis.fuzzyQuery(searchString).map(entry => {
                const emoji = entry.match(/^\s*(\S+)/)?.[1] || "";
                return resultComp.createObject(null, {
                    rawValue: entry,
                    name: entry.replace(/^\s*\S+\s+/, ""),
                    iconName: emoji,
                    iconType: LauncherSearchResult.IconType.Text,
                    verb: Translation.tr("Copy"),
                    type: Translation.tr("Emoji"),
                    execute: () => {
                        Quickshell.clipboardText = entry.match(/^\s*(\S+)/)?.[1];
                    }
                });
            }).filter(Boolean);
        } else if (root.query.startsWith(Config.options.search.prefix.keybinds ?? "<")) {
            // Keybinds
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.keybinds ?? "<");
            const flatBinds = (function flatten(node) {
                let result = [...(node.keybinds ?? [])];
                for (const child of (node.children ?? [])) {
                    result = result.concat(flatten(child));
                }
                return result;
            })(HyprlandKeybinds.keybinds);

            return flatBinds.filter(bind => {
                if (!bind.comment) return false;
                if (searchString.length === 0) return true;
                return bind.comment.toLowerCase().includes(searchString.toLowerCase())
                    || bind.key.toLowerCase().includes(searchString.toLowerCase());
            }).map(bind => {
                const modsStr = bind.mods.join(" + ");
                const keyStr  = modsStr.length > 0 ? `${modsStr} + ${bind.key}` : bind.key;
                return resultComp.createObject(null, {
                    name: bind.comment,
                    iconName: "keyboard",
                    iconType: LauncherSearchResult.IconType.Material,
                    verb: keyStr,
                    type: Translation.tr("Keybind"),
                    comment: keyStr,
                    execute: () => {
                        Quickshell.clipboardText = keyStr;
                    }
                });
            }).filter(Boolean);
        } else if (root.query.startsWith(Config.options.search.prefix.symbols)) {
            // Material Symbols
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.symbols);
            return MaterialSymbolsSearch.fuzzyQuery(searchString).map(entry => {
                const tabIdx = entry.indexOf("\t");
                const symName = tabIdx >= 0 ? entry.slice(0, tabIdx) : entry;
                const symTags = tabIdx >= 0 ? entry.slice(tabIdx + 1) : "";
                return resultComp.createObject(null, {
                    rawValue: entry,
                    name: symName,
                    iconName: symName,
                    iconType: LauncherSearchResult.IconType.Material,
                    verb: Translation.tr("Copy"),
                    type: Translation.tr("Symbol"),
                    comment: symTags,
                    execute: () => {
                        Quickshell.clipboardText = symName;
                    }
                });
            }).filter(Boolean);
        } else if (Config.options.search.omni.enableAiShortcuts && /^(?:gpt|chatgpt|claude|ai)\b/i.test(root.query.trim())) {
            // Optional AI quick-launch prefixes: gpt, chatgpt, claude, ai
            const fullTrimmed = root.query.trim();
            const firstSpace = fullTrimmed.indexOf(" ");
            const prefix = (firstSpace !== -1 ? fullTrimmed.slice(0, firstSpace) : fullTrimmed).toLowerCase();
            const prompt = firstSpace !== -1 ? fullTrimmed.slice(firstSpace + 1).trim() : "";

            if (prefix === "claude") {
                return [resultComp.createObject(null, {
                    name: prompt || "Claude",
                    comment: prompt ? Translation.tr("Ask in Claude") : Translation.tr("Open Claude"),
                    verb: Translation.tr("Open"),
                    type: Translation.tr("AI Assistant"),
                    iconName: "claude-desktop",
                    iconType: LauncherSearchResult.IconType.System,
                    execute: () => {
                        GlobalStates.overviewOpen = false;
                        if (prompt) Quickshell.clipboardText = prompt;
                        Quickshell.execDetached([...root.helperCommand, "open-claude", prompt]);
                    }
                })];
            } else if (prefix === "gpt" || prefix === "chatgpt") {
                return [resultComp.createObject(null, {
                    name: prompt || "ChatGPT",
                    comment: prompt ? Translation.tr("Ask in ChatGPT (prompt copied)") : Translation.tr("Open ChatGPT"),
                    verb: Translation.tr("Open"),
                    type: Translation.tr("AI Assistant"),
                    iconName: "chatgpt",
                    iconType: LauncherSearchResult.IconType.System,
                    execute: () => {
                        GlobalStates.overviewOpen = false;
                        if (prompt) Quickshell.clipboardText = prompt;
                        Quickshell.execDetached([...root.helperCommand, "open-chatgpt", prompt]);
                    }
                })];
            }

            return [resultComp.createObject(null, {
                name: prompt || Translation.tr("ai [your question]"),
                comment: prompt ? Translation.tr("Send to sidebar AI chat") : Translation.tr("Open sidebar AI chat"),
                verb: Translation.tr("Ask"),
                type: Translation.tr("AI Assistant"),
                iconName: "neurology",
                iconType: LauncherSearchResult.IconType.Material,
                execute: () => {
                    GlobalStates.sidebarLeftOpen = true;
                    if (prompt) {
                        Qt.callLater(() => {
                            Ai.sendUserMessage(prompt);
                        });
                    }
                }
            })];
        } else if (Config.options.search.omni.enableSpotify && /^[pqPQ](\s+.*)?$/.test(root.query)) {
            // Optional Spotify Play (p <song>) or Queue (q <song>)
            const isPlay = root.query[0].toLowerCase() === "p";
            const songQuery = root.query.replace(/^[pqPQ]\s*/, "").trim();

            let historyItems = [];
            if (root.lastSpotifyHistoryQuery === songQuery.toLowerCase() && root.spotifyHistoryResults.length > 0) {
                historyItems = root.spotifyHistoryResults.map(h => {
                    return resultComp.createObject(null, {
                        name: `${isPlay ? "p" : "q"} ${h.text}`,
                        comment: (isPlay ? Translation.tr("Previously played") : Translation.tr("Previously queued")) + ` (${h.count || 1})`,
                        verb: isPlay ? Translation.tr("Play") : Translation.tr("Queue"),
                        type: Translation.tr("Spotify History"),
                        iconName: "history",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            if (h.uri) {
                                Quickshell.execDetached([...root.helperCommand, isPlay ? "spotify-play" : "spotify-queue", h.uri, h.text]);
                            } else {
                                Quickshell.execDetached([...root.helperCommand, isPlay ? "spotify-play-query" : "spotify-queue-query", h.text]);
                            }
                        }
                    });
                });
            }

            if (songQuery.length === 0) {
                const promptItem = resultComp.createObject(null, {
                    name: isPlay ? Translation.tr("Type a track to play on Spotify...") : Translation.tr("Type a track to queue on Spotify..."),
                    comment: isPlay ? Translation.tr("Example: p bohemian rhapsody") : Translation.tr("Example: q stairway to heaven"),
                    verb: isPlay ? Translation.tr("Play") : Translation.tr("Queue"),
                    type: "Spotify",
                    iconName: isPlay ? "play_circle" : "queue_music",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {}
                });
                return historyItems.length > 0 ? historyItems.concat([promptItem]) : [promptItem];
            }

            const directItem = resultComp.createObject(null, {
                name: songQuery,
                comment: isPlay ? Translation.tr("Search and play immediately on Spotify") : Translation.tr("Search and add to Spotify queue"),
                verb: isPlay ? Translation.tr("Play") : Translation.tr("Queue"),
                type: "Spotify",
                iconName: isPlay ? "play_circle" : "queue_music",
                iconType: LauncherSearchResult.IconType.Material,
                execute: () => {
                    Quickshell.execDetached([...root.helperCommand, isPlay ? "spotify-play-query" : "spotify-queue-query", songQuery]);
                }
            });

            if (root.lastSpotifyQuery === songQuery.toLowerCase() && root.spotifySearchResults.length > 0) {
                const trackItems = root.spotifySearchResults.map(track => {
                    return resultComp.createObject(null, {
                        name: track.display,
                        comment: (isPlay ? Translation.tr("Play on Spotify") : Translation.tr("Add to Spotify queue")) + (track.album ? ` • ${track.album}` : ""),
                        verb: isPlay ? Translation.tr("Play") : Translation.tr("Queue"),
                        type: "Spotify",
                        iconName: isPlay ? "play_circle" : "queue_music",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            Quickshell.execDetached([...root.helperCommand, isPlay ? "spotify-play" : "spotify-queue", track.uri, track.display]);
                        },
                        actions: [
                            resultComp.createObject(null, {
                                name: isPlay ? Translation.tr("Add to Queue") : Translation.tr("Play Now"),
                                iconName: isPlay ? "queue_music" : "play_arrow",
                                iconType: LauncherSearchResult.IconType.Material,
                                execute: () => {
                                    Quickshell.execDetached([...root.helperCommand, isPlay ? "spotify-queue" : "spotify-play", track.uri, track.display]);
                                }
                            })
                        ]
                    });
                });
                return historyItems.concat(trackItems).concat([directItem]);
            }

            return historyItems.concat([directItem]);
        }

        ////////////////// Init ///////////////////
        nonAppResultsTimer.restart();
        const mathResultObject = resultComp.createObject(null, {
            name: root.mathResult,
            verb: Translation.tr("Copy"),
            type: Translation.tr("Math result"),
            fontType: LauncherSearchResult.FontType.Monospace,
            iconName: 'calculate',
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                Quickshell.clipboardText = root.mathResult;
            }
        });
        const appResultObjects = AppSearch.fuzzyQuery(StringUtils.cleanPrefix(root.query, Config.options.search.prefix.app)).map(entry => {
            return resultComp.createObject(null, {
                type: Translation.tr("App"),
                id: entry.id,
                name: entry.name,
                iconName: entry.icon,
                iconType: LauncherSearchResult.IconType.System,
                verb: Translation.tr("Open"),
                execute: () => {
                    if (!entry.runInTerminal)
                        entry.execute();
                    else {
                        // Probably needs more proper escaping, but this will do for now
                        Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(entry.command.join(' '))}'`]);
                    }
                },
                comment: entry.comment,
                runInTerminal: entry.runInTerminal,
                genericName: entry.genericName,
                keywords: entry.keywords,
                actions: entry.actions.map(action => {
                    return resultComp.createObject(null, {
                        name: action.name,
                        iconName: action.icon,
                        iconType: LauncherSearchResult.IconType.System,
                        execute: () => {
                            if (!action.runInTerminal)
                                action.execute();
                            else {
                                Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(action.command.join(' '))}'`]);
                            }
                        }
                    });
                })
            });
        });
        ////////////////// Settings search //////////////////
        const settingsEntries = Config.options.settings.style === "dashboard" ? [] : SettingsSearchIndex.search(root.query, 8);
        const settingsResults = settingsEntries.map(entry => {
            const breadcrumb = entry.kind === "page" ? Translation.tr("Settings") : [entry.pageName, entry.kind === "option" ? entry.section : "", entry.kind === "option" ? entry.subsection : ""].filter(part => part).join(" › ");
            return resultComp.createObject(null, {
                control: entry.kind === "option" ? SettingsQuickControls.find(entry.pageId, entry.rawSection, entry.rawSubsection, entry.rawLabel) : null,
                name: entry.label,
                comment: breadcrumb,
                verb: Translation.tr("Go"),
                type: [Translation.tr("Settings"), entry.pageName, entry.kind === "option" ? entry.section : "", entry.kind === "option" ? entry.subsection : ""].filter(part => part).join(" • "),
                iconName: entry.icon,
                iconType: LauncherSearchResult.IconType.Material,
                execute: () => {
                    root.query = "";
                    GlobalStates.openSettingsAt(entry.pageId, entry.kind === "page" ? "" : entry.label, entry.section, entry.subsection);
                }
            });
        });
        const commandResultObject = resultComp.createObject(null, {
            name: StringUtils.cleanPrefix(root.query, Config.options.search.prefix.shellCommand).replace("file://", ""),
            verb: Translation.tr("Run"),
            type: Translation.tr("Command"),
            fontType: LauncherSearchResult.FontType.Monospace,
            iconName: 'terminal',
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                let cleanedCommand = root.query.replace("file://", "");
                cleanedCommand = StringUtils.cleanPrefix(cleanedCommand, Config.options.search.prefix.shellCommand);
                if (cleanedCommand.startsWith(Config.options.search.prefix.shellCommand)) {
                    cleanedCommand = cleanedCommand.slice(Config.options.search.prefix.shellCommand.length);
                }
                Quickshell.execDetached(["bash", "-c", root.query.startsWith('sudo') ? `${Config.options.apps.terminal} fish -C '${cleanedCommand}'` : cleanedCommand]);
            }
        });
        const webSearchResultObject = resultComp.createObject(null, {
            name: StringUtils.cleanPrefix(root.query, Config.options.search.prefix.webSearch),
            verb: Translation.tr("Search"),
            type: Translation.tr("Web search"),
            iconName: 'travel_explore',
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                let query = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.webSearch);
                let url = Config.options.search.engineBaseUrl + query;
                for (let site of Config.options.search.excludedSites) {
                    url += ` -site:${site}`;
                }
                Qt.openUrlExternally(url);
            }
        });
        const launcherActionObjects = root.allActions.map(action => {
            const actionString = `${Config.options.search.prefix.action}${action.action}`;
            if (actionString.startsWith(root.query) || root.query.startsWith(actionString)) {
                return resultComp.createObject(null, {
                    name: root.query.startsWith(actionString) ? root.query : actionString,
                    verb: Translation.tr("Run"),
                    type: Translation.tr("Action"),
                    iconName: 'settings_suggest',
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        action.execute(root.query.split(" ").slice(1).join(" "));
                    }
                });
            }
            return null;
        }).filter(Boolean);

        //////// File & Folder Search with "/" /////////
        if (Config.options.search.omni.enableFileSearch && root.query.startsWith("/")) {
            let fileItems = [];
            if (root.lastFileQuery === root.query && root.fileSearchResults.length > 0) {
                fileItems = root.fileSearchResults.map(item => {
                    return resultComp.createObject(null, {
                        name: item.path,
                        comment: item.comment,
                        verb: Translation.tr(item.verb),
                        type: item.is_dir ? Translation.tr("Folder") : Translation.tr("File"),
                        iconName: item.is_dir ? "folder" : "description",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            Quickshell.execDetached([...root.helperCommand, "file-open", item.path]);
                        }
                    });
                });
            } else {
                fileItems = [resultComp.createObject(null, {
                    name: root.query,
                    comment: `${root.query} — ${Translation.tr("Open in file manager")}`,
                    verb: Translation.tr("Open"),
                    type: Translation.tr("File"),
                    iconName: "folder_open",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        Quickshell.execDetached([...root.helperCommand, "file-open", root.query]);
                    }
                })];
            }

            const exactActionMatch = root.allActions.some(a => {
                const actStr = `${Config.options.search.prefix.action}${a.action}`;
                return root.query === actStr || root.query.startsWith(actStr + " ");
            });

            return exactActionMatch ? launcherActionObjects.concat(fileItems) : fileItems.concat(launcherActionObjects);
        }

        //////// Direct domain / URL -> open in Default Browser /////////
        const trimmedQuery = root.query.trim();
        let domainResultObject = null;
        if (Config.options.search.omni.enableDirectUrl) {
            const hasScheme = /^https?:\/\//i.test(trimmedQuery);
            const domainMatch = /^(?:https?:\/\/)?(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+([a-z]{2,24})(?::\d+)?(?:[\/?#]\S*)?$/i.exec(trimmedQuery);
            const fileExtLike = ["txt", "md", "py", "js", "sh", "json", "pdf", "png", "jpg", "jpeg", "qml", "lua", "conf", "ini", "zip", "log", "csv", "yml", "yaml", "html", "css", "cpp", "java", "mp3", "mp4"];
            const isDomain = domainMatch !== null && (hasScheme || !fileExtLike.includes(domainMatch[1].toLowerCase()));
            if (isDomain) {
                const targetUrl = hasScheme ? trimmedQuery : "https://" + trimmedQuery;
                domainResultObject = resultComp.createObject(null, {
                    name: trimmedQuery,
                    comment: Translation.tr("Open directly in browser"),
                    verb: Translation.tr("Open"),
                    type: Translation.tr("Website"),
                    iconName: 'language',
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        Quickshell.execDetached([...root.helperCommand, "open-url", targetUrl]);
                    }
                });
            }
        }

        //////// Prioritized by prefix /////////
        let result = root.quickToolResults(root.query);
        const quickCount = result.length;
        // "7m" or "timer 5 min" is a timer, not a unit conversion
        const startsWithNumber = /^\d/.test(root.query) && quickCount === 0;
        const startsWithMathPrefix = root.query.startsWith(Config.options.search.prefix.math);
        const startsWithShellCommandPrefix = root.query.startsWith(Config.options.search.prefix.shellCommand);
        const startsWithWebSearchPrefix = root.query.startsWith(Config.options.search.prefix.webSearch);
        if (startsWithNumber || startsWithMathPrefix) {
            result.push(mathResultObject);
        } else if (startsWithShellCommandPrefix) {
            result.push(commandResultObject);
        } else if (startsWithWebSearchPrefix) {
            result.push(webSearchResultObject);
        }        const startsWithMathPrefix = root.query.startsWith(Config.options.search.prefix.math);
        const startsWithShellCommandPrefix = root.query.startsWith(Config.options.search.prefix.shellCommand);
        const startsWithWebSearchPrefix = root.query.startsWith(Config.options.search.prefix.webSearch);
        if (startsWithNumber || startsWithMathPrefix) {
            result.push(mathResultObject);
        } else if (startsWithShellCommandPrefix) {
            result.push(commandResultObject);
        } else if (startsWithWebSearchPrefix) {
            result.push(webSearchResultObject);
        }

        //////////////// Apps //////////////////
        result = result.concat(appResultObjects);
        ////////////// Settings ////////////////
        result = result.concat(settingsResults);
        ////////// Launcher actions ////////////
        result = result.concat(launcherActionObjects);

        //////// Smart Suggestions (Browser History + Launcher History) /////////
        if (Config.options.search.omni.enableBrowserHistory && root.lastSuggestionQuery === trimmedQuery.toLowerCase() && root.smartSuggestions.length > 0) {
            for (let i = 0; i < root.smartSuggestions.length; i++) {
                const s = root.smartSuggestions[i];
                if (s.type === "browser_url" || s.type === "url") {
                    result.push(resultComp.createObject(null, {
                        name: s.text,
                        comment: (s.data ? `${s.data} • ` : "") + `${Translation.tr("Browser history")} (${s.count || 1})`,
                        verb: Translation.tr("Open"),
                        type: Translation.tr("Website"),
                        iconName: "history",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            Quickshell.execDetached([...root.helperCommand, "open-url", s.text]);
                        }
                    }));
                } else if (Config.options.search.omni.enableSpotify && s.type === "spotify_play") {
                    result.push(resultComp.createObject(null, {
                        name: `p ${s.text}`,
                        comment: `${Translation.tr("Recent track")}: ${s.text} (${s.count || 1})`,
                        verb: Translation.tr("Play"),
                        type: "Spotify",
                        iconName: "play_circle",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            if (s.data) {
                                Quickshell.execDetached([...root.helperCommand, "spotify-play", s.data, s.text]);
                            } else {
                                Quickshell.execDetached([...root.helperCommand, "spotify-play-query", s.text]);
                            }
                        }
                    }));
                } else if (Config.options.search.omni.enableSpotify && s.type === "spotify_queue") {
                    result.push(resultComp.createObject(null, {
                        name: `q ${s.text}`,
                        comment: `${Translation.tr("Recent queued track")}: ${s.text} (${s.count || 1})`,
                        verb: Translation.tr("Queue"),
                        type: "Spotify",
                        iconName: "queue_music",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            if (s.data) {
                                Quickshell.execDetached([...root.helperCommand, "spotify-queue", s.data, s.text]);
                            } else {
                                Quickshell.execDetached([...root.helperCommand, "spotify-queue-query", s.text]);
                            }
                        }
                    }));
                } else if (s.type === "search") {
                    result.push(resultComp.createObject(null, {
                        name: s.text,
                        comment: `${Translation.tr("Recent search")}: "${s.text}" (${s.count || 1})`,
                        verb: Translation.tr("Search"),
                        type: Translation.tr("Web search"),
                        iconName: "search",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            Quickshell.execDetached([...root.helperCommand, "open-search", s.text, Config.options.search.engineBaseUrl]);
                        }
                    }));
                } else if (s.type === "command") {
                    result.push(resultComp.createObject(null, {
                        name: s.text,
                        comment: `${Translation.tr("Recent command")}: ${s.text} (${s.count || 1})`,
                        verb: Translation.tr("Run"),
                        type: Translation.tr("Command"),
                        fontType: LauncherSearchResult.FontType.Monospace,
                        iconName: "terminal",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            Quickshell.execDetached([...root.helperCommand, "run-shell", s.text]);
                        }
                    }));
                }
            }
        }

        /// Math result, command, web search ///
        if (Config.options.search.prefix.showDefaultActionsWithoutPrefix) {
            if (!startsWithShellCommandPrefix)
                result.push(commandResultObject);
            if (!startsWithNumber && !startsWithMathPrefix && quickCount === 0)
                result.push(mathResultObject);
            if (!startsWithWebSearchPrefix)
                result.push(webSearchResultObject);
        }
        
        return result;
    }

    Component {
        id: resultComp
        LauncherSearchResult {}
    }
}
