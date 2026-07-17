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
        if (seconds <= 0) return "0";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        if (h > 0) {
            return h + "h";
        }
        return m + "m";
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
        radius: Appearance.rounding?.verylarge ?? 30
        color: Appearance.colors.colPrimaryContainer

        StyledRectangularShadow {
            target: card
            z: -2
        }

        // Layout for variation 1: 2x2 Square layout
        ColumnLayout {
            visible: root.sizeMode === "2x2"
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 8

            // Header Section
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialShapeWrappedMaterialSymbol {
                    wrappedShape: MaterialShape.Shape.Cookie4Sided
                    color: Appearance.colors.colPrimary
                    colSymbol: Appearance.colors.colOnPrimary
                    text: "schedule"
                    iconSize: 20
                    fill: 1
                    padding: 6
                    implicitWidth: 32
                    implicitHeight: 32
                }

                ColumnLayout {
                    spacing: -2
                    Layout.fillWidth: true

                    StyledText {
                        text: "Screen Time"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimaryContainer
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: "Active window usage"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }

            // Stats Section
            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                StyledText {
                    text: root.formatTime(root.totalScreentime)
                    font.pixelSize: 26
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnPrimaryContainer
                }

                StyledText {
                    text: "Uptime: " + root.formatTime(root.totalUptime)
                    font.pixelSize: 10
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.5
                }
            }

            // Bar Chart Section
            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 14

                Item {
                    id: chart2x2
                    width: 196
                    height: 50
                    Layout.alignment: Qt.AlignHCenter

                    property real maxVal: {
                        let max = 0;
                        for (let i = 0; i < 24; i++) {
                            let val = root.hourlyUsage[i.toString()] ?? 0;
                            if (val > max) max = val;
                        }
                        return max > 0 ? max : 1;
                    }

                    // Horizontal Gridlines
                    Rectangle {
                        width: 166
                        height: 1
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.08
                        anchors.top: parent.top
                    }
                    Rectangle {
                        width: 166
                        height: 1
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.08
                        anchors.verticalCenter: parent.top
                        anchors.verticalCenterOffset: parent.height / 2
                    }
                    Rectangle {
                        width: 166
                        height: 1
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.08
                        anchors.bottom: parent.bottom
                    }

                    // Vertical Dashed Gridlines & Horizontal Labels
                    Repeater {
                        model: [0, 6, 12, 18]
                        delegate: Item {
                            required property int modelData
                            anchors.fill: parent

                            // Dashed Line Column
                            Column {
                                spacing: 2
                                anchors.horizontalCenter: parent.left
                                anchors.horizontalCenterOffset: modelData * 7 + 2.5
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                
                                Repeater {
                                    model: Math.floor(chart2x2.height / 4)
                                    delegate: Rectangle {
                                        width: 1
                                        height: 2
                                        color: Appearance.colors.colOnPrimaryContainer
                                        opacity: 0.12
                                    }
                                }
                            }

                            // Horizontal hour label (00, 06, 12, 18)
                            StyledText {
                                text: modelData < 10 ? "0" + modelData : modelData.toString()
                                font.pixelSize: 8
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.4
                                anchors.horizontalCenter: parent.left
                                anchors.horizontalCenterOffset: modelData * 7 + 2.5
                                anchors.top: parent.bottom
                                anchors.topMargin: 4
                            }
                        }
                    }

                    // Vertical Axis Labels (on the right)
                    StyledText {
                        text: root.formatHourAxis(chart2x2.maxVal)
                        font.pixelSize: 8
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.4
                        anchors.left: parent.left
                        anchors.leftMargin: 172
                        anchors.verticalCenter: parent.top
                    }
                    StyledText {
                        text: root.formatHourAxis(chart2x2.maxVal / 2)
                        font.pixelSize: 8
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.4
                        anchors.left: parent.left
                        anchors.leftMargin: 172
                        anchors.verticalCenter: parent.top
                        anchors.verticalCenterOffset: parent.height / 2
                    }
                    StyledText {
                        text: "0"
                        font.pixelSize: 8
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.4
                        anchors.left: parent.left
                        anchors.leftMargin: 172
                        anchors.verticalCenter: parent.bottom
                    }

                    // The Active Bars
                    Row {
                        id: barsRow2x2
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        spacing: 2

                        Repeater {
                            model: 24
                            delegate: Rectangle {
                                required property int index
                                width: 5
                                height: Math.max(2, ((root.hourlyUsage[index.toString()] ?? 0) / chart2x2.maxVal) * chart2x2.height)
                                radius: 1.2
                                color: Appearance.colors.colPrimary
                                opacity: {
                                    const val = root.hourlyUsage[index.toString()] ?? 0;
                                    if (val === 0) return 0.0;
                                    return new Date().getHours() === index ? 1.0 : 0.6;
                                }
                                anchors.bottom: parent.bottom
                            }
                        }
                    }
                }
            }

            // Top Apps Grid
            Grid {
                columns: 2
                columnSpacing: 16
                rowSpacing: 8
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 4

                Repeater {
                    model: root.getSortedApps().slice(0, 4)
                    delegate: RowLayout {
                        required property var modelData
                        spacing: 8
                        width: 114

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 5
                            color: "transparent"
                            clip: true

                            IconImage {
                                anchors.fill: parent
                                source: Quickshell.iconPath(AppSearch.guessIcon(modelData.name), "image-missing")
                            }
                        }

                        ColumnLayout {
                            spacing: -3
                            Layout.fillWidth: true

                            StyledText {
                                text: root.formatAppName(modelData.name)
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnPrimaryContainer
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: root.formatTime(modelData.time)
                                font.pixelSize: 9
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.6
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        // Layout for variation 2: 1x4 Horizontal layout
        RowLayout {
            visible: root.sizeMode === "1x4"
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 12

            // Left Column (Stats & Chart)
            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: 236
                spacing: 4

                ColumnLayout {
                    spacing: -4
                    Layout.fillWidth: true

                    StyledText {
                        text: root.formatTime(root.totalScreentime)
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        text: "Uptime: " + root.formatTime(root.totalUptime)
                        font.pixelSize: 9
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.5
                    }
                }

                // Small Bar Chart Section
                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 14

                    Item {
                        id: chart1x4
                        width: 196
                        height: 40
                        Layout.alignment: Qt.AlignHCenter

                        property real maxVal: {
                            let max = 0;
                            for (let i = 0; i < 24; i++) {
                                let val = root.hourlyUsage[i.toString()] ?? 0;
                                if (val > max) max = val;
                            }
                            return max > 0 ? max : 1;
                        }

                        // Horizontal Gridlines
                        Rectangle {
                            width: 166
                            height: 1
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.08
                            anchors.top: parent.top
                        }
                        Rectangle {
                            width: 166
                            height: 1
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.08
                            anchors.verticalCenter: parent.top
                            anchors.verticalCenterOffset: parent.height / 2
                        }
                        Rectangle {
                            width: 166
                            height: 1
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.08
                            anchors.bottom: parent.bottom
                        }

                        // Vertical Dashed Gridlines & Horizontal Labels
                        Repeater {
                            model: [0, 6, 12, 18]
                            delegate: Item {
                                required property int modelData
                                anchors.fill: parent

                                // Dashed Line Column
                                Column {
                                    spacing: 2
                                    anchors.horizontalCenter: parent.left
                                    anchors.horizontalCenterOffset: modelData * 7 + 2.5
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    
                                    Repeater {
                                        model: Math.floor(chart1x4.height / 4)
                                        delegate: Rectangle {
                                            width: 1
                                            height: 2
                                            color: Appearance.colors.colOnPrimaryContainer
                                            opacity: 0.12
                                        }
                                    }
                                }

                                // Horizontal hour label (00, 06, 12, 18)
                                StyledText {
                                    text: modelData < 10 ? "0" + modelData : modelData.toString()
                                    font.pixelSize: 8
                                    color: Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.4
                                    anchors.horizontalCenter: parent.left
                                    anchors.horizontalCenterOffset: modelData * 7 + 2.5
                                    anchors.top: parent.bottom
                                    anchors.topMargin: 4
                                }
                            }
                        }

                        // Vertical Axis Labels (on the right)
                        StyledText {
                            text: root.formatHourAxis(chart1x4.maxVal)
                            font.pixelSize: 8
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.4
                            anchors.left: parent.left
                            anchors.leftMargin: 172
                            anchors.verticalCenter: parent.top
                        }
                        StyledText {
                            text: root.formatHourAxis(chart1x4.maxVal / 2)
                            font.pixelSize: 8
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.4
                            anchors.left: parent.left
                            anchors.leftMargin: 172
                            anchors.verticalCenter: parent.top
                            anchors.verticalCenterOffset: parent.height / 2
                        }
                        StyledText {
                            text: "0"
                            font.pixelSize: 8
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.4
                            anchors.left: parent.left
                            anchors.leftMargin: 172
                            anchors.verticalCenter: parent.bottom
                        }

                        // The Active Bars
                        Row {
                            id: barsRow1x4
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            spacing: 2

                            Repeater {
                                model: 24
                                delegate: Rectangle {
                                    required property int index
                                    width: 5
                                    height: Math.max(2, ((root.hourlyUsage[index.toString()] ?? 0) / chart1x4.maxVal) * chart1x4.height)
                                    radius: 1.2
                                    color: Appearance.colors.colPrimary
                                    opacity: {
                                        const val = root.hourlyUsage[index.toString()] ?? 0;
                                        if (val === 0) return 0.0;
                                        return new Date().getHours() === index ? 1.0 : 0.6;
                                    }
                                    anchors.bottom: parent.bottom
                                }
                            }
                        }
                    }
                }
            }

            // Vertical Divider
            Rectangle {
                width: 1
                Layout.fillHeight: true
                color: Appearance.colors.colOnPrimaryContainer
                opacity: 0.08
            }

            // Right Column (Apps List - Minimal)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4
                Layout.alignment: Qt.AlignTop

                Repeater {
                    model: root.getSortedApps().slice(0, 4)
                    delegate: RowLayout {
                        required property var modelData
                        spacing: 8
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 4
                            color: "transparent"
                            clip: true

                            IconImage {
                                anchors.fill: parent
                                source: Quickshell.iconPath(AppSearch.guessIcon(modelData.name), "image-missing")
                            }
                        }

                        StyledText {
                            text: root.formatTime(modelData.time)
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.8
                            Layout.fillWidth: true
                            elide: Text.ElideRight
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
