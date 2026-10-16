import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    readonly property var styleOptions: [
        { value: "default", name: Translation.tr("Default"), detail: Translation.tr("Full overlay panel"), icon: "settings_panorama", shape: MaterialShape.Shape.Cookie9Sided },
        { value: "minimal", name: Translation.tr("Minimal"), detail: Translation.tr("Compact overlay panel"), icon: "settings_heart", shape: MaterialShape.Shape.Clover4Leaf },
        { value: "dashboard", name: Translation.tr("Dashboard"), detail: Translation.tr("Floating window with cards"), icon: "dashboard", shape: MaterialShape.Shape.SoftBurst }
    ]

    tint: Appearance.colors.colLayer1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                shape: MaterialShape.Shape.Gem
                text: "settings"
                iconSize: 26
                fill: 1
                padding: 11
                color: Appearance.colors.colPrimary
                colSymbol: Appearance.colors.colOnPrimary
            }

            ColumnLayout {
                spacing: 0

                StyledText {
                    text: Translation.tr("Settings Panel")
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: Translation.tr("Choose how settings open")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            Item { Layout.fillWidth: true }

            ColumnLayout {
                visible: Config.options.settings.style === "dashboard"
                spacing: 2

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: Translation.tr("Animation speed")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                Row {
                    Layout.alignment: Qt.AlignRight
                    spacing: 4

                    Repeater {
                        model: [
                            { value: 1, label: "1x" },
                            { value: 1.5, label: "1.5x" },
                            { value: 2, label: "2x" },
                            { value: 3, label: "3x" }
                        ]

                        delegate: RippleButton {
                            required property var modelData
                            readonly property bool picked: (Config.options.settings.animationSpeed ?? 1) === modelData.value

                            implicitWidth: 44
                            implicitHeight: 28
                            buttonRadius: 14
                            colBackground: picked ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer
                            colBackgroundHover: picked ? Appearance.colors.colPrimaryHover : Appearance.colors.colSecondaryContainerHover
                            colRipple: picked ? Appearance.colors.colPrimaryActive : Appearance.colors.colSecondaryContainerActive
                            downAction: () => {
                                const value = modelData.value;
                                Qt.callLater(() => { Config.options.settings.animationSpeed = value; });
                            }
                            contentItem: StyledText {
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: picked ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Repeater {
                model: styleOptions

                delegate: RippleButton {
                    id: option
                    required property var modelData

                    readonly property bool selected: Config.options.settings.style === modelData.value

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    buttonRadius: Appearance.rounding.large
                    colBackground: selected ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer
                    colBackgroundHover: selected ? Appearance.colors.colPrimaryHover : Appearance.colors.colSecondaryContainerHover
                    colRipple: selected ? Appearance.colors.colPrimaryActive : Appearance.colors.colSecondaryContainerActive
                    downAction: () => {
                        const value = modelData.value;
                        Qt.callLater(() => { Config.options.settings.style = value; });
                    }

                    contentItem: ColumnLayout {
                        spacing: 8

                        Item { Layout.fillHeight: true }

                        MaterialShapeWrappedMaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            shape: option.modelData.shape
                            text: option.modelData.icon
                            iconSize: 34
                            fill: 1
                            padding: 16
                            color: option.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary
                            colSymbol: option.selected ? Appearance.colors.colPrimary : Appearance.colors.colOnPrimary
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: option.modelData.name
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.DemiBold
                            color: option.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                        }

                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: option.modelData.detail
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: option.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                            opacity: 0.8
                        }

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.bottomMargin: 8
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 13
                            color: option.selected ? Appearance.colors.colOnPrimary : "transparent"
                            border.width: option.selected ? 0 : 2
                            border.color: Appearance.colors.colOnSecondaryContainer

                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: option.selected
                                text: "check"
                                iconSize: 18
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }
                }
            }
        }
    }
}
