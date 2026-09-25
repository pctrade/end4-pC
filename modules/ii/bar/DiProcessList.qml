import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// The heaviest processes for one resource, with a way to end them. Registers with Pressure while it's on screen —
// that's what makes the process scan run at all when no alert is up (and it stops the moment this goes away).
//
// Each row: the app's icon, its name, and a faint fill behind it for its share of what's being used. Up to
// `visibleRows` show at once; the rest scroll inside the list (the wheel never leaks into the island).
//
// Ending takes two clicks (the first arms the button for a few seconds): SIGTERM lets the app close properly;
// if it's still there after that, the button turns into "Force" (SIGKILL). Protected processes — the compositor,
// the shell, audio — never get a button.
Item {
    id: list
    property string kind: "cpu"
    property int visibleRows: 5
    property color fadeColor: Appearance.colors.colLayer0
    readonly property int rowHeight: 42

    implicitHeight: list.procs.length === 0 ? 36 : Math.min(list.procs.length, list.visibleRows) * list.rowHeight
    Behavior on implicitHeight {
        NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutCubic }
    }

    readonly property var procs: Pressure.procs[list.kind] ?? []

    function iconFor(app) {
        if (!app) return ""
        const entry = DesktopEntries.byId(app) ?? DesktopEntries.heuristicLookup(app)
        if (entry?.icon && AppSearch.iconExists(entry.icon)) return entry.icon
        if (AppSearch.iconExists(app)) return app
        if (AppSearch.iconExists(app.toLowerCase())) return app.toLowerCase()
        return ""
    }

    property string watchedKind: ""
    function rewatch() {
        if (list.watchedKind === list.kind) return
        if (list.watchedKind !== "") Pressure.watch(list.watchedKind, false)
        list.watchedKind = list.kind
        Pressure.watch(list.kind, true)
    }
    onKindChanged: list.rewatch()
    Component.onCompleted: list.rewatch()
    Component.onDestruction: if (list.watchedKind !== "") Pressure.watch(list.watchedKind, false)

    StyledText {
        anchors.centerIn: parent
        visible: list.procs.length === 0
        text: Translation.tr("Measuring…")
        font.pixelSize: Appearance.font.pixelSize.smallest
        color: Appearance.colors.colOnLayer0
        opacity: 0.55
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        MouseArea {
            parent: scroller
            anchors.fill: parent
            z: 10
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                const step = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 120 * list.rowHeight
                scroller.contentY = Math.max(0, Math.min(scroller.contentHeight - scroller.height, scroller.contentY - step))
                wheel.accepted = true
            }
        }

        Column {
            id: column
            width: scroller.width

            Repeater {
                model: list.procs

                delegate: Item {
                    id: row
                    required property var modelData
                    readonly property string killState: Pressure.killState(row.modelData.pid)
                    readonly property bool abnormal: row.modelData.abnormal
                    readonly property string iconName: list.iconFor(row.modelData.app ?? row.modelData.name)
                    readonly property bool hasIcon: row.iconName !== ""
                    readonly property bool showKill: !row.modelData.protected && row.killState !== "ending" && row.killState !== "forcing"
                        && (rowHover.hovered || row.abnormal || row.armed || row.killState === "stuck")
                    property bool armed: false
                    width: column.width
                    height: list.rowHeight

                    HoverHandler { id: rowHover }

                    Timer {
                        id: disarm
                        interval: 3000
                        onTriggered: row.armed = false
                    }

                    Rectangle {
                        anchors {
                            fill: parent
                            topMargin: 2
                            bottomMargin: 2
                        }
                        radius: 12
                        color: row.abnormal ? ColorUtils.transparentize(Appearance.colors.colError, 0.86)
                            : rowHover.hovered ? Appearance.colors.colLayer1 : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: IslandMotion.micro }
                        }

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            radius: parent.radius
                            width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, row.modelData.share)))
                            color: row.abnormal ? Appearance.colors.colError : Appearance.colors.colPrimary
                            opacity: 0.08

                            Behavior on width {
                                NumberAnimation { duration: IslandMotion.long; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 6
                        }
                        spacing: 9

                        Item {
                            implicitWidth: 24
                            implicitHeight: 24

                            IconImage {
                                anchors.fill: parent
                                visible: row.hasIcon
                                source: row.hasIcon ? Quickshell.iconPath(row.iconName) : ""
                                implicitSize: 24
                            }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: !row.hasIcon
                                text: row.modelData.protected ? "shield" : "terminal"
                                iconSize: 18
                                color: Appearance.colors.colOnLayer0
                                opacity: 0.6
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: -3

                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnLayer0
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: row.killState === "ending" ? Translation.tr("Ending…")
                                    : row.killState === "forcing" ? Translation.tr("Forcing…")
                                    : row.killState === "stuck" ? Translation.tr("Didn't close")
                                    : row.abnormal ? Translation.tr("Out of line")
                                    : Translation.tr("%1% of the total").arg(Math.round(row.modelData.share * 100))
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: row.abnormal || row.killState === "stuck" ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                                opacity: row.abnormal || row.killState !== "" ? 1 : 0.5
                                elide: Text.ElideRight
                            }
                        }

                        StyledText {
                            text: row.modelData.text
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            color: row.abnormal ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                        }

                        Rectangle {
                            id: killButton
                            readonly property bool wide: row.armed || row.killState === "stuck"
                            Layout.preferredWidth: row.showKill ? (killButton.wide ? killText.implicitWidth + 18 : 26) : 0
                            implicitHeight: 26
                            radius: 13
                            visible: Layout.preferredWidth > 1
                            opacity: row.showKill ? 1 : 0
                            color: killButton.wide ? Appearance.colors.colError
                                : killMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colError, 0.7)
                                : Appearance.colors.colLayer2

                            Behavior on Layout.preferredWidth {
                                NumberAnimation { duration: IslandMotion.micro; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: IslandMotion.micro }
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: !killButton.wide
                                text: "close"
                                iconSize: 15
                                color: killMouse.containsMouse ? Appearance.colors.colError : Appearance.colors.colOnLayer2
                            }
                            StyledText {
                                id: killText
                                anchors.centerIn: parent
                                visible: killButton.wide
                                text: row.killState === "stuck" ? Translation.tr("Force") : Translation.tr("End?")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnError
                            }

                            MouseArea {
                                id: killMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (row.killState === "stuck") {
                                        Pressure.kill(row.modelData.pid, true)
                                    } else if (row.armed) {
                                        row.armed = false
                                        Pressure.kill(row.modelData.pid, false)
                                    } else {
                                        row.armed = true
                                        disarm.restart()
                                    }
                                }
                            }

                            StyledToolTip {
                                extraVisibleCondition: killMouse.containsMouse && !killButton.wide
                                text: Translation.tr("End process · PID %1").arg(row.modelData.pid)
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 18
        visible: scroller.contentHeight > scroller.height + 1 && scroller.contentY < scroller.contentHeight - scroller.height - 2
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: list.fadeColor }
        }
    }
}
