import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root
    property real innerInset: 0
    property real outerInset: 0
    property bool magnifiable: false
    property int magnifyId: -1
    readonly property var magnifyValue: root.magnifyId >= 0 ? (DockMagnify.values[root.magnifyId] ?? null) : null
    readonly property bool magnifyActive: DockStyle.magnifying && root.magnifiable
    readonly property real naturalWidth: DockStyle.vertical
        ? implicitBackgroundWidth + leftInset + rightInset
        : implicitHeight - topInset - bottomInset

    Layout.fillHeight: !DockStyle.vertical
    Layout.fillWidth: DockStyle.vertical
    Layout.topMargin: DockStyle.mTop(DockStyle.buttonInnerMargin, 0)
    Layout.leftMargin: DockStyle.mLeft(DockStyle.buttonInnerMargin, 0)
    topInset: DockStyle.mTop(innerInset, outerInset)
    bottomInset: DockStyle.mBottom(innerInset, outerInset)
    leftInset: DockStyle.mLeft(innerInset, outerInset)
    rightInset: DockStyle.mRight(innerInset, outerInset)
    implicitWidth: naturalWidth
    buttonRadius: Appearance.rounding.normal

    transformOrigin: Item.Bottom
    scale: root.magnifyActive && root.magnifyValue ? root.magnifyValue.scale : 1
    z: root.magnifyActive && root.magnifyValue ? root.magnifyValue.scale : 0
    transform: Translate { x: root.magnifyActive && root.magnifyValue ? root.magnifyValue.shift : 0 }


    Component.onCompleted: if (root.magnifiable) root.magnifyId = DockMagnify.register(root)
    Component.onDestruction: DockMagnify.unregister(root.magnifyId)

    // Windows that scrolling on this button cycles through (app buttons only).
    property var scrollWindows: []
    property real wheelAccum: 0
    // Last window this button's scrolling activated. Focus (`activated`) only
    // updates once the compositor confirms it, so quick steps use this instead.
    property var wheelTarget: null
    signal windowCycled(int index)

    Timer {
        id: wheelTargetReset
        interval: 600
        onTriggered: root.wheelTarget = null
    }

    WheelHandler {
        enabled: (Config.options.dock.scrollToCycleWindows ?? false) && (root.scrollWindows?.length ?? 0) > 0
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            // Touchpads send many small deltas; step once per mouse-wheel notch (120).
            root.wheelAccum += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
            if (Math.abs(root.wheelAccum) < 120)
                return;
            const step = root.wheelAccum > 0 ? -1 : 1; // scroll down = next window
            root.wheelAccum = 0;
            const list = root.scrollWindows;
            let current = root.wheelTarget ? list.indexOf(root.wheelTarget) : -1;
            if (current < 0)
                current = list.findIndex(t => t.activated);
            const next = current < 0
                ? (step > 0 ? 0 : list.length - 1)
                : (current + step + list.length) % list.length;
            root.wheelTarget = list[next];
            wheelTargetReset.restart();
            list[next].activate();
            root.windowCycled(next);
        }
    }

    background.implicitHeight: DockStyle.buttonBase
    background.implicitWidth: DockStyle.buttonBase
}
