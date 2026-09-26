import QtQuick
import qs.services
import qs.modules.common

// Charging case that pops open when the earbuds connect and snaps shut when they leave.
// The drawing keeps its own shading, recolored to the theme's primary hue (see IslandEvents.themedSvg).
Item {
    id: art
    property bool open: false
    property bool busy: false
    property bool animateEntrance: true
    implicitWidth: 28
    implicitHeight: 28

    property bool initialOpen: false
    property bool ready: false
    readonly property bool shownOpen: art.ready ? art.open : art.initialOpen

    Component.onCompleted: {
        art.initialOpen = art.animateEntrance ? (!art.open && !art.busy) : art.open
        closedImg.opacity = art.initialOpen ? 0 : 1
        openImg.opacity = art.initialOpen ? 1 : 0
        if (art.animateEntrance) readyTimer.start()
        else art.ready = true
    }

    Timer {
        id: readyTimer
        interval: 320
        onTriggered: art.ready = true
    }

    onShownOpenChanged: {
        if (!art.ready) return
        openAnim.stop()
        closeAnim.stop()
        if (art.shownOpen) openAnim.restart()
        else closeAnim.restart()
    }

    Image {
        id: closedImg
        width: art.width
        height: art.height
        source: IslandEvents.caseClosedArt
        sourceSize.width: art.width * 2
        sourceSize.height: art.height * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    Image {
        id: openImg
        width: art.width
        height: art.height
        source: IslandEvents.caseOpenArt
        sourceSize.width: art.width * 2
        sourceSize.height: art.height * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    SequentialAnimation {
        id: openAnim
        ParallelAnimation {
            NumberAnimation { target: closedImg; property: "scale"; to: 1.1; duration: 130; easing.type: Easing.OutQuad }
            NumberAnimation { target: closedImg; property: "y"; to: -1.5; duration: 130; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: closedImg; property: "opacity"; to: 0; duration: 110 }
            NumberAnimation { target: openImg; property: "opacity"; to: 1; duration: 140 }
            NumberAnimation { target: openImg; property: "scale"; from: 0.84; to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
            NumberAnimation { target: openImg; property: "y"; from: -2; to: 0; duration: 520; easing.type: Easing.OutBack }
        }
        ScriptAction {
            script: {
                closedImg.scale = 1
                closedImg.y = 0
            }
        }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: openImg; property: "scale"; to: 0.9; duration: 140; easing.type: Easing.InQuad }
            NumberAnimation { target: openImg; property: "opacity"; to: 0; duration: 140 }
            NumberAnimation { target: closedImg; property: "opacity"; to: 1; duration: 120 }
            NumberAnimation { target: closedImg; property: "scale"; from: 1.08; to: 1; duration: 440; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        }
        ScriptAction { script: openImg.scale = 1 }
    }

    SequentialAnimation {
        running: art.busy && !art.shownOpen
        loops: Animation.Infinite
        onRunningChanged: if (!running) closedImg.rotation = 0

        NumberAnimation { target: closedImg; property: "rotation"; to: -8; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: closedImg; property: "rotation"; to: 8; duration: 160; easing.type: Easing.InOutQuad }
        NumberAnimation { target: closedImg; property: "rotation"; to: -5; duration: 140; easing.type: Easing.InOutQuad }
        NumberAnimation { target: closedImg; property: "rotation"; to: 0; duration: 110; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 900 }
    }
}
