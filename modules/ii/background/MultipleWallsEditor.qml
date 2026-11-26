import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    required property var collage

    readonly property var result: root.collage.result
    readonly property bool canSplit: Collage.leafCount < Collage.maxTiles
    readonly property bool canRemove: Collage.leafCount > 1

    Repeater {
        model: ScriptModel {
            values: root.result.leaves
            objectProp: "id"
        }

        delegate: Item {
            id: tileControls
            required property var modelData
            readonly property bool primary: modelData.id === Collage.primaryId

            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h

            Behavior on x { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on width { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on height { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            RippleButton {
                id: starButton
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 10
                implicitWidth: 38
                implicitHeight: 38
                buttonRadius: Appearance.rounding.full
                toggled: tileControls.primary
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.25)
                colBackgroundToggled: Appearance.colors.colPrimary
                colBackgroundToggledHover: Appearance.colors.colPrimaryHover
                onClicked: Collage.setPrimary(tileControls.modelData.id)

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "star"
                    fill: tileControls.primary ? 1 : 0
                    iconSize: 22
                    color: tileControls.primary ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                }

                StyledToolTip {
                    text: Translation.tr("Use this wallpaper for colors and backdrop")
                }
            }

            Rectangle {
                id: actionPill
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                implicitWidth: actionRow.implicitWidth + 12
                implicitHeight: 44
                radius: Appearance.rounding.full
                color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.15)

                RowLayout {
                    id: actionRow
                    anchors.centerIn: parent
                    spacing: 2

                    component TileAction: RippleButton {
                        id: action
                        property string symbol
                        property string tip
                        implicitWidth: 36
                        implicitHeight: 36
                        buttonRadius: Appearance.rounding.full
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: action.symbol
                            iconSize: 20
                            color: action.enabled ? Appearance.colors.colOnLayer0 : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.6)
                        }
                        StyledToolTip {
                            text: action.tip
                        }
                    }

                    TileAction {
                        symbol: "wallpaper"
                        tip: Translation.tr("Change image (or drop a file on the tile)")
                        onClicked: Collage.pickImage(tileControls.modelData.id)
                    }
                    TileAction {
                        symbol: "splitscreen_vertical_add"
                        tip: Translation.tr("Split side by side")
                        enabled: root.canSplit
                        onClicked: Collage.splitLeaf(tileControls.modelData.id, "v")
                    }
                    TileAction {
                        symbol: "splitscreen_add"
                        tip: Translation.tr("Split top and bottom")
                        enabled: root.canSplit
                        onClicked: Collage.splitLeaf(tileControls.modelData.id, "h")
                    }
                    TileAction {
                        symbol: "delete"
                        tip: Translation.tr("Remove")
                        enabled: root.canRemove
                        onClicked: Collage.removeLeaf(tileControls.modelData.id)
                    }
                }
            }
        }
    }

    Repeater {
        model: ScriptModel {
            values: root.result.splits
            objectProp: "path"
        }

        delegate: MouseArea {
            id: gutter
            required property var modelData
            readonly property bool vertical: modelData.d === "v"
            readonly property real hitSize: Math.max(Collage.gap, 20)

            x: vertical ? modelData.line - hitSize / 2 : modelData.from
            y: vertical ? modelData.from : modelData.line - hitSize / 2
            width: vertical ? hitSize : modelData.to - modelData.from
            height: vertical ? modelData.to - modelData.from : hitSize
            hoverEnabled: true
            preventStealing: true
            cursorShape: vertical ? Qt.SplitHCursor : Qt.SplitVCursor

            function ratioAt(mouse) {
                const point = gutter.mapToItem(root, mouse.x, mouse.y)
                const area = root.result.area
                return vertical
                    ? ((point.x - area.x) / area.w - modelData.fx) / modelData.fw
                    : ((point.y - area.y) / area.h - modelData.fy) / modelData.fh
            }

            property bool moved: false

            onPressed: {
                gutter.moved = false
                Collage.dragging = true
            }
            onPositionChanged: mouse => {
                if (!pressed) return
                gutter.moved = true
                const ratio = Math.max(0.15, Math.min(0.85, gutter.ratioAt(mouse)))
                const next = Object.assign({}, Collage.liveRatios)
                next[modelData.path] = ratio
                Collage.liveRatios = next
            }
            onReleased: mouse => {
                if (gutter.moved) Collage.setRatio(modelData.path, gutter.ratioAt(mouse))
                Collage.liveRatios = ({})
                Collage.dragging = false
            }
            onCanceled: {
                Collage.liveRatios = ({})
                Collage.dragging = false
            }
            onDoubleClicked: Collage.setRatio(modelData.path, 0.5)

            Rectangle {
                anchors.centerIn: parent
                width: gutter.vertical ? 4 : Math.min(parent.width, 80)
                height: gutter.vertical ? Math.min(parent.height, 80) : 4
                radius: 2
                color: Appearance.colors.colPrimary
                opacity: gutter.containsMouse || gutter.pressed ? 1 : 0.55
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
        }
    }
}
