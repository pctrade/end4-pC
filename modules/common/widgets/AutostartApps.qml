import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import Quickshell.Hyprland

ContentSection {
    id: root
    icon: "app_registration"
    shape: MaterialShape.Shape.Sunny
    title: Translation.tr("Autostart Apps")
    Layout.fillWidth: true

    function addEntry() {
        let list = []
        for (let i = 0; i < Config.options.hyprland.autostartApps.apps.length; i++) {
            let o = Config.options.hyprland.autostartApps.apps[i]
            list.push({ cmd: o.cmd, workspace: o.workspace, delay: o.delay })
        }
        list.push({ cmd: "", workspace: 1, delay: 0 })
        Config.options.hyprland.autostartApps.apps = list
    }

    function removeEntry(index) {
        let list = []
        for (let i = 0; i < Config.options.hyprland.autostartApps.apps.length; i++) {
            if (i === index) continue
            let o = Config.options.hyprland.autostartApps.apps[i]
            list.push({ cmd: o.cmd, workspace: o.workspace, delay: o.delay })
        }
        Config.options.hyprland.autostartApps.apps = list
    }

    function updateEntry(index, key, value) {
        let list = []
        for (let i = 0; i < Config.options.hyprland.autostartApps.apps.length; i++) {
            let o = Config.options.hyprland.autostartApps.apps[i]
            list.push({ cmd: o.cmd, workspace: o.workspace, delay: o.delay })
        }
        list[index][key] = value
        Config.options.hyprland.autostartApps.apps = list
    }

    RowLayout {
        Layout.fillWidth: true

        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Enable")
            checked: Config.options.hyprland.autostartApps.enable
            onCheckedChanged: {
                Config.options.hyprland.autostartApps.enable = checked
            }
        }

        Item { Layout.fillWidth: true }

        RippleButton {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            visible: Config.options.hyprland.autostartApps.enable
            buttonRadius: implicitWidth / 2
            colBackground: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
            colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.6)
            colRipple: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.5)
            onClicked: {
                Quickshell.execDetached(["python3", `${Directories.scriptPath}/hyprland/autostart.py`])
            }
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                text: "motion_play"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colPrimary
            }
        }
    }

    Item {
        Layout.fillWidth: true
        height: 24
        visible: Config.options.hyprland.autostartApps.apps.length > 0 && Config.options.hyprland.autostartApps.enable

        Row {
            id: headerRightGroup
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            StyledText {
                width: 118
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Workspace")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
            }

            StyledText {
                width: 118
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Delay")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
            }

            Item { width: 36; height: 1 }
        }

        StyledText {
            anchors.left: parent.left
            anchors.right: headerRightGroup.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: Translation.tr("App or Command")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
        }
    }

    Repeater {
        id: appsRepeater
        model: Config.options.hyprland.autostartApps.apps

        delegate: Item {
            id: entryRow
            required property var modelData
            required property int index
            Layout.fillWidth: true
            implicitHeight: cmdArea.implicitHeight
            visible: Config.options.hyprland.autostartApps.enable

            Row {
                id: rightGroup
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                ConfigSpinBox {
                    width: 118
                    value: entryRow.modelData.workspace ?? 1
                    from: 1
                    to: 20

                    property bool ready: false
                    Component.onCompleted: ready = true

                    onValueChanged: {
                        if (!ready) return
                        root.updateEntry(entryRow.index, "workspace", value)
                    }
                }

                ConfigSpinBox {
                    width: 118
                    value: entryRow.modelData.delay ?? 0
                    from: 0
                    to: 60
                    stepSize: 1

                    property bool ready: false
                    Component.onCompleted: ready = true

                    onValueChanged: {
                        if (!ready) return
                        root.updateEntry(entryRow.index, "delay", value)
                    }
                }

                RippleButton {
                    width: 36
                    height: 36
                    buttonRadius: width / 2
                    colBackground: ColorUtils.transparentize(Appearance.colors.colError, 0.85)
                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colError, 0.6)
                    colRipple: ColorUtils.transparentize(Appearance.colors.colError, 0.5)
                    onClicked: root.removeEntry(entryRow.index)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "delete"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colError
                    }
                }
            }

            MaterialTextArea {
                id: cmdArea
                anchors.left: parent.left
                anchors.right: rightGroup.left
                anchors.rightMargin: 6
                placeholderText: Translation.tr("App (e.g. firefox)")
                text: entryRow.modelData.cmd ?? ""
                wrapMode: TextEdit.Wrap
                font.pixelSize: Appearance.font.pixelSize.normal

                property bool ready: false
                Component.onCompleted: ready = true

                onTextChanged: {
                    if (!ready) return
                    debounceTimer.restart()
                }

                Timer {
                    id: debounceTimer
                    interval: 3000
                    repeat: false
                    onTriggered: {
                        root.updateEntry(entryRow.index, "cmd", cmdArea.text)
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4

        Item { Layout.fillWidth: true }

        ToolbarPairedFab {
            visible: Config.options.hyprland.autostartApps.enable
            iconText: "add"
            onClicked: root.addEntry()
        }
    }
}