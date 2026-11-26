import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    property string title: ""
    property string icon: "casino"
    property var tileShape: MaterialShape.Shape.Sunny

    signal randomRequested()
    signal foldersRequested()

    tint: Appearance.colors.colPrimaryContainer

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                shape: root.tileShape
                text: root.icon
                iconSize: 24
                fill: 1
                padding: 10
                color: Appearance.colors.colPrimary
                colSymbol: Appearance.colors.colOnPrimary
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnPrimaryContainer
                elide: Text.ElideRight
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { icon: "shuffle", label: Translation.tr("Random"), primary: true },
                    { icon: "folder_open", label: Translation.tr("More folders"), primary: false }
                ]

                delegate: RippleButton {
                    id: tool
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 40
                    buttonRadius: 20
                    colBackground: modelData.primary ? Appearance.colors.colPrimary : Qt.rgba(1, 1, 1, 0.14)
                    colBackgroundHover: modelData.primary ? Appearance.colors.colPrimaryHover : Qt.rgba(1, 1, 1, 0.26)
                    colRipple: Qt.rgba(1, 1, 1, 0.3)
                    downAction: () => {
                        const random = modelData.primary;
                        Qt.callLater(() => {
                            if (random) root.randomRequested();
                            else root.foldersRequested();
                        });
                    }

                    contentItem: RowLayout {
                        spacing: 6

                        Item { Layout.fillWidth: true }
                        MaterialSymbol {
                            text: tool.modelData.icon
                            iconSize: 18
                            color: tool.modelData.primary ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            text: tool.modelData.label
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: tool.modelData.primary ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
