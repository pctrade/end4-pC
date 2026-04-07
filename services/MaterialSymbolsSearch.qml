pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Raw list loaded from JSON: [{name, tags, categories}]
    property var allSymbols: []

    // ── Load JSON ─────────────────────────────────────────────────────────
    FileView {
        id: symbolsFile
        path: Qt.resolvedUrl(`${Directories.config}/quickshell/ii/assets/material_symbols_rounded.json`)
        watchChanges: false
        onLoaded: {
            try {
                root.allSymbols = JSON.parse(symbolsFile.text());
            } catch (e) {
                console.warn("MaterialSymbolsSearch: failed to parse JSON –", e);
                root.allSymbols = [];
            }
        }
    }

    // ── Fuzzy search ──────────────────────────────────────────────────────
    // Returns a list of plain strings formatted as:
    //   "<name>  <tag1>, <tag2>, ..."
    function fuzzyQuery(query) {
        if (!query || query.length === 0)
            return root.allSymbols.slice(0, 30).map(sym => _format(sym));

        const q = query.toLowerCase();
        const scored = [];

        for (const sym of root.allSymbols) {
            const nameLower = sym.name.toLowerCase();

            // Exact name match → highest priority
            if (nameLower === q) {
                scored.push({ score: 100, sym });
                continue;
            }
            // Name starts-with
            if (nameLower.startsWith(q)) {
                scored.push({ score: 80, sym });
                continue;
            }
            // Name contains
            if (nameLower.includes(q)) {
                scored.push({ score: 60, sym });
                continue;
            }
            // Any tag exact / starts-with / contains
            let tagScore = 0;
            for (const tag of sym.tags) {
                const tl = tag.toLowerCase();
                if (tl === q)           { tagScore = Math.max(tagScore, 50); break; }
                if (tl.startsWith(q))   { tagScore = Math.max(tagScore, 35); }
                else if (tl.includes(q)){ tagScore = Math.max(tagScore, 20); }
            }
            // Fuzzy character match on name as fallback
            if (tagScore === 0) {
                let qi = 0;
                for (let i = 0; i < nameLower.length && qi < q.length; i++) {
                    if (nameLower[i] === q[qi]) qi++;
                }
                if (qi === q.length) tagScore = Math.max(tagScore, 10);
            }

            if (tagScore > 0)
                scored.push({ score: tagScore, sym });
        }

        scored.sort((a, b) => b.score - a.score);
        const limit = q.length <= 2 ? 50 : 200;
        return scored.slice(0, limit).map(s => _format(s.sym));
    }

    function _format(sym) {
        // Format: "<name>\t<tag1>, <tag2>, ..."
        return sym.name + "\t" + sym.tags.join(", ");
    }
}
