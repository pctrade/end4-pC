import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// The island's event log, newest first: filter chips, grouped list, detail of the selected event.
ColumnLayout {
    id: xh
    required property Item di
    spacing: 8
    implicitWidth: xh.wantedWidth
    readonly property real wantedWidth: xh.log.length > 0 ? 532 : 372

    readonly property var log: IslandEvents.eventLog
    property double now: Date.now()

    Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: xh.now = Date.now()
    }

    readonly property var groups: [
        { id: "all", label: Translation.tr("All"), icon: "history", kinds: [] },
        { id: "notification", label: Translation.tr("Notifications"), icon: "notifications", kinds: ["notification"] },
        { id: "activity", label: Translation.tr("Activities"), icon: "bolt", kinds: ["activity"] },
        { id: "download", label: Translation.tr("Downloads"), icon: "download_done", kinds: ["download"] },
        { id: "peek", label: Translation.tr("System"), icon: "memory", kinds: ["peek"] },
        { id: "error", label: Translation.tr("Errors"), icon: "error", kinds: ["error"] }
    ]
    property string filter: "all"

    function groupOf(kind) {
        return xh.groups.find(g => g.kinds.includes(kind)) ?? xh.groups[0]
    }
    function countFor(group) {
        return group.id === "all" ? xh.log.length : xh.log.filter(e => group.kinds.includes(e.kind)).length
    }
    readonly property var chips: xh.groups
        .map(g => ({ id: g.id, label: g.label, icon: g.icon, count: xh.countFor(g) }))
        .filter(g => g.id === "all" || g.count > 0 || g.id === xh.filter)

    readonly property var filtered: {
        const group = xh.groups.find(g => g.id === xh.filter)
        return !group || group.id === "all" ? xh.log : xh.log.filter(e => group.kinds.includes(e.kind))
    }
    onFilteredChanged: if (xh.filter !== "all" && xh.filtered.length === 0) xh.filter = "all"

    function keyOf(entry) {
        return entry ? `${entry.time}|${entry.title}` : ""
    }
    property string selectedKey: ""
    readonly property var selected: xh.filtered.find(e => xh.keyOf(e) === xh.selectedKey) ?? xh.filtered[0] ?? null

    function bucketOf(time) {
        if (xh.now - time < 5 * 60000) return "now"
        return new Date(time).toDateString() === new Date(xh.now).toDateString() ? "today" : "earlier"
    }
    readonly property var bucketLabels: ({
        now: Translation.tr("Now"),
        today: Translation.tr("Today"),
        earlier: Translation.tr("Earlier")
    })
    readonly property var rows: {
        const out = []
        let last = ""
        for (const entry of xh.filtered) {
            const bucket = xh.bucketOf(entry.time)
            if (bucket !== last) {
                out.push({ header: true, label: xh.bucketLabels[bucket] })
                last = bucket
            }
            out.push({ header: false, entry: entry })
        }
        return out
    }

    function ago(time) {
        const seconds = Math.max(0, Math.round((xh.now - time) / 1000))
        if (seconds < 60) return Translation.tr("now")
        if (seconds < 3600) return Translation.tr("%1 min").arg(Math.floor(seconds / 60))
        if (seconds < 86400) return Translation.tr("%1 h").arg(Math.floor(seconds / 3600))
        return Translation.tr("%1 d").arg(Math.floor(seconds / 86400))
    }
    function when(time) {
        const clock = Qt.formatDateTime(new Date(time), "HH:mm")
        if (new Date(time).toDateString() === new Date(xh.now).toDateString())
            return Translation.tr("Today, %1").arg(clock)
        return `${Qt.formatDateTime(new Date(time), Config.options?.time?.shortDateFormat ?? "dd/MM")}, ${clock}`
    }
    function accentFor(kind) {
        return kind === "error" ? Appearance.colors.colError : Appearance.colors.colPrimary
    }
    function actionLabel(action) {
        switch (action?.type) {
            case "file":         return Translation.tr("Open file")
            case "command":      return Translation.tr("Run again")
            case "notification": return Translation.tr("Show notification")
            default:             return ""
        }
    }
    function runAction(entry) {
        const action = entry?.action
        if (action?.type === "file") IslandEvents.openDownload(action.path)
        else if (action?.type === "command") IslandEvents.rerunCommand(action.data)
        else if (action?.type === "notification") GlobalStates.sidebarRightOpen = true
        else return
        xh.di.collapse()
    }

    Connections {
        target: xh.di
        function onHistoryIndexChanged() {
            const entry = xh.log[xh.di.historyIndex]
            if (!entry) return
            if (!xh.filtered.includes(entry)) xh.filter = "all"
            xh.selectedKey = xh.keyOf(entry)
        }
    }

    property bool settled: false
    Timer {
        interval: 900
        running: true
        onTriggered: xh.settled = true
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        spacing: 6

        Repeater {
            model: xh.chips.length

            delegate: Item {
                id: chipSlot
                required property int index
                readonly property var d: xh.chips[chipSlot.index] ?? ({})
                readonly property bool active: xh.filter === chipSlot.d.id
                readonly property real fullWidth: chipRow.implicitWidth + 22
                Layout.preferredWidth: chipSlot.fullWidth
                Layout.preferredHeight: 32
                visible: xh.log.length > 0

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                }

                Rectangle {
                    id: chip
                    anchors.fill: parent
                    radius: 16
                    color: chipSlot.active ? Appearance.colors.colSecondaryContainer
                        : chipMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
                    DiCascade { target: chip; index: chipSlot.index; pressed: chipMouse.pressed }

                    Behavior on color {
                        ColorAnimation { duration: IslandMotion.micro }
                    }

                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialSymbol {
                            text: chipSlot.d.icon ?? ""
                            iconSize: 16
                            fill: 1
                            color: chipSlot.active ? Appearance.colors.colOnSecondaryContainer
                                : chipSlot.d.id === "error" ? Appearance.colors.colError : Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            visible: chipSlot.active
                            text: chipSlot.d.label ?? ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                        StyledText {
                            text: chipSlot.d.count ?? 0
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: chipSlot.active ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                            opacity: chipSlot.active ? 0.75 : 0.6
                        }
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: xh.filter = chipSlot.d.id
                    }
                }
            }
        }

        RowLayout {
            visible: xh.log.length === 0
            spacing: 8
            MaterialSymbol {
                text: "history"
                iconSize: 18
                fill: 1
                color: Appearance.colors.colPrimary
            }
            StyledText {
                text: Translation.tr("Recent events")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }
        }

        Item { Layout.fillWidth: true }

        Item {
            id: clearSlot
            visible: xh.log.length > 0
            Layout.preferredWidth: clearRow.implicitWidth + 24
            Layout.preferredHeight: 32

            Rectangle {
                id: clearButton
                anchors.fill: parent
                radius: 16
                color: clearMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
                DiCascade { target: clearButton; index: xh.chips.length; pressed: clearMouse.pressed }

                Behavior on color {
                    ColorAnimation { duration: IslandMotion.micro }
                }

                RowLayout {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 5
                    MaterialSymbol {
                        text: "delete_sweep"
                        iconSize: 16
                        fill: 1
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: Translation.tr("Clear")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                    }
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: IslandEvents.clearEventLog()
                }
            }
        }
    }

    Item {
        id: emptySlot
        visible: xh.log.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: 150

        ColumnLayout {
            id: emptyState
            anchors.centerIn: parent
            spacing: 2
            DiCascade { target: emptyState; index: 1 }

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "history_toggle_off"
                iconSize: 30
                color: Appearance.colors.colOnLayer0
                opacity: 0.35
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Nothing has happened yet")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                opacity: 0.6
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 300
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: Translation.tr("Notifications, finished tasks and downloads that pass through the island land here")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.45
            }
        }
    }

    RowLayout {
        visible: xh.log.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: 186
        spacing: 8

        Flickable {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: listColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: list.contentHeight > list.height

            Behavior on contentY {
                enabled: !list.moving
                NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutCubic }
            }

            function reveal(item) {
                const y = item.mapToItem(listColumn, 0, 0).y
                if (y < list.contentY) list.contentY = Math.max(0, y - 22)
                else if (y + item.height > list.contentY + list.height)
                    list.contentY = Math.min(list.contentHeight - list.height, y + item.height - list.height)
            }

            ColumnLayout {
                id: listColumn
                width: list.width
                spacing: 4

                Repeater {
                    model: xh.rows.length

                    delegate: Item {
                        id: slot
                        required property int index
                        readonly property var d: xh.rows[slot.index] ?? ({ header: true, label: "" })
                        readonly property var entry: slot.d.header ? null : slot.d.entry
                        readonly property bool isSelected: slot.entry !== null && slot.entry === xh.selected
                        Layout.fillWidth: true
                        Layout.preferredHeight: slot.d.header ? 16 : 34
                        Layout.topMargin: slot.d.header && slot.index > 0 ? 4 : 0

                        onIsSelectedChanged: if (slot.isSelected && xh.settled) list.reveal(slot)

                        StyledText {
                            id: sectionLabel
                            visible: slot.d.header
                            anchors {
                                left: parent.left
                                leftMargin: 4
                                verticalCenter: parent.verticalCenter
                            }
                            text: slot.d.label ?? ""
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.6
                        }

                        Rectangle {
                            id: row
                            visible: !slot.d.header
                            anchors.fill: parent
                            radius: 12
                            color: slot.isSelected ? Appearance.colors.colLayer2
                                : rowMouse.containsMouse ? ColorUtils.mix(Appearance.colors.colLayer1, Appearance.colors.colLayer2, 0.5)
                                : Appearance.colors.colLayer1
                            DiCascade {
                                target: row
                                index: slot.index + 1
                                delay: xh.settled ? 0 : 60
                                step: xh.settled || slot.index > 8 ? 0 : 30
                                pressed: rowMouse.pressed
                                pressedScale: 0.98
                            }

                            Behavior on color {
                                ColorAnimation { duration: IslandMotion.micro }
                            }

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    leftMargin: 3
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 3
                                height: slot.isSelected ? 14 : 0
                                radius: 1.5
                                color: xh.accentFor(slot.entry?.kind)
                                Behavior on height {
                                    NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutBack }
                                }
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 11
                                    rightMargin: 10
                                }
                                spacing: 8

                                MaterialSymbol {
                                    text: slot.entry?.icon ?? "bolt"
                                    iconSize: 17
                                    fill: 1
                                    color: slot.entry?.kind === "error" ? Appearance.colors.colError
                                        : slot.isSelected ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                                    Behavior on color {
                                        ColorAnimation { duration: IslandMotion.micro }
                                    }
                                }

                                StyledText {
                                    id: rowTitle
                                    Layout.fillWidth: rowSub.text === ""
                                    Layout.maximumWidth: rowSub.text === "" ? -1 : Math.max(80, list.width * 0.55)
                                    Layout.minimumWidth: 0
                                    text: slot.entry?.title ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    id: rowSub
                                    visible: text !== ""
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: (slot.entry?.subtitle ?? "").replace(/\s+/g, " ")
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colOnLayer1
                                    opacity: 0.55
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: slot.entry ? xh.ago(slot.entry.time) : ""
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.features: { "tnum": 1 }
                                    color: Appearance.colors.colOnLayer1
                                    opacity: 0.55
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (slot.isSelected) xh.runAction(slot.entry)
                                    else xh.selectedKey = xh.keyOf(slot.entry)
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: detailSlot
            Layout.preferredWidth: 176
            Layout.fillHeight: true

            Rectangle {
                id: detail
                anchors.fill: parent
                radius: 12
                color: Appearance.colors.colLayer1
                DiCascade { target: detail; index: 3 }

                readonly property var entry: xh.selected
                readonly property color accent: xh.accentFor(detail.entry?.kind)

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 10
                    }
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            implicitWidth: 30
                            implicitHeight: 30
                            radius: 15
                            color: ColorUtils.transparentize(detail.accent, 0.82)
                            Behavior on color {
                                ColorAnimation { duration: IslandMotion.micro }
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: detail.entry?.icon ?? "history"
                                iconSize: 17
                                fill: 1
                                color: detail.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: -2

                            StyledText {
                                Layout.fillWidth: true
                                text: xh.groupOf(detail.entry?.kind).id === "all" ? Translation.tr("Event")
                                    : xh.groupOf(detail.entry?.kind).label
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer1
                                opacity: 0.6
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: detail.entry ? xh.when(detail.entry.time) : ""
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.features: { "tnum": 1 }
                                color: Appearance.colors.colOnLayer1
                                opacity: 0.55
                                elide: Text.ElideRight
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        text: detail.entry?.title ?? ""
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 0
                        visible: text !== ""
                        text: detail.entry?.subtitle ?? ""
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.65
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        clip: true
                        verticalAlignment: Text.AlignTop
                    }
                    Item {
                        Layout.fillHeight: true
                        visible: (detail.entry?.subtitle ?? "") === ""
                    }

                    RowLayout {
                        visible: !actionSlot.visible
                        Layout.fillWidth: true
                        spacing: 5
                        MaterialSymbol {
                            text: "today"
                            iconSize: 14
                            fill: 1
                            color: Appearance.colors.colOnLayer1
                            opacity: 0.55
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                const today = xh.log.filter(e => xh.bucketOf(e.time) !== "earlier")
                                const errors = today.filter(e => e.kind === "error").length
                                const parts = [Translation.tr("%1 today").arg(today.length)]
                                if (errors > 0) parts.push(errors === 1 ? Translation.tr("1 error") : Translation.tr("%1 errors").arg(errors))
                                return parts.join(" · ")
                            }
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnLayer1
                            opacity: 0.55
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        id: actionSlot
                        visible: xh.actionLabel(detail.entry?.action) !== ""
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32

                        Rectangle {
                            id: actionButton
                            anchors.fill: parent
                            radius: 16
                            color: actionMouse.containsMouse ? Appearance.colors.colPrimaryContainerHover
                                : Appearance.colors.colPrimaryContainer
                            DiCascade { target: actionButton; index: 5; pressed: actionMouse.pressed }

                            Behavior on color {
                                ColorAnimation { duration: IslandMotion.micro }
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 5
                                MaterialSymbol {
                                    text: detail.entry?.action?.type === "file" ? "open_in_new"
                                        : detail.entry?.action?.type === "command" ? "replay" : "notifications"
                                    iconSize: 16
                                    fill: 1
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                                StyledText {
                                    text: xh.actionLabel(detail.entry?.action)
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                            }

                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: xh.runAction(detail.entry)
                            }
                        }
                    }
                }
            }
        }
    }
}
