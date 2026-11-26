import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs
import qs.services
import qs.modules.common

Item {
    id: root

    property var screen: null
    property bool transitionDone: true
    property var entrants: []

    function evaluateEntrance() {
        if (root.entrants.length === 0) return
        if (root.entrants.some(tile => !tile.imageSettled)) return
        if (!root.transitionDone) return
        const group = root.entrants
        root.entrants = []
        for (const tile of group) tile.reveal()
    }

    readonly property real backdropOpacity: (root.transitionDone && root.entrants.length === 0) ? 1 : 0

    onTransitionDoneChanged: root.evaluateEntrance()

    readonly property var result: Collage.layout(root.width, root.height, Collage.barInsets(root.screen?.name ?? ""))
    property alias backdropSource: backdropImage.source

    Item {
        id: backdropBox
        width: 256
        height: Math.max(1, 256 * root.height / Math.max(1, root.width))
        scale: root.width / 256
        transformOrigin: Item.TopLeft
        opacity: root.backdropOpacity
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        Image {
            id: backdropImage
            anchors.fill: parent
            source: Collage.primaryImage
            sourceSize.width: 256
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        FastBlur {
            anchors.fill: parent
            source: backdropImage
            radius: 24
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.22)
        opacity: root.backdropOpacity
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
    }

    Repeater {
        model: ScriptModel {
            values: root.result.leaves
            objectProp: "id"
        }

        delegate: ClippingRectangle {
            id: tile
            required property var modelData
            required property int index

            property real animScale: Collage.entranceActive ? 0.25 : 1
            property real animOpacity: Collage.entranceActive ? 0 : 1
            property real offsetX: 0
            property real offsetY: 0
            property bool entering: false
            property bool imageSettled: false

            readonly property int decodeStep: 512
            property int decodeWidth: 0

            function requiredDecodeWidth() {
                const needed = Math.max(tile.modelData.w, tile.modelData.h * 2.4)
                return Math.ceil(needed / tile.decodeStep) * tile.decodeStep
            }

            function growDecode() {
                if (Collage.dragging) return
                const needed = tile.requiredDecodeWidth()
                if (needed > tile.decodeWidth) tile.decodeWidth = needed
            }

            function playEntrance(reason) {
                enterAnim.stop()
                const angle = Math.random() * Math.PI * 2
                const magnitude = 140 + Math.random() * 90
                tile.animScale = 0.25
                tile.animOpacity = 0
                tile.offsetX = Math.cos(angle) * magnitude
                tile.offsetY = Math.sin(angle) * magnitude
                tile.entering = true
                tile.imageSettled = false
                if (!root.entrants.includes(tile)) root.entrants = root.entrants.concat([tile])
                settleTimer.restart()
                giveUpTimer.restart()
            }

            function reveal() {
                if (!tile.entering) return
                tile.entering = false
                settleTimer.stop()
                giveUpTimer.stop()
                enterAnim.restart()
            }

            function checkImage() {
                if (!tile.entering) return
                if (tileImage.status === Image.Ready || tileImage.status === Image.Error) {
                    tile.imageSettled = true
                    root.evaluateEntrance()
                }
            }

            onModelDataChanged: tile.growDecode()
            Component.onCompleted: {
                tile.growDecode()
                if (Collage.entranceActive) tile.playEntrance("created")
            }

            transformOrigin: Item.Center
            scale: tile.animScale
            opacity: tile.animOpacity
            transform: Translate {
                x: tile.offsetX
                y: tile.offsetY
            }

            Timer {
                id: settleTimer
                interval: 60
                onTriggered: tile.checkImage()
            }

            Timer {
                id: giveUpTimer
                interval: 5000
                onTriggered: {
                    tile.imageSettled = true
                    root.evaluateEntrance()
                }
            }

            Connections {
                target: Collage
                function onEntranceSerialChanged() { tile.playEntrance("preset applied") }
            }

            SequentialAnimation {
                id: enterAnim
                ParallelAnimation {
                    SpringAnimation { target: tile; property: "animScale"; to: 1; spring: 2.6; damping: 0.32 }
                    SpringAnimation { target: tile; property: "offsetX"; to: 0; spring: 2.6; damping: 0.32 }
                    SpringAnimation { target: tile; property: "offsetY"; to: 0; spring: 2.6; damping: 0.32 }
                    NumberAnimation { target: tile; property: "animOpacity"; to: 1; duration: 220; easing.type: Easing.OutQuad }
                }
            }

            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h
            radius: Collage.radius
            color: Qt.rgba(0, 0, 0, 0.3)

            Behavior on x { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on width { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on height { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Image {
                id: tileImage
                anchors.fill: parent
                onStatusChanged: tile.checkImage()
                source: tile.decodeWidth > 0 ? tile.modelData.src : ""
                sourceSize.width: tile.decodeWidth
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }
        }
    }
}
