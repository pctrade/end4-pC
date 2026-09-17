import QtQuick
import qs.modules.common

MouseArea {
    id: root
    property int gridSize: 24
    property bool showGrid: false
    readonly property bool isWidgetCanvas: true
    readonly property bool gridVisible: showGrid && Config.options.background.showGrid

    property bool centerXActive: false
    property bool centerYActive: false

    // The item that paints the drag feedback (grid/center/selection/flash
    // lines). WidgetCanvas owns the interaction state; the visual host is
    // elevated above the depth wallpaper container by Background.qml.
    property Item visualHost: null

    property var registeredWidgets: []
    property bool selecting: false
    property point selectionStartPoint: Qt.point(0, 0)
    property rect selectionRect: Qt.rect(0, 0, 0, 0)

    property var groupDragMemberStarts: []
    property real groupDragStartX: 0
    property real groupDragStartY: 0

    function setDragging(active) {
        root.showGrid = active
        if (!active) {
            root.centerXActive = false
            root.centerYActive = false
        }
    }

    function setCenterActive(xActive, yActive) {
        root.centerXActive = xActive
        root.centerYActive = yActive
    }

    function registerWidget(widget) {
        root.registeredWidgets = root.registeredWidgets.concat([widget])
    }

    function unregisterWidget(widget) {
        root.registeredWidgets = root.registeredWidgets.filter(w => w !== widget)
    }

    // Widgets are positioned RELATIVE to the depth wallpaper layers. Layer
    // movement stays a pure layer-relative operation (forward = one layer
    // toward the front). On top of that, widgets sharing a layer carry a small
    // sub-order so overlapping widgets can be raised/lowered among themselves
    // without ever crossing a wallpaper layer.
    readonly property real depthLayerCount: Math.max(1, (Config.options.background.depthEffect.layers ?? []).length)

    function widgetByConfigName(key) {
        return root.registeredWidgets.find(w => w.configEntryName === key)
    }

    // Resolve the config object for any widget key: custom widgets live in
    // the customWidgets array (keyed by their id), everything else in the
    // keyed widgets object.
    function widgetEntryFromConfig(key) {
        const ids = Config.options.background.widgets.customWidgetIds ?? []
        if (ids.includes(key)) {
            const list = Config.options.background.widgets.customWidgets ?? []
            return list.find(w => w?.id === key) ?? null
        }
        return Config.options.background.widgets[key]
    }

    // list<var> entries are persisted/reactive only after a whole-list
    // reassignment (same pattern the depth-effect settings use for layers).
    function persistCustomWidget(entry) {
        if (!entry?.id) return
        const list = (Config.options.background.widgets.customWidgets ?? [])
            .map(w => (w.id === entry.id ? entry : w))
        Config.options.background.widgets.customWidgets = list
    }

    function isCustomWidgetKey(key) {
        return (Config.options.background.widgets.customWidgetIds ?? []).includes(key)
    }

    // Effective "above layer k-1" position for a widget. Out-of-range or
    // unset (-1) values mean the default = above the highest layer.
    function effectiveDepthPosition(key) {
        const entry = root.widgetEntryFromConfig(key)
        const raw = entry?.depthLayerPosition ?? -1
        return (raw > 0 && raw <= root.depthLayerCount) ? raw : root.depthLayerCount
    }

    // ── Widget-to-widget stacking (persisted, back -> front) ──────────────
    // The order list lives in config so overlapping widgets keep their
    // arrangement across restarts. Keys missing from the list (never
    // reordered) keep their registration order after the listed ones, i.e.
    // they default to the front.
    function stackOrderKeys() {
        const keys = root.registeredWidgets.map(w => w.configEntryName)
        const listed = (Config.options.background.widgets.widgetStackOrder ?? []).filter(k => keys.includes(k))
        return listed.concat(keys.filter(k => !listed.includes(k)))
    }

    // Offset added to a widget's layer-slot z. Mapped to (-0.4, 0.4) so it
    // always stays inside the slot (layer z is an integer; the widget slot
    // for depthPosition k is the open interval (k-1, k)).
    function stackOffset(key) {
        const keys = root.stackOrderKeys()
        const n = keys.length
        if (n <= 1) return 0
        const rank = keys.indexOf(key)
        if (rank < 0) return 0
        return ((rank + 1) / (n + 1)) * 0.8 - 0.4
    }

    function _persistStackOrder(order) {
        // Keep keys belonging to other contexts (e.g. other screens) so this
        // screen's reorder never drops them.
        const known = root.registeredWidgets.map(w => w.configEntryName)
        const others = (Config.options.background.widgets.widgetStackOrder ?? []).filter(k => !known.includes(k))
        Config.options.background.widgets.widgetStackOrder = order.concat(others)
    }

    function _reorderStack(key, toFront) {
        const keys = root.stackOrderKeys().filter(k => k !== key)
        if (toFront) keys.push(key)
        else keys.unshift(key)
        root._persistStackOrder(keys)
    }

    // The widgets sharing this key's layer, back -> front. Widget order only
    // matters within one layer, since a one-step z difference between layers
    // always dominates the sub-order offset.
    function _sameDepthGroup(key) {
        const pos = root.effectiveDepthPosition(key)
        return root.stackOrderKeys().filter(k => {
            const w = root.widgetByConfigName(k)
            return w && !w.pinnedBottom && root.effectiveDepthPosition(k) === pos
        })
    }

    // Layers first: a widget can always step toward the front while it is not
    // on the front-most layer; once there, it can be raised above the other
    // widgets sharing that layer.
    function canMoveFront(key) {
        if (root.widgetByConfigName(key)?.pinnedBottom) return false
        if (root.effectiveDepthPosition(key) < root.depthLayerCount) return true
        const group = root._sameDepthGroup(key)
        return group.length > 1 && group.indexOf(key) < group.length - 1
    }

    function canMoveBack(key) {
        if (root.widgetByConfigName(key)?.pinnedBottom) return false
        if (root.effectiveDepthPosition(key) > 1) return true
        const group = root._sameDepthGroup(key)
        return group.length > 1 && group.indexOf(key) > 0
    }

    // Layers first, then widget order: step one layer toward the front while
    // not on the front-most layer; once there, raise the widget above the
    // others sharing that layer.
    function moveLayerFront(widget) {
        if (widget?.pinnedBottom) return
        const key = widget.configEntryName
        if (root.effectiveDepthPosition(key) < root.depthLayerCount) {
            const entry = root.widgetEntryFromConfig(key)
            if (!entry) return
            entry.depthLayerPosition = root.effectiveDepthPosition(key) + 1
            if (root.isCustomWidgetKey(key)) root.persistCustomWidget(entry)
        } else {
            root._reorderStack(key, true)
        }
    }

    // Mirror of moveLayerFront toward the back: the first click from the
    // default (above-highest) position drops it right behind the highest
    // layer; on the back-most layer it lowers the widget below its peers.
    function moveLayerBack(widget) {
        if (widget?.pinnedBottom) return
        const key = widget.configEntryName
        if (root.effectiveDepthPosition(key) > 1) {
            const entry = root.widgetEntryFromConfig(key)
            if (!entry) return
            entry.depthLayerPosition = root.effectiveDepthPosition(key) - 1
            if (root.isCustomWidgetKey(key)) root.persistCustomWidget(entry)
        } else {
            root._reorderStack(key, false)
        }
    }

    function clearSelection() {
        for (const widget of root.registeredWidgets) widget.selected = false
    }

    function rectsIntersect(a, b) {
        return a.x < b.x + b.width && a.x + a.width > b.x
            && a.y < b.y + b.height && a.y + a.height > b.y
    }

    function selectWithinRect(rect) {
        for (const widget of root.registeredWidgets) {
            const widgetRect = Qt.rect(widget.x, widget.y, widget.width, widget.height)
            widget.selected = root.rectsIntersect(rect, widgetRect)
        }
    }

    function beginGroupDrag(initiator) {
        if (!initiator.selected) {
            root.groupDragMemberStarts = []
            return
        }
        root.groupDragStartX = initiator.x
        root.groupDragStartY = initiator.y
        root.groupDragMemberStarts = root.registeredWidgets
            .filter(w => w.selected && w !== initiator)
            .map(w => ({ widget: w, startX: w.x, startY: w.y }))
        for (const entry of root.groupDragMemberStarts) entry.widget.groupDragActive = true
    }

    function updateGroupDrag(initiator) {
        if (root.groupDragMemberStarts.length === 0) return
        const dx = initiator.x - root.groupDragStartX
        const dy = initiator.y - root.groupDragStartY
        for (const entry of root.groupDragMemberStarts) {
            entry.widget.x = entry.startX + dx
            entry.widget.y = entry.startY + dy
        }
    }

    function endGroupDrag() {
        for (const entry of root.groupDragMemberStarts) {
            entry.widget.groupDragActive = false
            entry.widget.commitPosition()
        }
        root.groupDragMemberStarts = []
    }

    onPressed: (mouse) => {
        if (Config.options.background.widgetsLocked) return
        root.selecting = true
        root.selectionStartPoint = Qt.point(mouse.x, mouse.y)
        root.selectionRect = Qt.rect(mouse.x, mouse.y, 0, 0)
        if (!(mouse.modifiers & Qt.ControlModifier)) root.clearSelection()
    }

    onPositionChanged: (mouse) => {
        if (!root.selecting) return
        const startX = root.selectionStartPoint.x
        const startY = root.selectionStartPoint.y
        const rectX = Math.min(startX, mouse.x)
        const rectY = Math.min(startY, mouse.y)
        const rectW = Math.abs(mouse.x - startX)
        const rectH = Math.abs(mouse.y - startY)
        root.selectionRect = Qt.rect(rectX, rectY, rectW, rectH)
        root.selectWithinRect(root.selectionRect)
    }

    onReleased: {
        root.selecting = false
    }

    function flashLines(verticalPositions, horizontalPositions) {
        if (root.visualHost)
            root.visualHost.flashLines(verticalPositions, horizontalPositions)
    }
}