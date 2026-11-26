import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 8

    readonly property var autostart: Config.options.hyprland.autostartApps
    property bool writing: false

    ListModel {
        id: entries
    }

    function snapshot() {
        const list = []
        for (let i = 0; i < entries.count; i++) {
            const entry = entries.get(i)
            list.push({ cmd: entry.cmd, workspace: entry.workspace, delay: entry.delay })
        }
        return list
    }

    function configSnapshot() {
        return (root.autostart.apps ?? []).map(app => ({ cmd: app.cmd ?? "", workspace: app.workspace ?? 1, delay: app.delay ?? 0 }))
    }

    function loadFromConfig() {
        entries.clear()
        for (const app of root.configSnapshot()) entries.append(app)
    }

    function commit() {
        root.writing = true
        root.autostart.apps = root.snapshot()
        root.writing = false
    }

    function setField(index, key, value) {
        if (index < 0 || index >= entries.count || entries.get(index)[key] === value) return
        entries.setProperty(index, key, value)
        root.commit()
    }

    function addEntry() {
        entries.append({ cmd: "", workspace: 1, delay: 0 })
        root.commit()
    }

    function removeEntry(index) {
        entries.remove(index)
        root.commit()
    }

    Component.onCompleted: root.loadFromConfig()

    Connections {
        target: root.autostart
        function onAppsChanged() {
            if (root.writing) return
            if (JSON.stringify(root.snapshot()) !== JSON.stringify(root.configSnapshot())) root.loadFromConfig()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        GroupedList {
            id: enableGroup
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            ConfigSwitch {
                buttonIcon: "check"
                text: Translation.tr("Enable")
                checked: root.autostart.enable
                onCheckedChanged: root.autostart.enable = checked
            }
        }

        RippleButton {
            Layout.alignment: Qt.AlignTop
            Layout.preferredHeight: enableGroup.implicitHeight
            Layout.preferredWidth: 56
            visible: root.autostart.enable
            buttonRadius: Appearance.rounding.normal
            colBackground: Appearance.colors.colLayer1
            colBackgroundHover: Appearance.colors.colLayer1Hover
            colRipple: Appearance.colors.colLayer1Active
            onClicked: Quickshell.execDetached(["python3", `${Directories.scriptPath}/hyprland/autostart.py`, "--force"])
            contentItem: Item {
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "play_arrow"
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colPrimary
                }
            }
            StyledToolTip {
                text: Translation.tr("Run all now")
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        visible: root.autostart.enable && entries.count === 0
        wrapMode: Text.Wrap
        color: Appearance.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.small
        text: Translation.tr("No apps yet. Each app opens on its workspace when the shell starts.")
    }

    Repeater {
        model: entries

        delegate: ColumnLayout {
            id: entryItem
            Layout.fillWidth: true
            spacing: 4
            visible: root.autostart.enable

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 4

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("App %1").arg(index + 1)
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                }

                RippleButton {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    buttonRadius: width / 2
                    colBackground: ColorUtils.transparentize(Appearance.colors.colError, 0.85)
                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colError, 0.6)
                    colRipple: ColorUtils.transparentize(Appearance.colors.colError, 0.5)
                    onClicked: root.removeEntry(index)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "delete"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colError
                    }
                    StyledToolTip {
                        text: Translation.tr("Remove")
                    }
                }
            }

            GroupedList {
                Layout.fillWidth: true

                ConfigTextArea {
                    id: commandField
                    Layout.fillWidth: true
                    buttonIcon: "terminal"
                    text: Translation.tr("Command")
                    placeholderText: Translation.tr("e.g. firefox")
                    fieldWidth: 320
                    value: model.cmd

                    property bool ready: false
                    Component.onCompleted: ready = true

                    onValueChanged: if (ready) commandDebounce.restart()
                    onConfirmClicked: {
                        commandDebounce.stop()
                        root.setField(index, "cmd", value)
                    }
                    textArea.onActiveFocusChanged: {
                        if (!textArea.activeFocus && ready) {
                            commandDebounce.stop()
                            root.setField(index, "cmd", value)
                        }
                    }

                    Timer {
                        id: commandDebounce
                        interval: 600
                        onTriggered: root.setField(index, "cmd", commandField.value)
                    }
                }

                ConfigSpinBox {
                    icon: "workspaces"
                    text: Translation.tr("Workspace")
                    value: model.workspace
                    from: 1
                    to: 20

                    property bool ready: false
                    Component.onCompleted: ready = true
                    onValueChanged: if (ready) root.setField(index, "workspace", value)
                }

                ConfigSpinBox {
                    icon: "timer"
                    text: Translation.tr("Delay after launch (seconds)")
                    value: model.delay
                    from: 0
                    to: 60
                    stepSize: 1

                    property bool ready: false
                    Component.onCompleted: ready = true
                    onValueChanged: if (ready) root.setField(index, "delay", value)
                }
            }
        }
    }

    RippleButton {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        visible: root.autostart.enable
        buttonRadius: Appearance.rounding.normal
        colBackground: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)
        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)
        colRipple: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.5)
        onClicked: root.addEntry()
        contentItem: Item {
            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                MaterialSymbol {
                    text: "add"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    text: Translation.tr("Add app")
                    color: Appearance.colors.colPrimary
                    font.weight: Font.Medium
                }
            }
        }
    }
}
