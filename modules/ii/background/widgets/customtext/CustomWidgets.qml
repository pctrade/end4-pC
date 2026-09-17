import QtQuick
import qs
import qs.modules.common

/**
 * CRUD helpers for fully independent custom text widgets.
 *
 * Custom widgets are stored as entries in `background.widgets.customWidgets`
 * (a `list<var>`, exactly like the depth-effect `layers` patern: the list is
 * reassigned after every mutation so the running config tree persists and
 * reacts to changes). Each entry carries its own `id`; `customWidgetIds` is
 * the ordered index WidgetsLoader renders and WidgetCanvas uses to recognize
 * custom widgets.
 */
QtObject {
    id: root

    readonly property var _rootCfg: Config.options.background.widgets

    function all() {
        return (root._rootCfg.customWidgets ?? []).slice()
    }

    function find(id) {
        return root.all().find(w => w?.id === id) ?? null
    }

    // Persist and NOTIFY in one step. Every write stores a FRESH shallow copy
    // of the entry, so `var configEntry` bindings (widget position, settings
    // fields) always receive a brand-new object and re-evaluate. Mutating a
    // list<var> element in place is invisible to QML bindings — that was the
    // root cause of positions going stale after a manual X/Y edit or a drag,
    // so the copy is the single source of truth, not the shared instance.
    function save(entry) {
        if (!entry?.id) return
        const list = root.all().map(w => (w.id === entry.id ? Object.assign({}, entry) : Object.assign({}, w)))
        root._rootCfg.customWidgets = list
        root._ensureId(entry.id)
    }

    function _ensureId(id) {
        const ids = [...root._rootCfg.customWidgetIds]
        if (!ids.includes(id)) {
            ids.push(id)
            root._rootCfg.customWidgetIds = ids
        }
    }

    function _generateId() {
        return "custom_"
            + Date.now().toString(36)
            + "_"
            + Math.floor(Math.random() * 1e9).toString(36)
    }

    // Pixel center point of the widget on a screen of the given size.
    function centerFor(defScreenWidth, defScreenHeight) {
        return Qt.point(defScreenWidth / 2, defScreenHeight / 2)
    }

    function addDefaults(defScreenWidth, defScreenHeight) {
        const id = root._generateId()
        const c = root.centerFor(defScreenWidth, defScreenHeight)
        const entry = {
            id: id,
            enable: true,
            // content
            text: "EEEE, dd MMMM yyyy",
            // typography
            fontSource: "system",
            fontFamily: "",
            appliedFont: "",
            fontSize: 48,
            fontSizeUnit: "px",
            fontWeight: 400,
            fontItalic: false,
            fontSolid: true,
            // text color
            textColor: "",
            // outline
            outlineColor: "",
            outlineWidth: 2,
            // layout
            letterSpacing: 0,
            lineHeight: 1.0,
            opacity: 1.0,
            rotation: 0,
            textAlignment: "center",
            // badge
            badge: false,
            badgeSolid: true,
            badgeColor: "",
            badgeBlur: 0,
            badgeSameRadius: true,
            badgeRadiusTL: 16,
            badgeRadiusTR: 16,
            badgeRadiusBL: 16,
            badgeRadiusBR: 16,
            badgeSamePadding: true,
            badgePaddingTop: 8,
            badgePaddingRight: 12,
            badgePaddingBottom: 8,
            badgePaddingLeft: 12,
            // position (center coordinates in px)
            x: c.x,
            y: c.y,
            xUnit: "px",
            yUnit: "px",
            // depth
            depthLayerPosition: -1,
            placementStrategy: "free",
            // interaction
            draggable: true
        }
        root._rootCfg.customWidgets = root.all().concat([entry])
        root._ensureId(id)
        return id
    }

    function remove(id) {
        root._rootCfg.customWidgets = root.all().filter(w => w.id !== id)
        root._rootCfg.customWidgetIds = root._rootCfg.customWidgetIds.filter(i => i !== id)
    }

    function duplicate(id) {
        const src = root.find(id)
        if (!src) return ""
        const newId = root._generateId()
        const copy = JSON.parse(JSON.stringify(src))
        copy.id = newId
        copy.enable = true
        copy.depthLayerPosition = -1
        root._rootCfg.customWidgets = root.all().concat([copy])
        root._ensureId(newId)
        return newId
    }

    // Resolve the config object for any widget key:
    // custom widgets come from the array, everything else from the keyed object.
    function entryByKey(key) {
        if ((root._rootCfg.customWidgetIds ?? []).includes(key)) {
            return root.find(key)
        }
        return root._rootCfg[key]
    }

    function isCustom(key) {
        return (root._rootCfg.customWidgetIds ?? []).includes(key)
    }
}