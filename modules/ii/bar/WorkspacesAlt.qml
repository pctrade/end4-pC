pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import QtQuick

Item {
    id: root

    required property var host
    required property var model

    readonly property string style: Config.options.bar.workspaces.style
    readonly property bool vertical: root.host.vertical
    readonly property real slot: root.host.slotLength
    readonly property int count: root.model.shownCount
    readonly property bool hovering: root.host.containsMouse
    readonly property color activeColor: Appearance.colors.colPrimary
    readonly property color occupiedColor: root.host.contentColorOverridden ? root.host.contentColor : Appearance.colors.colOnLayer1
    readonly property color emptyColor: root.host.contentColorOverridden ? Qt.alpha(root.host.contentColor, 0.35) : Appearance.colors.colOnLayer1Inactive

    readonly property real gnomeExtra: root.style === "gnome" ? 16 : 0

    implicitWidth: root.vertical ? root.host.barThickness : root.count * root.slot + root.gnomeExtra
    implicitHeight: root.vertical ? root.count * root.slot + root.gnomeExtra : root.host.barThickness

    function indexAt(position) {
        if (root.gnomeExtra === 0) return Math.floor(position / root.slot)
        const active = root.host.workspaceIndexInGroup
        const activeEnd = (active + 1) * root.slot + root.gnomeExtra
        if (position < active * root.slot) return Math.floor(position / root.slot)
        if (position < activeEnd) return active
        return active + 1 + Math.floor((position - activeEnd) / root.slot)
    }

    function occupied(index) {
        return root.model.occupied[index] && root.model.getWorkspaceIdAt(index) !== root.model.fakeWorkspace
    }

    Repeater {
        model: root.count

        delegate: Item {
            id: cell

            required property int index
            readonly property bool active: cell.index === root.host.workspaceIndexInGroup
            readonly property bool isOccupied: root.occupied(cell.index)
            readonly property bool hovered: root.hovering && root.host.hoverIndex === cell.index
            readonly property color tone: cell.active ? root.activeColor : (cell.isOccupied ? root.occupiedColor : root.emptyColor)

            property real cellStart: cell.index * root.slot + (cell.index > root.host.workspaceIndexInGroup ? root.gnomeExtra : 0)
            property real cellLength: root.slot + (cell.active ? root.gnomeExtra : 0)

            Behavior on cellStart {
                enabled: root.style === "gnome"
                NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
            }
            Behavior on cellLength {
                enabled: root.style === "gnome"
                NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
            }

            x: root.vertical ? 0 : cell.cellStart
            y: root.vertical ? cell.cellStart : 0
            width: root.vertical ? root.width : cell.cellLength
            height: root.vertical ? cell.cellLength : root.height

            Loader {
                anchors.centerIn: parent
                sourceComponent: {
                    switch (root.style) {
                        case "dots": return dotMark
                        case "ticks": return tickMark
                        default: return gnomeMark
                    }
                }
            }

            Component {
                id: gnomeMark

                Rectangle {
                    readonly property real longSide: cell.active ? 26 : 10
                    width: root.vertical ? 10 : longSide
                    height: root.vertical ? longSide : 10
                    radius: 5
                    color: cell.tone
                    opacity: cell.active || cell.isOccupied || cell.hovered ? 1 : 0.8

                    Behavior on width {
                        NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                    }
                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                }
            }

            Component {
                id: tickMark

                Rectangle {
                    readonly property real longSide: (cell.active ? 22 : cell.isOccupied ? 14 : 8) + (cell.hovered ? 4 : 0)
                    width: root.vertical ? longSide : 5
                    height: root.vertical ? 5 : longSide
                    radius: 2.5
                    color: cell.tone

                    Behavior on width {
                        NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
                    }
                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                }
            }

            Component {
                id: dotMark

                Rectangle {
                    id: dot
                    property real popScale: cell.hovered && !cell.active ? 1.4 : 1
                    width: cell.isOccupied ? 9 : 7
                    height: width
                    radius: width / 2
                    scale: dot.popScale
                    color: cell.active ? "transparent" : cell.tone

                    Behavior on popScale {
                        SpringAnimation { spring: 6; damping: 0.3; epsilon: 0.01 }
                    }
                    Behavior on width {
                        NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2 }
                    }
                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                }
            }
        }
    }

    Loader {
        active: root.style === "dots"
        anchors.fill: parent

        sourceComponent: Item {
            id: blobLayer

            readonly property real blobSize: 12
            property real pop: 1

            property var pair: AnimatedTabIndexPair {
                index: root.host.workspaceIndexInGroup
                idx1Duration: 90
                idx2Duration: 330
            }

            readonly property real start: Math.min(pair.idx1, pair.idx2)
            readonly property real span: Math.abs(pair.idx1 - pair.idx2)
            readonly property real squash: 1 - 0.3 * Math.min(1, blobLayer.span / 1.5)

            Connections {
                target: root.host
                function onWorkspaceIndexInGroupChanged() { popAnim.restart() }
            }

            SequentialAnimation {
                id: popAnim
                NumberAnimation { target: blobLayer; property: "pop"; to: 1.35; duration: 110; easing.type: Easing.OutQuad }
                NumberAnimation { target: blobLayer; property: "pop"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 3 }
            }

            Rectangle {
                readonly property real length: (blobLayer.span * root.slot + blobLayer.blobSize) * (blobLayer.span > 0.05 ? 1 : blobLayer.pop)
                readonly property real thickness: blobLayer.blobSize * blobLayer.squash * (blobLayer.span > 0.05 ? 1 : blobLayer.pop)
                readonly property real offset: blobLayer.start * root.slot + (root.slot - blobLayer.blobSize) / 2 - (length - (blobLayer.span * root.slot + blobLayer.blobSize)) / 2

                x: root.vertical ? (parent.width - thickness) / 2 : offset
                y: root.vertical ? offset : (parent.height - thickness) / 2
                width: root.vertical ? thickness : length
                height: root.vertical ? length : thickness
                radius: Math.min(width, height) / 2
                color: root.activeColor
            }
        }
    }
}
