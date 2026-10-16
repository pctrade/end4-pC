import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    property string title: ""
    property string icon: "widgets"
    property var tileShape: MaterialShape.Shape.Flower

    readonly property int starredCount: DesktopWidgets.catalog.filter(w => DesktopWidgets.isStarred(w.key)).length
    readonly property int tileMinWidth: 170
    readonly property int columns: Math.max(2, Math.min(7, Math.floor(grid.width / tileMinWidth)))

    tint: Appearance.colors.colLayer1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                shape: root.tileShape
                text: root.icon
                iconSize: 26
                fill: 1
                padding: 11
                color: Appearance.colors.colTertiary
                colSymbol: Appearance.colors.colOnTertiary
            }

            ColumnLayout {
                spacing: 0

                StyledText {
                    text: root.title
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: Translation.tr("%1 on the desktop · %2 in the menu").arg(DesktopWidgets.enabledCount).arg(root.starredCount)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitHeight: 32
                implicitWidth: hint.implicitWidth + 28
                radius: 16
                color: Appearance.colors.colSecondaryContainer

                RowLayout {
                    id: hint
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: "star"
                        fill: 1
                        iconSize: 16
                        color: Appearance.colors.colTertiary
                    }
                    StyledText {
                        text: Translation.tr("Shown in the desktop menu")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
            }
        }

        GridLayout {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.columns
            rowSpacing: 10
            columnSpacing: 10
            uniformCellWidths: true
            uniformCellHeights: true

            Repeater {
                model: DesktopWidgets.catalog

                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index

                    readonly property bool on: DesktopWidgets.isEnabled(modelData.key)
                    readonly property bool starred: DesktopWidgets.isStarred(modelData.key)

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 96

                    RippleButton {
                        anchors.fill: parent
                        buttonRadius: Appearance.rounding.normal
                        colBackground: tile.on ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                        colBackgroundHover: tile.on ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                        colRipple: tile.on ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                        downAction: () => {
                            const key = tile.modelData.key;
                            const next = !tile.on;
                            Qt.callLater(() => DesktopWidgets.setEnabled(key, next));
                        }

                        contentItem: ColumnLayout {
                            spacing: 0

                            MaterialShapeWrappedMaterialSymbol {
                                Layout.leftMargin: 2
                                shape: tile.on ? MaterialShape.Shape.Sunny : MaterialShape.Shape.Circle
                                text: tile.modelData.icon
                                iconSize: 22
                                fill: tile.on ? 1 : 0
                                padding: 10
                                color: tile.on ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer
                                colSymbol: tile.on ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                            }

                            Item { Layout.fillHeight: true }

                            StyledText {
                                Layout.fillWidth: true
                                text: tile.modelData.name
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: tile.on ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            }
                            StyledText {
                                text: tile.on ? Translation.tr("On desktop") : Translation.tr("Off")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: tile.on ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                                opacity: tile.on ? 0.75 : 1
                            }
                        }
                    }

                    RippleButton {
                        id: starButton
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        implicitWidth: 30
                        implicitHeight: 30
                        buttonRadius: 15
                        colBackground: "transparent"
                        colBackgroundHover: tile.on ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                        colRipple: tile.on ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                        downAction: () => {
                            const key = tile.modelData.key;
                            starPop.restart();
                            Qt.callLater(() => DesktopWidgets.toggleStar(key));
                        }

                        SequentialAnimation {
                            id: starPop
                            NumberAnimation { target: starIcon; property: "scale"; to: 0.6; duration: 90; easing.type: Easing.InQuad }
                            SpringAnimation { target: starIcon; property: "scale"; to: 1; spring: 4; damping: 0.22 }
                        }

                        contentItem: MaterialSymbol {
                            id: starIcon
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: "star"
                            fill: tile.starred ? 1 : 0
                            iconSize: 20
                            color: tile.starred ? Appearance.colors.colTertiary : (tile.on ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext)
                            opacity: tile.starred ? 1 : 0.55
                        }
                    }
                }
            }
        }
    }
}
