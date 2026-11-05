pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common.functions

Singleton {
    id: root

    property var entriesByPage: ({})

    readonly property var labelledTypes: [
        "ConfigSwitch", "ConfigSpinBox", "ConfigTextArea", "ConfigSelectionArray",
        "ConfigComboBox", "ConfigSlider", "ConfigSelectionShapeArray", "ConfigRow",
        "ColorSelectionArray", "ContentSubsection"
    ]

    function parsePage(source) {
        const typeOpen = /^\s*([A-Z][\w.]*)\s*\{/;
        const labelProp = /^\s*(title|text):\s*Translation\.tr\(\s*(?:"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)')\s*\)/;
        const entries = [];
        const stack = [];
        let section = "";
        let subsection = "";
        for (const line of source.split("\n")) {
            const prop = line.match(labelProp);
            const type = stack.length > 0 ? stack[stack.length - 1] : null;
            if (prop && type) {
                const label = (prop[2] ?? prop[3]).replace(/\\(["'])/g, "$1");
                if (type === "ContentSection" && prop[1] === "title") {
                    section = label;
                    subsection = "";
                    entries.push({ kind: "section", section: label, subsection: "", label: label });
                } else if (root.labelledTypes.includes(type)) {
                    entries.push({ kind: "option", section: section, subsection: type === "ContentSubsection" ? "" : subsection, label: label });
                    if (type === "ContentSubsection") subsection = label;
                }
            }
            const opens = (line.match(/\{/g) || []).length;
            const closes = (line.match(/\}/g) || []).length;
            for (let i = 0; i < closes; i++) stack.pop();
            const typeMatch = line.match(typeOpen);
            for (let i = 0; i < opens; i++) stack.push(i === 0 && typeMatch ? typeMatch[1] : null);
        }
        return entries;
    }

    // Pages are parsed as their files load but published together: every
    // assignment re-runs the launcher results, apps included, so publishing
    // page by page rebuilt them once per page right under the first keystroke
    property var pendingEntries: ({})
    function indexPage(pageId, source) {
        root.pendingEntries[pageId] = root.parsePage(source);
        if (Object.keys(root.pendingEntries).length >= SettingsPages.pages.length)
            root.entriesByPage = Object.assign({}, root.pendingEntries);
    }

    function search(query, limit) {
        const tokens = query.toLowerCase().trim().split(/\s+/).filter(t => t.length > 0);
        if (tokens.length === 0) return [];

        const results = [];
        for (const page of SettingsPages.pages) {
            const pageName = page.name.toLowerCase();
            const pageScore = root.scoreText(pageName, tokens);
            if (pageScore > 0) {
                results.push({
                    pageId: page.id, pageName: page.name, icon: page.icon,
                    kind: "page", section: "", label: page.name, score: pageScore + 50
                });
            }
            for (const entry of (root.entriesByPage[page.id] ?? [])) {
                const label = Translation.tr(entry.label);
                const section = Translation.tr(entry.section);
                const haystack = (label + " " + entry.label + " " + section + " " + pageName).toLowerCase();
                if (!tokens.every(t => haystack.includes(t))) continue;
                const labelScore = Math.max(
                    root.scoreText(label.toLowerCase(), tokens),
                    root.scoreText(entry.label.toLowerCase(), tokens)
                );
                results.push({
                    pageId: page.id, pageName: page.name, icon: page.icon,
                    kind: entry.kind, section: section, label: label, rawLabel: entry.label, rawSection: entry.section, subsection: Translation.tr(entry.subsection ?? ""), rawSubsection: entry.subsection ?? "",
                    score: labelScore + (entry.kind === "section" ? 10 : 0)
                });
            }
        }
        results.sort((a, b) => b.score - a.score);
        return results.slice(0, limit);
    }

    function scoreText(text, tokens) {
        let score = 0;
        for (const token of tokens) {
            const at = text.indexOf(token);
            if (at < 0) continue;
            if (text === token) score += 100;
            else if (at === 0) score += 60;
            else if (text[at - 1] === " ") score += 40;
            else score += 20;
        }
        return score;
    }

    Instantiator {
        model: SettingsPages.pages
        delegate: FileView {
            required property var modelData
            path: FileUtils.trimFileProtocol(Quickshell.shellPath(modelData.path))
            onLoaded: root.indexPage(modelData.id, text())
            onLoadFailed: root.indexPage(modelData.id, "")
        }
    }
}
