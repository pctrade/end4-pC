import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Smart Drop. While something is dragged over the island the pill splits into one zone per action that fits
// it (services/SmartDrop.qml); a highlight glides to the zone under the pointer like it's being pulled there,
// and that zone's icon hops up. After the drop it says what happened.
Item {
    id: dropState
    required property Item di
    anchors.fill: parent

    readonly property bool hovering: dropState.di.dropHovering
    readonly property var added: dropState.di.lastShelfAdded
    readonly property var actions: dropState.di.dropActions
    readonly property var feedback: dropState.di.dropFeedback
    readonly property real zoneWidth: (dropState.width - 8) / Math.max(1, dropState.actions.length)

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: height / 2
        color: ColorUtils.transparentize(Appearance.colors.colPrimary, dropState.hovering ? 0.9 : 1)
        border.width: 1.5
        border.color: dropState.hovering ? Appearance.colors.colPrimary : Appearance.m3colors.m3success
    }

    // ── While dragging: the zones ──
    Item {
        anchors.fill: parent
        anchors.margins: 4
        visible: dropState.hovering && dropState.actions.length > 0

        Rectangle {
            id: highlight
            x: dropState.di.dropZone * dropState.zoneWidth
            y: 0
            width: dropState.zoneWidth
            height: parent.height
            radius: height / 2
            color: Appearance.colors.colPrimaryContainer

            Behavior on x {
                NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
            }
        }

        Row {
            anchors.fill: parent

            Repeater {
                model: dropState.actions
                delegate: Item {
                    id: zone
                    required property string modelData
                    required property int index
                    readonly property bool aimed: dropState.di.dropZone === zone.index
                    readonly property var spec: SmartDrop.catalog[zone.modelData] ?? { icon: "help", label: zone.modelData }
                    width: dropState.zoneWidth
                    height: parent.height

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialSymbol {
                            text: zone.spec.icon
                            iconSize: 15
                            fill: 1
                            color: zone.aimed ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer0
                            opacity: zone.aimed ? 1 : 0.6
                            transform: Translate { y: zone.aimed ? -1.5 : 0 }
                            scale: zone.aimed ? 1.15 : 1

                            Behavior on scale {
                                NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                            }
                        }
                        StyledText {
                            text: zone.spec.label
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: zone.aimed ? Font.DemiBold : Font.Normal
                            color: zone.aimed ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer0
                            opacity: zone.aimed ? 1 : 0.6
                        }
                    }

                    // Dealt in from the left as the pill opens
                    opacity: 0
                    NumberAnimation on opacity {
                        running: dropState.hovering
                        from: 0
                        to: 1
                        duration: 260
                    }
                }
            }
        }
    }

    // ── After the drop: what happened ──
    RowLayout {
        visible: !dropState.hovering
        anchors {
            fill: parent
            leftMargin: 4
            rightMargin: 14
        }
        spacing: 8

        MaterialShapeWrappedMaterialSymbol {
            wrappedShape: MaterialShape.Shape.Circle
            color: Appearance.m3colors.m3success
            colSymbol: Appearance.colors.colOnPrimary
            text: dropState.feedback?.icon ?? "check"
            iconSize: 16
            fill: 1
            padding: 5
            scale: 0.3

            NumberAnimation on scale {
                running: !dropState.hovering
                from: 0.3
                to: 1
                duration: 480
                easing.type: Easing.OutBack
                easing.overshoot: 2.4
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -3

            StyledText {
                Layout.fillWidth: true
                text: dropState.feedback?.label ?? Translation.tr("Kept in the drawer")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: dropState.feedback === null
                text: dropState.added.length > 1 ? `${dropState.added.length} ${Translation.tr("files")}` : DropShelf.fileName(dropState.added[0] ?? "")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.7
                elide: Text.ElideMiddle
            }
        }
    }
}
