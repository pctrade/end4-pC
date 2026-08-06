import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "screentime"
    hoverEnabled: true

    property string sizeMode: root.configEntry.sizeMode ?? "2x2"

    implicitWidth: sizeMode === "1x4" ? 400 : 276
    implicitHeight: sizeMode === "1x4" ? 120 : 252

    Behavior on implicitWidth {
        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
    }

    property var parsedData: null
    property int totalScreentime: parsedData?.total_screentime ?? 0
    property int totalUptime: parsedData?.total_uptime ?? 0
    property var appsData: parsedData?.apps ?? {}
    property var hourlyUsage: parsedData?.hourly_usage ?? {}

    function formatTime(seconds) {
        if (seconds <= 0) return "0m";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        if (h > 0) {
            return h + "h " + m + "m";
        }
        return m + "m";
    }

    function getSortedApps() {
        if (!appsData) return [];
        let list = [];
        for (let name in appsData) {
            list.push({ name: name, time: appsData[name] });
        }
        list.sort((a, b) => b.time - a.time);
        return list;
    }

    function formatAppName(name) {
        if (!name) return "";
        if (name.includes(".")) {
            const parts = name.split(".");
            name = parts[parts.length - 1];
        }
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    function formatHourAxis(seconds) {
        if (seconds <= 0) return "0h/hr";
        const h = (seconds / 3600).toFixed(1);
        return h + "h/hr";
    }

    Process {
        id: trackerProc
        command: ["python3", Quickshell.shellPath("scripts/screentime/screentime_tracker.py")]
        running: true
    }

    FileView {
        id: screentimeFileView
        path: Quickshell.env("HOME") + "/.cache/screentime.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const textData = screentimeFileView.text().trim();
                if (textData) {
                    root.parsedData = JSON.parse(textData);
                }
            } catch (e) {
                console.log("[ScreenTimeWidget] Error parsing JSON:", e);
            }
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Appearance.rounding?.verylarge ?? 24
        color: Appearance.colors.colLayer0

        StyledRectangularShadow {
            target: card
            z: -2
        }

        // Layout for 2x2 Square mode (Material 3 Android Wellbeing style)
        ColumnLayout {
            visible: root.sizeMode === "2x2"
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 6

            // Top Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "hourglass_bottom"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer0
                }

                StyledText {
                    text: "Screen Time"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    Layout.fillWidth: true
                }

                StyledText {
                    text: "24h History"
                    font.pixelSize: 11
                    color: Appearance.colors.colSubtext
                }
            }

            // Main Metric Readout + Peak rate
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

                StyledText {
                    text: root.formatTime(root.totalScreentime)
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer0
                }

                StyledText {
                    property real maxVal: {
                        let max = 0;
                        for (let i = 0; i < 24; i++) {
                            let val = root.hourlyUsage[i.toString()] ?? 0;
                            if (val > max) max = val;
                        }
                        return max;
                    }
                    text: "Peak: " + root.formatHourAxis(maxVal)
                    font.pixelSize: 11
                    color: Appearance.colors.colSubtext
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 4
                }
            }

            // Material 3 Bar Chart with 0-24 Full Day Timeline
            ColumnLayout {
                id: chartContainer2x2
                Layout.fillWidth: true
                spacing: 3

                Item {
                    id: chart2x2
                    Layout.fillWidth: true
                    implicitHeight: 38

                    property real maxVal: {
                        let max = 0;
                        for (let i = 0; i < 24; i++) {
                            let val = root.hourlyUsage[i.toString()] ?? 0;
                            if (val > max) max = val;
                        }
                        return max > 0 ? max : 1;
                    }

                    property int currentHour: new Date().getHours()

                    Row {
                        anchors.centerIn: parent
                        spacing: 3

                        Repeater {
                            model: 24
                            delegate: Item {
                                required property int index
                                property int hourIndex: index
                                property real hourVal: root.hourlyUsage[hourIndex.toString()] ?? 0
                                property bool isCurrentHour: hourIndex === chart2x2.currentHour

                                width: 6
                                height: chart2x2.implicitHeight

                                Rectangle {
                                    width: parent.width
                                    height: Math.max(4, (hourVal / chart2x2.maxVal) * chart2x2.implicitHeight)
                                    radius: width / 2
                                    anchors.bottom: parent.bottom

                                    color: isCurrentHour ? Appearance.colors.colSecondaryContainer :
                                            (hourVal > 0 ? ColorUtils.mix(Appearance.colors.colPrimary, Appearance.colors.colLayer0, 0.45)
                                                         : ColorUtils.mix(Appearance.colors.colOnLayer0, Appearance.colors.colLayer0, 0.12))
                                    border.width: isCurrentHour ? 1 : 0
                                    border.color: Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }
                    }
                }

                // 0-24 Hour Timeline Markings Row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10

                    StyledText { text: "00"; font.pixelSize: 9; color: Appearance.colors.colSubtext }
                    Item { Layout.fillWidth: true }
                    StyledText { text: "06"; font.pixelSize: 9; color: Appearance.colors.colSubtext }
                    Item { Layout.fillWidth: true }
                    StyledText { text: "12"; font.pixelSize: 9; color: Appearance.colors.colSubtext }
                    Item { Layout.fillWidth: true }
                    StyledText { text: "18"; font.pixelSize: 9; color: Appearance.colors.colSubtext }
                    Item { Layout.fillWidth: true }
                    StyledText { text: "24"; font.pixelSize: 9; color: Appearance.colors.colSubtext }
                }
            }

            // Top Apps Usage List (Android M3 Rows)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 5

                Repeater {
                    model: root.getSortedApps().slice(0, 3)
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10

                        // Squircle Icon Box
                        Rectangle {
                            width: 26
                            height: 26
                            radius: 8
                            color: Appearance.colors.colLayer1

                            IconImage {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                source: Quickshell.iconPath(AppSearch.guessIcon(modelData.name), "image-missing")
                            }
                        }

                        StyledText {
                            text: root.formatAppName(modelData.name)
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer0
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        StyledText {
                            text: root.formatTime(modelData.time)
                            font.pixelSize: 12
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }

        // Layout for 1x4 Horizontal mode
        RowLayout {
            visible: root.sizeMode === "1x4"
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 14

            // Left Column (Stats & Bar Chart)
            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: 210
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialSymbol {
                        text: "hourglass_bottom"
                        iconSize: 16
                        color: Appearance.colors.colOnLayer0
                    }

                    StyledText {
                        text: "Screen Time"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                    }
                }

                StyledText {
                    text: root.formatTime(root.totalScreentime)
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer0
                }

                // Small M3 Bar Chart with 0-24 Timeline
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Item {
                        id: chart1x4
                        Layout.fillWidth: true
                        implicitHeight: 28

                        property real maxVal: {
                            let max = 0;
                            for (let i = 0; i < 24; i++) {
                                let val = root.hourlyUsage[i.toString()] ?? 0;
                                if (val > max) max = val;
                            }
                            return max > 0 ? max : 1;
                        }

                        property int currentHour: new Date().getHours()

                        Row {
                            anchors.centerIn: parent
                            spacing: 3

                            Repeater {
                                model: 24
                                delegate: Item {
                                    required property int index
                                    property int hourIndex: index
                                    property real hourVal: root.hourlyUsage[hourIndex.toString()] ?? 0
                                    property bool isCurrentHour: hourIndex === chart1x4.currentHour

                                    width: 5
                                    height: chart1x4.implicitHeight

                                    Rectangle {
                                        width: parent.width
                                        height: Math.max(3, (hourVal / chart1x4.maxVal) * chart1x4.implicitHeight)
                                        radius: width / 2
                                        anchors.bottom: parent.bottom

                                        color: isCurrentHour ? Appearance.colors.colSecondaryContainer :
                                                (hourVal > 0 ? ColorUtils.mix(Appearance.colors.colPrimary, Appearance.colors.colLayer0, 0.45)
                                                             : ColorUtils.mix(Appearance.colors.colOnLayer0, Appearance.colors.colLayer0, 0.12))
                                        border.width: isCurrentHour ? 1 : 0
                                        border.color: Appearance.colors.colOnPrimaryContainer
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        Layout.rightMargin: 6

                        StyledText { text: "00"; font.pixelSize: 8; color: Appearance.colors.colSubtext }
                        Item { Layout.fillWidth: true }
                        StyledText { text: "12"; font.pixelSize: 8; color: Appearance.colors.colSubtext }
                        Item { Layout.fillWidth: true }
                        StyledText { text: "24"; font.pixelSize: 8; color: Appearance.colors.colSubtext }
                    }
                }
            }

            // Divider
            Rectangle {
                width: 1
                Layout.fillHeight: true
                color: Appearance.colors.colLayer0Border
                opacity: 0.5
            }

            // Right Column (App List)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                Repeater {
                    model: root.getSortedApps().slice(0, 3)
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 6
                            color: Appearance.colors.colLayer1

                            IconImage {
                                anchors.centerIn: parent
                                width: 14
                                height: 14
                                source: Quickshell.iconPath(AppSearch.guessIcon(modelData.name), "image-missing")
                            }
                        }

                        StyledText {
                            text: root.formatAppName(modelData.name)
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer0
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        StyledText {
                            text: root.formatTime(modelData.time)
                            font.pixelSize: 11
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }

        // Resize Handle in bottom right corner
        Rectangle {
            id: resizeHandle
            width: 14; height: 14; radius: 3
            color: Appearance.colors.colOnPrimaryContainer
            anchors { right: card.right; bottom: card.bottom; margins: 4 }
            opacity: (root.containsMouse || resizeArea.containsMouse || resizeArea.pressed) ? 0.4 : 0
            visible: opacity > 0 && !Config.options.background.widgetsLocked
            Behavior on opacity { NumberAnimation { duration: 150 } }

            MouseArea {
                id: resizeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                preventStealing: true
                property real startWidth: 0
                property real startX: 0
                onPressed: (mouse) => {
                    startWidth = root.width
                    startX = mapToItem(null, mouse.x, mouse.y).x
                }
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    var globalX = mapToItem(null, mouse.x, mouse.y).x
                    var dx = globalX - startX
                    var newW = startWidth + dx
                    
                    if (newW > 338) {
                        root.sizeMode = "1x4"
                    } else {
                        root.sizeMode = "2x2"
                    }
                }
                onReleased: {
                    root.configEntry.sizeMode = root.sizeMode
                }
            }
        }
    }
}
