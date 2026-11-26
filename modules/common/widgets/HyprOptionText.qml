import QtQuick
import qs.services

ConfigTextArea {
    id: root

    required property string optionKey
    property string fallback: ""
    readonly property string current: String(HyprlandOptions.get(root.optionKey, root.fallback))

    onCurrentChanged: if (!root.textArea.activeFocus && root.value !== root.current) root.value = root.current
    Component.onCompleted: root.value = root.current

    function commit() {
        commitTimer.stop()
        if (root.value !== root.current) HyprlandOptions.apply(root.optionKey, root.value)
    }

    onValueChanged: if (root.textArea.activeFocus) commitTimer.restart()
    onConfirmClicked: root.commit()
    textArea.onActiveFocusChanged: if (!root.textArea.activeFocus) root.commit()

    Timer {
        id: commitTimer
        interval: 800
        onTriggered: root.commit()
    }
}
