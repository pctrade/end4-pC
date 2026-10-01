import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Smart Drop: the pill splits into one zone per action that fits the dragged item (services/SmartDrop.qml).
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
        border.width: dropState.hovering ? 1.5 : 0
        border.color: Appearance.colors.colPrimary
    }

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
                NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
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
                                NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
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

                    opacity: 0
                    NumberAnimation on opacity {
                        running: dropState.hovering
                        from: 0
                        to: 1
                        duration: IslandMotion.short
                    }
                }
            }
        }
    }

    RowLayout {
        visible: !dropState.hovering
        anchors {
            fill: parent
            leftMargin: 8
            rightMargin: 14
        }
        spacing: 8

        Rectangle {
            id: doneMark
            implicitWidth: 24
            implicitHeight: 24
            radius: 12
            color: ColorUtils.transparentize(Appearance.m3colors.m3success, 0.82)
            opacity: 0
            scale: 0.85

            MaterialSymbol {
                anchors.centerIn: parent
                text: dropState.feedback?.icon ?? "check"
                iconSize: 14
                color: Appearance.m3colors.m3success
            }

            ParallelAnimation {
                running: !dropState.hovering
                NumberAnimation { target: doneMark; property: "opacity"; from: 0; to: 1; duration: IslandMotion.short; easing.type: Easing.OutCubic }
                NumberAnimation { target: doneMark; property: "scale"; from: 0.85; to: 1; duration: IslandMotion.medium; easing.type: Easing.OutCubic }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -3

            StyledText {
                Layout.fillWidth: true
                text: dropState.feedback?.label ?? Translation.tr("Kept in the drawer")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
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
