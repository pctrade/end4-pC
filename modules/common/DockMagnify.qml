pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property var entries: []
    property int nextId: 0
    property var values: ({})
    property real totalExtra: 0
    property real amplitude: 0
    property real pointer: NaN
    property var window: null

    readonly property real sigma: 1.15

    function register(item) {
        const id = root.nextId++;
        root.entries.push({ id: id, item: item });
        return id;
    }

    function unregister(id) {
        root.entries = root.entries.filter(entry => entry.id !== id);
    }

    function clear() {
        if (Object.keys(root.values).length > 0) root.values = ({});
        if (root.totalExtra !== 0) root.totalExtra = 0;
    }

    function recompute() {
        if (!DockStyle.magnifying || root.amplitude <= 0.001 || !isFinite(root.pointer) || root.window === null) {
            root.clear();
            return;
        }

        const list = [];
        for (const entry of root.entries) {
            const item = entry.item;
            if (!item || !item.visible || !item.parent || item.QsWindow.window !== root.window) continue;
            const center = item.parent.mapToItem(null, item.x + item.width / 2, 0).x;
            list.push({ id: entry.id, center: center, base: Math.max(1, item.width) });
        }
        if (list.length === 0) {
            root.clear();
            return;
        }
        list.sort((a, b) => a.center - b.center);

        let unit = 0;
        if (list.length > 1) {
            unit = (list[list.length - 1].center - list[0].center) / (list.length - 1);
        } else {
            unit = list[0].base + 4;
        }
        unit = Math.max(unit, 1);

        const peak = (DockStyle.magnification - 1) * root.amplitude;

        function evaluate(pointerBase) {
            let before = 0;
            const out = [];
            for (const entry of list) {
                const distance = (pointerBase - entry.center) / unit;
                const scale = 1 + peak * Math.exp(-(distance * distance) / (2 * root.sigma * root.sigma));
                const extra = (scale - 1) * entry.base;
                out.push({ id: entry.id, center: entry.center, scale: scale, extra: extra, before: before });
                before += extra;
            }
            return { items: out, total: before };
        }

        function shiftAt(result, x) {
            const items = result.items;
            const shiftOf = it => it.before + it.extra / 2 - result.total / 2;
            if (x <= items[0].center) return shiftOf(items[0]);
            for (let i = 0; i < items.length - 1; ++i) {
                if (x <= items[i + 1].center) {
                    const t = (x - items[i].center) / Math.max(1, items[i + 1].center - items[i].center);
                    return shiftOf(items[i]) * (1 - t) + shiftOf(items[i + 1]) * t;
                }
            }
            return shiftOf(items[items.length - 1]);
        }

        let pointerBase = root.pointer;
        let result = evaluate(pointerBase);
        for (let i = 0; i < 3; ++i) {
            pointerBase = root.pointer - shiftAt(result, pointerBase);
            result = evaluate(pointerBase);
        }

        const next = {};
        for (const it of result.items)
            next[it.id] = { scale: it.scale, shift: it.before + it.extra / 2 - result.total / 2 };
        root.values = next;
        root.totalExtra = result.total;
    }

    onPointerChanged: root.recompute()
    onAmplitudeChanged: root.recompute()
}
