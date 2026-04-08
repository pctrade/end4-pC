pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Qt.labs.folderlistmodel

WindowDialog {
    id: root
    backgroundHeight: 400

    FolderListModel {
        id: folderModel
        folder: "file://" + Quickshell.shellPath("assets/icons")
        nameFilters: ["*.svg"]
        showDirs: false
    }

    WindowDialogTitle {
        text: "Select icon"
    }

    WindowDialogSeparator {
        Layout.topMargin: -22
        Layout.leftMargin: 0
        Layout.rightMargin: 0
    }

    GridView {
        id: grid
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        cellWidth: 70
        cellHeight: 70
        model: folderModel

        delegate: Item {
            id: delegateItem
            required property var modelData
            width: 70
            height: 70

            CustomIcon {
                anchors.centerIn: parent
                width: 36
                height: 36
                source: delegateItem.modelData.fileName
                colorize: Config.options.custom.colorizeIcon
                color: Appearance.colors.colOnLayer0
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Config.setNestedValue("custom.distroIcon", delegateItem.modelData.fileName.replace(".svg", ""))
                    root.dismiss()
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: Appearance.colors.colLayer1
                    opacity: mouseArea.containsMouse ? 0.3 : 0
                }
            }
        }
    }

    WindowDialogButtonRow {
        ConfigSwitch {
            buttonIcon: "palette"
            text: Translation.tr("Colorize")
            checked: Config.options.custom.colorizeIcon
            onCheckedChanged: {
                Config.options.custom.colorizeIcon = checked
            }
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: "Reset"
            onClicked: {
                Config.setNestedValue("custom.distroIcon", "")
                root.dismiss()
            }
        }

        DialogButton {
            buttonText: "Done"
            onClicked: root.dismiss()
        }
    }
}