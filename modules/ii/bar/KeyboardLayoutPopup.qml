import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    // [{ code, name, active }]
    property var layouts: []
    readonly property int activeIndex: layouts.findIndex(layout => layout.active)
    readonly property var activeLayout: layouts[activeIndex] ?? null
    readonly property var otherLayouts: layouts.filter(layout => !layout.active)

    ColumnLayout {
        implicitWidth: 280
        spacing: 8

        // Active layout, the same card as a connected Bluetooth device
        Rectangle {
            implicitWidth: 280
            implicitHeight: activeContent.implicitHeight + 24
            radius: Appearance.rounding.normal
            color: Appearance.colors.colSurfaceContainerLow

            ColumnLayout {
                id: activeContent
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: 16
                }
                width: parent.width - 32
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: root.activeLayout?.name || Translation.tr("Keyboard layout")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.layouts.length > 1
                        ? `${Translation.tr("Keyboard layout")} · ${root.activeIndex + 1}/${root.layouts.length}`
                        : Translation.tr("Keyboard layout")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                    opacity: 0.7
                    elide: Text.ElideRight
                }

                RowLayout {
                    implicitWidth: parent.width
                    spacing: 8

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        shape: MaterialShape.Shape.ClamShell
                        text: "keyboard"
                        iconSize: Appearance.font.pixelSize.large
                        implicitSize: Appearance.font.pixelSize.hugeass * 2
                        color: Appearance.colors.colPrimaryContainer
                        colSymbol: Appearance.colors.colPrimary
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: (root.activeLayout?.code ?? "").toUpperCase()
                        font.pixelSize: Appearance.font.pixelSize.hugeass * 2
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colPrimary
                    }
                }
            }
        }

        // The layouts a click or the wheel moves to
        Rectangle {
            visible: root.otherLayouts.length > 0
            implicitWidth: 280
            implicitHeight: visible ? othersContent.implicitHeight + 20 : 0
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1Base

            ColumnLayout {
                id: othersContent
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 6

                Repeater {
                    model: root.otherLayouts

                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10

                        StyledText {
                            visible: modelData.code !== ""
                            Layout.minimumWidth: 28
                            text: modelData.code.toUpperCase()
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colPrimary
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.name
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        StyledText {
            visible: root.layouts.length > 1
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("Click or scroll to switch")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnSurfaceVariant
            opacity: 0.6
        }
    }
}
