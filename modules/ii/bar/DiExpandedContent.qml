import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: content
    required property Item di
    required property string contentId
    property real maxHeight: 100000
    readonly property real padding: 14
    property string shownId: ""

    // The loaded view (the overlay looks for its shared elements)
    readonly property Item viewItem: loader.item
    readonly property real naturalHeight: (loader.item?.implicitHeight ?? 60) + content.padding * 2
    readonly property bool scrollable: content.naturalHeight > content.maxHeight + 1

    implicitWidth: (loader.item?.implicitWidth ?? 280) + content.padding * 2
    implicitHeight: Math.min(content.naturalHeight, content.maxHeight)

    Component.onCompleted: content.shownId = content.contentId
    onContentIdChanged: {
        if (content.shownId === "") content.shownId = content.contentId
        else swapAnim.restart()
    }

    SequentialAnimation {
        id: swapAnim
        NumberAnimation { target: loader; property: "opacity"; to: 0; duration: 110; easing.type: Easing.InCubic }
        ScriptAction {
            script: {
                content.shownId = content.contentId
                flick.contentY = 0
            }
        }
        NumberAnimation { target: loader; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
    }

    function componentFor(id) {
        switch (id) {
            case "notification":  return notificationView
            case "media":         return mediaView
            case "f1":
            case "f1Event":
            case "f1Flag":        return f1View
            case "timer":         return timerView
            case "osd":
            case "audioOutput":   return audioView
            case "bluetooth":     return bluetoothView
            case "activity":
            case "agents":        return activitiesView
            case "system":        return systemView
            case "systemLoad":    return loadView
            case "battery":       return batteryView
            case "screenshot":    return screenshotView
            case "clipboard":     return clipboardView
            case "privacy":       return privacyView
            case "watchRating":   return watchView
            case "weather":       return weatherView
            case "recording":     return recordingView
            case "shelf":
            case "shelfDrop":     return shelfView
            case "overview":      return overviewView
            case "history":       return historyView
            case "calendar":      return calendarView
            case "songRec":
            case "songRecResult": return songRecView
            case "download":
            case "zerotier":      return networkView
            case "hardware":      return hardwareView
            default:              return idleView
        }
    }

    // Content taller than the island's height limit scrolls inside it instead of stretching the island
    Flickable {
        id: flick
        anchors.fill: parent
        clip: content.scrollable
        interactive: content.scrollable
        contentWidth: width
        contentHeight: content.naturalHeight
        boundsBehavior: Flickable.StopAtBounds

        // A view taller than the overlay scrolls on its own and keeps every wheel event, even at the ends, so
        // scrolling to the bottom doesn't carry on into the next view
        MouseArea {
            parent: flick
            anchors.fill: parent
            z: 10
            enabled: content.scrollable
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                const step = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 120 * 48
                flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - step))
                wheel.accepted = true
            }
        }

        Loader {
            id: loader
            x: content.padding
            y: content.padding
            width: flick.width - content.padding * 2
            height: loader.item?.implicitHeight ?? 60
            sourceComponent: content.shownId === "" ? null : content.componentFor(content.shownId)
        }
    }

    Rectangle {
        visible: content.scrollable
        anchors {
            right: parent.right
            rightMargin: 4
        }
        y: content.padding + (content.height - content.padding * 2 - height) * (flick.contentY / Math.max(1, flick.contentHeight - flick.height))
        width: 3
        height: Math.max(24, (content.height - content.padding * 2) * flick.height / Math.max(1, flick.contentHeight))
        radius: 1.5
        color: Appearance.colors.colOnLayer0
        opacity: flick.moving ? 0.5 : 0.2

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }

    Component { id: notificationView; DiXNotification { di: content.di } }
    Component { id: mediaView; DiXMedia { di: content.di } }
    Component { id: f1View; DiXF1 { di: content.di } }
    Component { id: timerView; DiXTimer { di: content.di } }
    Component { id: audioView; DiXAudio { di: content.di } }
    Component { id: bluetoothView; DiXBluetooth { di: content.di } }
    Component { id: activitiesView; DiXActivities { di: content.di } }
    Component { id: systemView; DiXSystem { di: content.di } }
    Component { id: loadView; DiXLoad { di: content.di } }
    Component { id: batteryView; DiXBattery { di: content.di } }
    Component { id: screenshotView; DiXScreenshot { di: content.di } }
    Component { id: clipboardView; DiXClipboard { di: content.di } }
    Component { id: privacyView; DiXPrivacy { di: content.di } }
    Component { id: watchView; DiXWatch { di: content.di } }
    Component { id: weatherView; DiXWeather { di: content.di } }
    Component { id: recordingView; DiXRecording { di: content.di } }
    Component { id: shelfView; DiXShelf { di: content.di } }
    Component { id: overviewView; DiXOverview { di: content.di } }
    Component { id: songRecView; DiXSongRec { di: content.di } }
    Component { id: idleView; DiXIdle { di: content.di } }
    Component { id: networkView; DiXNetwork { di: content.di } }
    Component { id: historyView; DiXHistory { di: content.di } }
    Component { id: calendarView; DiXCalendar { di: content.di } }
    Component { id: hardwareView; DiXHardware { di: content.di } }
}
