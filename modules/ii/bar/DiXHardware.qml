import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Expanded hardware event: headline on top, a visual per kind (monitor layout, dock, drive, charger, disk).
ColumnLayout {
    id: xhw
    required property Item di
    spacing: 12
    implicitWidth: xhw.wantedWidth
    readonly property real wantedWidth: xhw.kind === "monitor" ? 440 : ["dock", "diskLow"].includes(xhw.kind) ? 532 : 372

    property var payload: IslandHardware.payload
    property var runAction: id => IslandHardware.runAction(id)
    readonly property string kind: xhw.payload.kind ?? ""
    readonly property color accent: IslandEvents.toneColor(xhw.payload.tone)
    readonly property color onAccent: ColorUtils.isDark(xhw.accent) ? "white" : "black"
    readonly property var actions: xhw.payload.actions ?? []
    readonly property string layout: xhw.payload.layout ?? "extend"
    readonly property var parts: (xhw.payload.subtitle ?? "").split(" · ").filter(p => p !== "")
    readonly property var hero: ({ key: "hardware-icon", item: headerIcon })

    readonly property string resolution: xhw.payload.resolution || (xhw.parts.find(p => p.includes("×")) ?? "")
    readonly property string refresh: xhw.parts.find(p => /Hz$/.test(p)) ?? ""
    readonly property string model: {
        const first = xhw.parts[0] ?? ""
        return first.includes("×") || /Hz$/.test(first) ? (xhw.payload.output ?? "") : first
    }

    readonly property string headline: {
        switch (xhw.kind) {
            case "monitor": return xhw.parts.join(" · ")
            case "dock": return ""
            default: return xhw.payload.subtitle ?? ""
        }
    }

    function formatDuration(seconds) {
        const minutes = Math.round(seconds / 60)
        if (minutes < 60) return Translation.tr("%1 min").arg(minutes)
        return Translation.tr("%1 h %2 min").arg(Math.floor(minutes / 60)).arg(minutes % 60)
    }

    component SectionLabel: StyledText {
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    component StatusLine: StyledText {
        visible: text !== ""
        text: xhw.payload.status ?? ""
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: xhw.accent
        elide: Text.ElideRight
    }

    component InfoChip: Rectangle {
        id: chip
        property string icon: ""
        property string value: ""
        property string label: ""
        property color tint: Appearance.colors.colPrimary
        property color base: Appearance.colors.colLayer1
        implicitHeight: 40
        implicitWidth: chipRow.implicitWidth + 20
        radius: 12
        color: chip.base

        RowLayout {
            id: chipRow
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 10
            }
            spacing: 8

            MaterialSymbol {
                text: chip.icon
                iconSize: 18
                fill: 1
                color: chip.tint
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: -1
                StyledText {
                    Layout.fillWidth: true
                    text: chip.value
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: chip.label
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.55
                    elide: Text.ElideRight
                }
            }
        }
    }

    component ActionPill: Rectangle {
        id: pill
        property var action: ({})
        property bool primary: false
        property int cascadeIndex: 0
        readonly property color ink: pill.primary ? xhw.onAccent : Appearance.colors.colOnLayer1
        implicitWidth: pillRow.implicitWidth + 24
        implicitHeight: 32
        radius: 16
        color: pill.primary ? (pillMouse.containsMouse ? Qt.darker(xhw.accent, 1.1) : xhw.accent)
            : (pillMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1)
        DiCascade { target: pill; index: pill.cascadeIndex; pressed: pillMouse.pressed }

        Behavior on color {
            ColorAnimation { duration: IslandMotion.micro }
        }

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 6
            MaterialSymbol {
                text: pill.action.icon ?? ""
                iconSize: 16
                fill: 1
                color: pill.primary ? pill.ink : xhw.accent
            }
            StyledText {
                text: pill.action.label ?? ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: pill.primary ? Font.DemiBold : Font.Medium
                color: pill.ink
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: xhw.runAction(pill.action.id)
        }
    }

    component LayoutPicker: Rectangle {
        id: picker
        readonly property int count: xhw.actions.length
        readonly property int currentIndex: Math.max(0, xhw.actions.findIndex(a => a.id === xhw.layout))
        readonly property real segment: (picker.width - 8) / Math.max(1, picker.count)
        implicitHeight: 38
        radius: 19
        color: Appearance.colors.colLayer1

        DiSpring {
            id: slide
            target: picker.currentIndex
            stiffness: 420
            dampingRatio: 0.78
            epsilon: 0.002
        }

        Rectangle {
            x: 4 + slide.value * picker.segment
            y: 4
            width: picker.segment
            height: picker.height - 8
            radius: height / 2
            color: xhw.accent
        }

        Row {
            x: 4
            y: 4
            Repeater {
                model: picker.count
                delegate: Item {
                    id: seg
                    required property int index
                    readonly property var action: xhw.actions[seg.index] ?? ({})
                    readonly property bool current: seg.index === picker.currentIndex
                    width: picker.segment
                    height: picker.height - 8

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: segMouse.containsMouse && !seg.current ? Appearance.colors.colLayer2 : "transparent"
                        Behavior on color {
                            ColorAnimation { duration: IslandMotion.micro }
                        }
                    }
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5
                        MaterialSymbol {
                            text: seg.action.icon ?? ""
                            iconSize: 16
                            fill: 1
                            color: seg.current ? xhw.onAccent : xhw.accent
                            Behavior on color {
                                ColorAnimation { duration: IslandMotion.micro }
                            }
                        }
                        StyledText {
                            Layout.maximumWidth: seg.width - 30
                            text: seg.action.label ?? ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: seg.current ? Font.DemiBold : Font.Normal
                            color: seg.current ? xhw.onAccent : Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                            Behavior on color {
                                ColorAnimation { duration: IslandMotion.micro }
                            }
                        }
                    }
                    MouseArea {
                        id: segMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: xhw.runAction(seg.action.id)
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        MaterialShapeWrappedMaterialSymbol {
            id: headerIcon
            wrappedShape: MaterialShape.Shape.Cookie9Sided
            color: ColorUtils.transparentize(xhw.accent, 0.78)
            colSymbol: xhw.accent
            text: xhw.payload.icon ?? "memory"
            iconSize: 18
            fill: 1
            padding: 7
        }
        ColumnLayout {
            id: headerText
            Layout.fillWidth: true
            spacing: -2
            DiCascade { target: headerText; index: 0 }

            StyledText {
                Layout.fillWidth: true
                text: xhw.payload.title ?? ""
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: xhw.headline
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
                opacity: 0.65
                elide: Text.ElideRight
            }
        }
        ColumnLayout {
            id: headerValue
            visible: (xhw.payload.value ?? "") !== "" && xhw.kind !== "charger"
            spacing: -3
            DiCascade { target: headerValue; index: 0 }

            StyledText {
                Layout.alignment: Qt.AlignRight
                text: xhw.payload.value ?? ""
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: xhw.accent
            }
            StyledText {
                Layout.alignment: Qt.AlignRight
                visible: xhw.kind === "diskLow"
                text: Translation.tr("free")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.55
            }
        }
    }

    Loader {
        Layout.fillWidth: true
        sourceComponent: {
            switch (xhw.kind) {
                case "monitor": return monitorBody
                case "dock": return dockBody
                case "drive": return driveBody
                case "charger": return chargerBody
                case "diskLow": return diskBody
                default: return genericBody
            }
        }
    }

    Component {
        id: monitorBody

        ColumnLayout {
            spacing: 8

            Rectangle {
                id: stage
                Layout.fillWidth: true
                Layout.preferredHeight: 116
                radius: 16
                color: Appearance.colors.colLayer1
                DiCascade { target: stage; index: 1 }

                readonly property bool mirror: xhw.layout === "mirror"
                readonly property bool only: xhw.layout === "only"
                readonly property real deskY: stage.height - 30
                readonly property real gap: 18
                readonly property real startX: (stage.width - laptopScreen.width - stage.gap - externalScreen.width) / 2

                Rectangle {
                    id: laptopScreen
                    width: 72
                    height: 44
                    radius: 6
                    z: stage.mirror ? 2 : 0
                    x: stage.mirror ? stage.width / 2 - width + 6 : stage.startX
                    y: stage.deskY - height - 6
                    color: stage.only ? Appearance.colors.colLayer1
                        : Qt.tint(Appearance.colors.colLayer1, ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85))
                    border.width: 1.5
                    border.color: stage.only ? ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.75) : Appearance.colors.colPrimary
                    opacity: stage.only ? 0.45 : 1

                    Behavior on x {
                        NumberAnimation { duration: IslandMotion.long; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: IslandMotion.short }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: stage.only ? "desktop_access_disabled" : stage.mirror ? "screen_share" : "laptop"
                        iconSize: 17
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.8
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height + 2
                        width: parent.width + 12
                        height: 4
                        radius: 2
                        color: parent.border.color
                    }
                }

                Rectangle {
                    id: externalScreen
                    width: 108
                    height: 62
                    radius: 6
                    z: 1
                    x: stage.mirror ? stage.width / 2 - 14 : stage.startX + laptopScreen.width + stage.gap
                    y: stage.deskY - height - 11
                    color: Qt.tint(Appearance.colors.colLayer1, ColorUtils.transparentize(Appearance.colors.colPrimary, 0.78))
                    border.width: 1.5
                    border.color: Appearance.colors.colPrimary

                    Behavior on x {
                        NumberAnimation { duration: IslandMotion.long; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "desktop_windows"
                            iconSize: 19
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            visible: text !== ""
                            text: xhw.resolution
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.75
                        }
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height
                        width: 6
                        height: 8
                        color: parent.border.color
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height + 8
                        width: 34
                        height: 3
                        radius: 1.5
                        color: parent.border.color
                    }
                }

                StyledText {
                    id: layoutCaption
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                        bottomMargin: 8
                    }
                    text: stage.mirror ? Translation.tr("Same picture on both")
                        : stage.only ? Translation.tr("Laptop screen off")
                        : Translation.tr("Extended to the right")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.6
                }
            }

            LayoutPicker {
                id: monitorPicker
                Layout.fillWidth: true
                visible: xhw.actions.length > 0
                DiCascade { target: monitorPicker; index: 3 }
            }
            StatusLine {
                Layout.fillWidth: true
            }
        }
    }

    Component {
        id: dockBody

        ColumnLayout {
            id: dockCol
            spacing: 6

            readonly property var ports: xhw.parts.map(p => {
                if (/\d\s*W$/.test(p)) return { icon: "power", value: p, label: Translation.tr("Charging") }
                if (p === "USB") return { icon: "usb", value: "USB", label: Translation.tr("Hub") }
                if (p === Translation.tr("network")) return { icon: "lan", value: Translation.tr("Wired"), label: Translation.tr("Network") }
                if (p === Translation.tr("power")) return { icon: "power", value: Translation.tr("Power"), label: Translation.tr("Charging") }
                if (/\d/.test(p)) return { icon: "desktop_windows", value: xhw.resolution || p, label: xhw.resolution ? p : Translation.tr("Display") }
                return { icon: "cable", value: p, label: "" }
            })

            DiSpring {
                id: cable
                stiffness: 60
                dampingRatio: 1
                epsilon: 0.002
            }
            Timer {
                interval: 180
                running: true
                onTriggered: cable.target = 1
            }

            SectionLabel {
                id: throughLabel
                text: Translation.tr("Through one cable")
                DiCascade { target: throughLabel; index: 1 }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Rectangle {
                    id: laptopNode
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: 14
                    color: Appearance.colors.colLayer1
                    DiCascade { target: laptopNode; index: 1 }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "laptop"
                        iconSize: 22
                        fill: 1
                        color: xhw.accent
                    }
                }
                Item {
                    implicitWidth: 22
                    implicitHeight: 48
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * cable.value
                        height: 3
                        radius: 1.5
                        color: xhw.accent
                    }
                }
                Rectangle {
                    id: dockBox
                    Layout.fillWidth: true
                    implicitHeight: 56
                    radius: 16
                    color: ColorUtils.transparentize(xhw.accent, 0.9)
                    border.width: 1.5
                    border.color: ColorUtils.transparentize(xhw.accent, 0.6)
                    DiCascade { target: dockBox; index: 2 }

                    RowLayout {
                        anchors {
                            fill: parent
                            margins: 8
                        }
                        spacing: 6
                        Repeater {
                            model: dockCol.ports
                            delegate: InfoChip {
                                id: portChip
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredWidth: portChip.implicitWidth
                                base: Appearance.colors.colLayer1
                                tint: xhw.accent
                                icon: portChip.modelData.icon
                                value: portChip.modelData.value
                                label: portChip.modelData.label
                                DiCascade { target: portChip; index: 3 + portChip.index }
                            }
                        }
                    }
                }
            }

            SectionLabel {
                id: dockLayoutLabel
                Layout.topMargin: 6
                visible: xhw.actions.length > 0
                text: Translation.tr("Screen layout")
                DiCascade { target: dockLayoutLabel; index: 4 }
            }
            LayoutPicker {
                id: dockPicker
                Layout.fillWidth: true
                visible: xhw.actions.length > 0
                DiCascade { target: dockPicker; index: 5 }
            }
            StatusLine {
                Layout.fillWidth: true
            }
        }
    }

    Component {
        id: driveBody

        ColumnLayout {
            id: driveCol
            spacing: 8

            property real sizeBytes: 0
            property real usedBytes: -1
            readonly property bool known: driveCol.usedBytes >= 0 && driveCol.sizeBytes > 0
            readonly property real usedRatio: driveCol.known ? Math.min(1, driveCol.usedBytes / driveCol.sizeBytes) : 0
            readonly property string capacity: xhw.parts[0] ?? ""
            readonly property string fsType: xhw.parts[1] ?? ""
            readonly property string freeKey: xhw.payload.free ?? ""
            readonly property string device: xhw.payload.device ?? ""

            function probe() {
                if (driveCol.device.startsWith("/dev/ilha-teste")) {
                    driveCol.sizeBytes = 32e9
                    driveCol.usedBytes = 11.4e9
                    return
                }
                if (driveCol.device === "") return
                usageProc.command = ["lsblk", "-bnPo", "FSSIZE,FSUSED", driveCol.device]
                usageProc.running = true
            }
            Component.onCompleted: driveCol.probe()
            onFreeKeyChanged: driveCol.probe()

            Process {
                id: usageProc
                stdout: StdioCollector {
                    onStreamFinished: {
                        const size = /FSSIZE="(\d+)"/.exec(text)
                        const used = /FSUSED="(\d+)"/.exec(text)
                        if (size && used) {
                            driveCol.sizeBytes = Number(size[1])
                            driveCol.usedBytes = Number(used[1])
                        }
                    }
                }
            }

            DiSpring {
                id: fillIn
                target: 0
                stiffness: 50
                dampingRatio: 1
                epsilon: 0.002
            }
            Timer {
                interval: 260
                running: true
                onTriggered: fillIn.target = 1
            }

            RowLayout {
                id: driveNumbers
                Layout.fillWidth: true
                spacing: 10
                DiCascade { target: driveNumbers; index: 1 }

                StyledText {
                    text: driveCol.known ? IslandHardware.formatSize(driveCol.sizeBytes - driveCol.usedBytes) : (driveCol.capacity || "–")
                    font.pixelSize: 34
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -1
                    StyledText {
                        Layout.fillWidth: true
                        text: driveCol.known ? Translation.tr("free") : Translation.tr("capacity")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.8
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: driveCol.known ? [Translation.tr("of %1").arg(IslandHardware.formatSize(driveCol.sizeBytes)), driveCol.fsType].filter(Boolean).join(" · ")
                            : [driveCol.fsType, Translation.tr("open it to see what's free")].filter(Boolean).join(" · ")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.6
                        elide: Text.ElideRight
                    }
                }
            }

            Item {
                id: stick
                Layout.fillWidth: true
                implicitHeight: 22
                DiCascade { target: stick; index: 2 }

                Rectangle {
                    id: stickBody
                    anchors {
                        left: parent.left
                        right: plug.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    radius: 8
                    color: Appearance.colors.colLayer1
                    clip: true

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: Math.max(driveCol.known ? 12 : 0, parent.width * driveCol.usedRatio * fillIn.value)
                        radius: 8
                        color: xhw.accent
                    }
                    StyledText {
                        anchors {
                            right: parent.right
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        visible: driveCol.known
                        text: `${Math.round(driveCol.usedRatio * 100)}%`
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.7
                    }
                }
                Rectangle {
                    id: plug
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    width: 14
                    height: 12
                    radius: 2
                    color: Appearance.colors.colLayer2
                    Rectangle {
                        x: 4; y: 3; width: 3; height: 3
                        color: Appearance.colors.colLayer1
                    }
                    Rectangle {
                        x: 4; y: 7; width: 3; height: 3
                        color: Appearance.colors.colLayer1
                    }
                }
            }

            RowLayout {
                id: legend
                Layout.fillWidth: true
                visible: driveCol.known
                spacing: 14
                DiCascade { target: legend; index: 3 }

                Repeater {
                    model: [
                        { color: xhw.accent, text: Translation.tr("Used %1").arg(IslandHardware.formatSize(driveCol.usedBytes)) },
                        { color: Appearance.colors.colLayer2, text: Translation.tr("Free %1").arg(IslandHardware.formatSize(driveCol.sizeBytes - driveCol.usedBytes)) }
                    ]
                    delegate: RowLayout {
                        required property var modelData
                        spacing: 5
                        Rectangle {
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: 4
                            color: modelData.color
                        }
                        StyledText {
                            text: modelData.text
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.65
                        }
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: xhw.actions.length > 0
                spacing: 6
                Repeater {
                    model: xhw.actions
                    delegate: ActionPill {
                        required property var modelData
                        required property int index
                        action: modelData
                        primary: index === 0
                        cascadeIndex: 4 + index
                    }
                }
            }
            StatusLine {
                Layout.fillWidth: true
            }
        }
    }

    Component {
        id: chargerBody

        ColumnLayout {
            id: chargerCol
            spacing: 8

            readonly property int watts: parseInt(xhw.payload.value ?? "") || Math.round(Battery.energyRate)
            readonly property int minimum: IslandHardware.slowChargerWatts
            readonly property real scaleMax: Math.max(65, chargerCol.minimum * 2, chargerCol.watts * 1.2)
            readonly property bool slow: chargerCol.watts < chargerCol.minimum
            readonly property color tint: chargerCol.slow ? IslandEvents.colorAttention : IslandEvents.colorSuccess

            DiSpring {
                id: powerFill
                stiffness: 50
                dampingRatio: 1
                epsilon: 0.002
            }
            Timer {
                interval: 260
                running: true
                onTriggered: powerFill.target = 1
            }

            RowLayout {
                id: chargerNumbers
                Layout.fillWidth: true
                spacing: 10
                DiCascade { target: chargerNumbers; index: 1 }

                StyledText {
                    text: `${chargerCol.watts} W`
                    font.pixelSize: 36
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: chargerCol.tint
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -1
                    StyledText {
                        text: Translation.tr("going in now")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.8
                    }
                    StyledText {
                        text: Translation.tr("a normal charge needs %1 W or more").arg(chargerCol.minimum)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.6
                    }
                }
                Item {
                    implicitWidth: 58
                    implicitHeight: 28
                    Rectangle {
                        id: cell
                        width: 52
                        height: 28
                        radius: 7
                        color: "transparent"
                        border.width: 1.5
                        border.color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.6)
                        Rectangle {
                            x: 3
                            y: 3
                            height: parent.height - 6
                            width: Math.max(4, (parent.width - 6) * Battery.percentage * powerFill.value)
                            radius: 4
                            color: ColorUtils.transparentize(chargerCol.tint, 0.55)
                        }
                        StyledText {
                            anchors.centerIn: parent
                            text: `${Math.round(Battery.percentage * 100)}%`
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnLayer0
                        }
                    }
                    Rectangle {
                        anchors.left: cell.right
                        anchors.leftMargin: 1
                        anchors.verticalCenter: cell.verticalCenter
                        width: 4
                        height: 10
                        radius: 2
                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.6)
                    }
                }
            }

            Item {
                id: gauge
                Layout.fillWidth: true
                implicitHeight: 32
                DiCascade { target: gauge; index: 2 }

                Rectangle {
                    id: track
                    width: parent.width
                    height: 12
                    radius: 6
                    color: Appearance.colors.colLayer1
                    clip: true
                    Rectangle {
                        height: parent.height
                        width: Math.max(12, parent.width * Math.min(1, chargerCol.watts / chargerCol.scaleMax) * powerFill.value)
                        radius: 6
                        color: chargerCol.tint
                    }
                }
                Rectangle {
                    id: minMark
                    x: track.width * chargerCol.minimum / chargerCol.scaleMax - 1
                    y: -3
                    width: 2
                    height: track.height + 6
                    radius: 1
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.7
                }
                StyledText {
                    x: Math.max(0, Math.min(gauge.width - width, minMark.x - width / 2))
                    y: track.height + 5
                    text: Translation.tr("min. %1 W").arg(chargerCol.minimum)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.6
                }
                StyledText {
                    anchors.right: parent.right
                    y: track.height + 5
                    text: `${Math.round(chargerCol.scaleMax)} W`
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.45
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                InfoChip {
                    id: fullChip
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icon: "schedule"
                    tint: chargerCol.tint
                    value: Battery.isCharging && Battery.timeToFull > 0 ? xhw.formatDuration(Battery.timeToFull)
                        : Battery.isPluggedIn ? Translation.tr("Not charging") : Translation.tr("Unplugged")
                    label: Translation.tr("Until full")
                    DiCascade { target: fullChip; index: 3 }
                }
                InfoChip {
                    id: tipChip
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icon: "bolt"
                    tint: chargerCol.tint
                    value: Translation.tr("Use the original charger")
                    label: Translation.tr("or a USB-C PD one")
                    DiCascade { target: tipChip; index: 4 }
                }
            }
        }
    }

    Component {
        id: diskBody

        RowLayout {
            id: diskRow
            spacing: 16

            property var partitions: []
            readonly property var suggestions: xhw.actions

            Component.onCompleted: dfProc.running = true

            Process {
                id: dfProc
                command: ["bash", "-c", "LC_ALL=C df -B1 --output=source,fstype,size,used,target -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs 2>/dev/null | tail -n +2"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const bySource = {}
                        for (const line of text.trim().split("\n")) {
                            const f = line.trim().split(/\s+/)
                            if (f.length < 5 || !f[0].startsWith("/dev/") || f[0].includes("loop")) continue
                            const size = Number(f[2])
                            if (!(size > 100e6)) continue
                            const target = f.slice(4).join(" ")
                            const known = bySource[f[0]]
                            if (!known || target.length < known.target.length)
                                bySource[f[0]] = { target: target, fs: f[1], size: size, used: Number(f[3]) }
                        }
                        const list = Object.keys(bySource).map(k => bySource[k])
                        list.sort((a, b) => (a.target === "/" ? -1 : b.target === "/" ? 1 : b.size - a.size))
                        diskRow.partitions = list.slice(0, 3)
                    }
                }
            }

            readonly property var shown: diskRow.partitions.length > 0 ? diskRow.partitions
                : [{ target: "/", fs: "", size: ResourceUsage.diskTotal * 1024, used: ResourceUsage.diskUsed * 1024 }]

            ColumnLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: 240
                Layout.maximumWidth: 240
                Layout.alignment: Qt.AlignTop
                spacing: 6

                SectionLabel {
                    id: partLabel
                    text: Translation.tr("Partitions")
                    DiCascade { target: partLabel; index: 1 }
                }
                Repeater {
                    model: diskRow.shown.length
                    delegate: Rectangle {
                        id: part
                        required property int index
                        readonly property var d: diskRow.shown[part.index] ?? ({})
                        readonly property real ratio: part.d.size > 0 ? Math.min(1, part.d.used / part.d.size) : 0
                        readonly property color tint: part.ratio > 0.95 ? IslandEvents.colorError
                            : part.ratio > 0.85 ? IslandEvents.colorAttention : Appearance.colors.colPrimary
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: 12
                        color: Appearance.colors.colLayer1
                        clip: true
                        DiCascade { target: part; index: 2 + part.index }

                        DiSpring {
                            id: partFill
                            stiffness: 55
                            dampingRatio: 1
                            epsilon: 0.002
                        }
                        Timer {
                            interval: 300 + part.index * 60
                            running: true
                            onTriggered: partFill.target = 1
                        }
                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: part.width * part.ratio * partFill.value
                            color: ColorUtils.transparentize(part.tint, 0.8)
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 10
                            }
                            spacing: 8
                            MaterialSymbol {
                                text: part.d.target === "/" ? "hard_drive" : part.d.target === "/boot" || part.d.target === "/efi" ? "settings_power" : "folder"
                                iconSize: 18
                                fill: 1
                                color: part.tint
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: -1
                                StyledText {
                                    Layout.fillWidth: true
                                    text: part.d.target === "/" ? Translation.tr("System") : (part.d.target ?? "")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideMiddle
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: [`${IslandHardware.formatSize(part.d.used)} / ${IslandHardware.formatSize(part.d.size)}`, (part.d.fs ?? "")].filter(Boolean).join(" · ")
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.features: { "tnum": 1 }
                                    color: Appearance.colors.colOnLayer1
                                    opacity: 0.6
                                    elide: Text.ElideRight
                                }
                            }
                            StyledText {
                                text: `${Math.round(part.ratio * 100)}%`
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                                color: part.tint
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 6

                SectionLabel {
                    id: cleanLabel
                    text: Translation.tr("Free up space")
                    DiCascade { target: cleanLabel; index: 1 }
                }
                Repeater {
                    model: diskRow.suggestions.length
                    delegate: Rectangle {
                        id: tip
                        required property int index
                        readonly property var action: diskRow.suggestions[tip.index] ?? ({})
                        readonly property var labelParts: (tip.action.label ?? "").split(" · ")
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: 12
                        color: tipMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
                        DiCascade { target: tip; index: 2 + tip.index; pressed: tipMouse.pressed }

                        Behavior on color {
                            ColorAnimation { duration: IslandMotion.micro }
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 8
                            }
                            spacing: 8
                            MaterialSymbol {
                                text: tip.action.icon ?? ""
                                iconSize: 18
                                fill: 1
                                color: xhw.accent
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: tip.labelParts[0] ?? ""
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                            }
                            StyledText {
                                visible: text !== ""
                                text: tip.labelParts[1] ?? ""
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                                color: xhw.accent
                            }
                            MaterialSymbol {
                                text: "chevron_right"
                                iconSize: 18
                                color: Appearance.colors.colOnLayer1
                                opacity: 0.45
                            }
                        }
                        MouseArea {
                            id: tipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: xhw.runAction(tip.action.id)
                        }
                    }
                }
                StyledText {
                    id: cleanHint
                    Layout.fillWidth: true
                    visible: diskRow.suggestions.length <= 1
                    text: Translation.tr("Trash and package cache are already small")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.55
                    wrapMode: Text.Wrap
                    DiCascade { target: cleanHint; index: 3 }
                }
            }
        }
    }

    Component {
        id: genericBody

        ColumnLayout {
            spacing: 8
            StatusLine {
                id: genericStatus
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                DiCascade { target: genericStatus; index: 1 }
            }
            Flow {
                Layout.fillWidth: true
                visible: xhw.actions.length > 0
                spacing: 6
                Repeater {
                    model: xhw.actions
                    delegate: ActionPill {
                        required property var modelData
                        required property int index
                        action: modelData
                        primary: index === 0
                        cascadeIndex: 2 + index
                    }
                }
            }
        }
    }
}
