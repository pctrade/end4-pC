pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property color textColor: "white"
    property color activeColor: "white"
    property color dimColor: Qt.rgba(1, 1, 1, 0.35)
    property color indicatorColor: Appearance.colors.colPrimaryContainer
    property color indicatorShapeColor: Appearance.colors.colOnPrimaryContainer
    property int textAlignment: Text.AlignLeft

    implicitWidth: 200
    implicitHeight: 200

    property bool registered: false
    function syncViewer() {
        if (root.visible === root.registered) return
        root.registered = root.visible
        LyricsService.viewers += root.visible ? 1 : -1
    }
    onVisibleChanged: root.syncViewer()
    Component.onCompleted: root.syncViewer()
    Component.onDestruction: if (root.registered) LyricsService.viewers--

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: LyricsService.status !== "ok"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 48
                    implicitHeight: 48

                    MaterialLoadingIndicator {
                        anchors.fill: parent
                        loading: LyricsService.status === "loading"
                        colBg: root.indicatorColor
                        colShape: root.indicatorShapeColor
                        implicitSize: 48
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.restartLyrics()
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: LyricsService.status === "ok"
            spacing: 6

            Repeater {
                model: 7
                delegate: StyledText {
                    id: lyricSlot
                    required property int index
                    Layout.fillWidth: true
                    horizontalAlignment: root.textAlignment
                    wrapMode: Text.WordWrap
                    text: LyricsService.slots[index] ?? ""
                    readonly property int dist: Math.abs(index - LyricsService.before)
                    font.pixelSize: {
                        if (dist === 0) return Appearance.font.pixelSize.normal
                        if (dist === 1) return Appearance.font.pixelSize.small
                        return Appearance.font.pixelSize.smaller
                    }
                    opacity: {
                        if (dist === 0) return 1.0
                        if (dist === 1) return 0.6
                        if (dist === 2) return 0.35
                        return 0.15
                    }
                    color: dist === 0 ? root.activeColor : root.textColor
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}