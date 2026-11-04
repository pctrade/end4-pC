pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Toolbar {
    id: root

    property var action
    property var selectionMode
    signal dismiss()

    readonly property bool recording: root.action === RegionSelection.SnipAction.Record || root.action === RegionSelection.SnipAction.RecordWithSound

    readonly property var captureModes: [
        {"icon": "screenshot_region", "name": Translation.tr("Screenshot")},
        {"icon": "videocam", "name": Translation.tr("Record")}
    ]
    readonly property var targetModes: root.recording ? [
        {"icon": "activity_zone", "name": Translation.tr("Region"), "mode": RegionSelection.SelectionMode.RectCorners},
        {"icon": "desktop_windows", "name": Translation.tr("Screen"), "mode": RegionSelection.SelectionMode.ScreenTarget}
    ] : [
        {"icon": "activity_zone", "name": Translation.tr("Region"), "mode": RegionSelection.SelectionMode.RectCorners},
        {"icon": "desktop_windows", "name": Translation.tr("Screen"), "mode": RegionSelection.SelectionMode.ScreenTarget},
        {"icon": "gesture", "name": Translation.tr("Free"), "mode": RegionSelection.SelectionMode.Circle}
    ]
    readonly property var screenshotActions: [
        {"icon": "content_copy", "tip": Translation.tr("Copy to clipboard (right click to annotate)"), "action": RegionSelection.SnipAction.Copy},
        {"icon": "edit", "tip": Translation.tr("Annotate"), "action": RegionSelection.SnipAction.Edit},
        {"icon": "image_search", "tip": Translation.tr("Search with Google Lens"), "action": RegionSelection.SnipAction.Search},
        {"icon": "document_scanner", "tip": Translation.tr("Recognize text"), "action": RegionSelection.SnipAction.CharRecognition},
        {"icon": "qr_code_scanner", "tip": Translation.tr("Scan QR code"), "action": RegionSelection.SnipAction.QrCode}
    ]

    function targetIndex() {
        const index = root.targetModes.findIndex(entry => entry.mode === root.selectionMode)
        return index >= 0 ? index : 0
    }

    ToolbarTabBar {
        id: captureTabs
        tabButtonList: root.captureModes
        currentIndex: root.recording ? 1 : 0
        onCurrentIndexChanged: {
            const wantsRecording = currentIndex === 1
            if (wantsRecording === root.recording) return
            root.action = wantsRecording ? RegionSelection.SnipAction.Record : RegionSelection.SnipAction.Copy
            if (wantsRecording && root.selectionMode === RegionSelection.SelectionMode.Circle)
                root.selectionMode = RegionSelection.SelectionMode.RectCorners
        }
    }

    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 1
        implicitHeight: 24
        color: Appearance.colors.colOutlineVariant
    }

    ToolbarTabBar {
        id: targetTabs
        tabButtonList: root.targetModes
        currentIndex: root.targetIndex()
        onCurrentIndexChanged: {
            const entry = root.targetModes[currentIndex]
            if (entry && root.selectionMode !== entry.mode)
                root.selectionMode = entry.mode
        }
    }

    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 1
        implicitHeight: 24
        color: Appearance.colors.colOutlineVariant
    }

    Repeater {
        model: root.recording ? [] : root.screenshotActions
        delegate: IconToolbarButton {
            required property var modelData
            text: modelData.icon
            toggled: root.action === modelData.action
            onClicked: root.action = modelData.action
            StyledToolTip {
                text: modelData.tip
            }
        }
    }

    IconToolbarButton {
        visible: root.recording
        text: Config.options.screenRecord.systemAudio ? "volume_up" : "volume_off"
        toggled: Config.options.screenRecord.systemAudio
        onClicked: Config.options.screenRecord.systemAudio = !Config.options.screenRecord.systemAudio
        StyledToolTip {
            text: Config.options.screenRecord.systemAudio ? Translation.tr("System audio: on") : Translation.tr("System audio: off")
        }
    }

    IconToolbarButton {
        visible: root.recording
        text: Config.options.screenRecord.microphone ? "mic" : "mic_off"
        toggled: Config.options.screenRecord.microphone
        onClicked: Config.options.screenRecord.microphone = !Config.options.screenRecord.microphone
        StyledToolTip {
            text: Config.options.screenRecord.microphone ? Translation.tr("Microphone: on") : Translation.tr("Microphone: off")
        }
    }
}
