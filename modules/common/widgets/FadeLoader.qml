import QtQuick

import qs.modules.common

Loader {
    id: root
    property bool shown: true
    property alias fade: opacityBehavior.enabled
    property alias animation: opacityBehavior.animation
    property var canvas: null
    opacity: shown ? 1 : 0
    visible: opacity > 0
    active: opacity > 0
    z: item?.z ?? 0

    // Widgets registered to the same canvas even when not direct children.
    onItemChanged: if (root.item && root.item.canvas !== undefined) root.item.canvas = root.canvas

    Behavior on opacity {
        id: opacityBehavior
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }
}