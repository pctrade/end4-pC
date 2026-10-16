import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    property string title: ""
    property string icon: "web_asset"
    property var tileShape: MaterialShape.Shape.Cookie9Sided

    tint: Appearance.colors.colSecondaryContainer

    function submit() {
        if (input.text.trim() === "" || Webapps.busy) return;
        Webapps.create(input.text);
        input.text = "";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                shape: root.tileShape
                text: root.icon
                iconSize: 22
                fill: 1
                padding: 9
                color: Appearance.colors.colSecondary
                colSymbol: Appearance.colors.colOnSecondary
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSecondaryContainer
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 70
                    radius: Appearance.rounding.normal
                    color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: input.activeFocus ? 2 : 0
                    border.color: Appearance.colors.colSecondary

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onClicked: input.forceActiveFocus()
                    }

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true

                        TextArea {
                            id: input
                            background: null
                            padding: 0
                            wrapMode: TextEdit.NoWrap
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.family: Appearance.font.family.main
                            color: Appearance.colors.colOnSecondaryContainer
                            selectionColor: Appearance.colors.colSecondary
                            ContextMenu.menu: StyledTextEditMenu { editor: input }
                            placeholderText: Translation.tr("example.com (one per line)")
                            placeholderTextColor: Qt.rgba(Appearance.colors.colOnSecondaryContainer.r, Appearance.colors.colOnSecondaryContainer.g, Appearance.colors.colOnSecondaryContainer.b, 0.5)
                            Keys.onPressed: event => {
                                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                                    root.submit();
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Webapps.error !== ""
                    text: Translation.tr("Could not create: %1").arg(Webapps.error)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSecondaryContainer
                    opacity: 0.8
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    buttonRadius: 22
                    enabled: input.text.trim() !== "" && !Webapps.busy
                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimaryHover
                    colRipple: Appearance.colors.colPrimaryActive
                    downAction: () => root.submit()
                    contentItem: RowLayout {
                        spacing: 8
                        Item { Layout.fillWidth: true }
                        MaterialSymbol {
                            text: "add"
                            iconSize: 20
                            fill: 1
                            color: Appearance.colors.colOnPrimary
                        }
                        StyledText {
                            text: Translation.tr("Create webapp")
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnPrimary
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 1
                color: Appearance.colors.colOnSecondaryContainer
                opacity: 0.12
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1

                StyledText {
                    anchors.centerIn: parent
                    visible: Webapps.items.length === 0
                    text: Translation.tr("No webapps yet")
                    color: Appearance.colors.colOnSecondaryContainer
                    opacity: 0.6
                }

                StyledListView {
                    anchors.fill: parent
                    visible: Webapps.items.length > 0
                    clip: true
                    spacing: 6
                    model: Webapps.items

                    delegate: RowLayout {
                        id: row
                        required property var modelData
                        width: ListView.view.width
                        spacing: 10

                        Image {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            source: row.modelData.icon.startsWith("/") ? "file://" + row.modelData.icon : ""
                            sourceSize: Qt.size(56, 56)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                color: Appearance.colors.colOnSecondaryContainer
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.url
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSecondaryContainer
                                opacity: 0.65
                                elide: Text.ElideRight
                            }
                        }

                        RippleButton {
                            implicitWidth: 36
                            implicitHeight: 36
                            buttonRadius: 18
                            colBackground: "transparent"
                            colBackgroundHover: Qt.rgba(1, 1, 1, 0.12)
                            colRipple: Qt.rgba(1, 1, 1, 0.2)
                            downAction: () => Webapps.open(row.modelData.id)
                            contentItem: MaterialSymbol {
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: "open_in_new"
                                iconSize: 20
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                        }

                        RippleButton {
                            implicitWidth: 36
                            implicitHeight: 36
                            buttonRadius: 18
                            colBackground: "transparent"
                            colBackgroundHover: Qt.rgba(1, 1, 1, 0.12)
                            colRipple: Qt.rgba(1, 1, 1, 0.2)
                            downAction: () => Webapps.remove(row.modelData.id)
                            contentItem: MaterialSymbol {
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: "delete"
                                iconSize: 20
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                        }
                    }
                }
            }
        }
    }
}
