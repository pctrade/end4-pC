pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Scope {
    id: root

    PanelWindow {
        id: panelWindow
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: Docker.popupVisible

        function hide() {
            Docker.popupVisible = false;
        }

        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:docker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Docker.popupVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        onVisibleChanged: {
            if (visible) {
                GlobalFocusGrab.addDismissable(panelWindow);
                Docker.refresh();
                Docker.refreshStats();
                searchInput.forceActiveFocus();
            } else {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                panelWindow.hide();
            }
        }

        // Dark dimming backdrop scrim (click outside closes)
        Rectangle {
            anchors.fill: parent
            color: "#80000000"
            opacity: Docker.popupVisible ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: panelWindow.hide()
            }
        }

        // Main Dashboard Window Card
        Rectangle {
            id: dashboardCard
            anchors.centerIn: parent
            width: Math.min(parent.width - 60, 600)
            height: Math.min(parent.height - 80, 650)
            radius: Appearance.rounding.windowRounding
            color: Appearance.colors.colLayer0Base || Appearance.m3colors.m3surface || "#1E1E2E"
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            opacity: Docker.popupVisible ? 1 : 0
            scale: Docker.popupVisible ? 1 : 0.96
            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            // Prevent clicks inside the window from closing it
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    MaterialShapeWrappedMaterialSymbol {
                        iconSize: Appearance.font.pixelSize.huge
                        text: "deployed_code"
                        shape: MaterialShape.Shape.Cookie4Sided
                        color: Appearance.colors.colPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: "Docker Dashboard"
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnLayer0
                        }

                        StyledText {
                            text: Docker.isAvailable 
                                ? (Docker.runningCount + " running · " + Docker.stoppedCount + " stopped · " + Docker.totalCount + " total")
                                : "Docker daemon unreachable"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Docker.unhealthyCount > 0 
                                ? Appearance.colors.colError 
                                : Appearance.colors.colOnLayer1
                        }
                    }

                    // Bulk Actions
                    RowLayout {
                        spacing: 6

                        RippleButton {
                            implicitWidth: 36
                            implicitHeight: 36
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colLayer1
                            onClicked: {
                                Docker.refresh();
                                Docker.refreshStats();
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "refresh"
                                iconSize: 20
                                color: Appearance.colors.colOnLayer0
                            }
                            StyledToolTip { text: "Refresh containers & stats" }
                        }

                        RippleButton {
                            implicitWidth: 36
                            implicitHeight: 36
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colLayer1
                            onClicked: Docker.pruneContainers()

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "delete_sweep"
                                iconSize: 20
                                color: Appearance.colors.colError
                            }
                            StyledToolTip { text: "Prune stopped containers" }
                        }

                        RippleButton {
                            implicitWidth: 36
                            implicitHeight: 36
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colLayer1
                            onClicked: panelWindow.hide()

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: 20
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledToolTip { text: "Close dashboard (Esc)" }
                        }
                    }
                }

                // Search Bar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer1
                    border.width: searchInput.activeFocus ? 1 : 0
                    border.color: Appearance.colors.colPrimary

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "search"
                            iconSize: 18
                            color: Appearance.colors.colOnLayer1
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer0
                            clip: true

                            Text {
                                text: "Search by container, image, stack, or port (e.g. 8000)..."
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                                opacity: 0.6
                                visible: !searchInput.text && !searchInput.activeFocus
                            }
                        }

                        MaterialSymbol {
                            visible: searchInput.text.length > 0
                            text: "close"
                            iconSize: 16
                            color: Appearance.colors.colOnLayer1
                            MouseArea {
                                anchors.fill: parent
                                onClicked: searchInput.text = ""
                            }
                        }
                    }
                }

                // Container List
                Flickable {
                    id: flickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: contentCol.implicitHeight
                    contentWidth: width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: contentCol
                        width: parent.width - 4
                        spacing: 10

                        // Empty state
                        Rectangle {
                            visible: Docker.containers.length === 0
                            Layout.fillWidth: true
                            implicitHeight: 140
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colLayer1

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                MaterialSymbol {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "inbox"
                                    iconSize: 40
                                    color: Appearance.colors.colOnLayer1
                                }
                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Docker.isAvailable ? "No containers found" : "Docker daemon is not reachable"
                                    color: Appearance.colors.colOnLayer1
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                }
                            }
                        }

                        // Stacks / Projects
                        Repeater {
                            model: Docker.projects

                            delegate: ColumnLayout {
                                id: projectItem
                                required property var modelData
                                property bool collapsed: false

                                function matchesFilter(c) {
                                    if (!c) return false;
                                    if (!searchInput.text || searchInput.text.trim() === "") return true;
                                    var q = searchInput.text.toLowerCase().trim();
                                    if (c.name && c.name.toLowerCase().indexOf(q) !== -1) return true;
                                    if (c.image && c.image.toLowerCase().indexOf(q) !== -1) return true;
                                    if (c.project && c.project.toLowerCase().indexOf(q) !== -1) return true;
                                    if (c.ports) {
                                        for (var i = 0; i < c.ports.length; i++) {
                                            if (c.ports[i].indexOf(q) !== -1) return true;
                                        }
                                    }
                                    return false;
                                }

                                readonly property var filteredContainers: modelData ? modelData.containers.filter(matchesFilter) : []
                                visible: filteredContainers.length > 0
                                Layout.fillWidth: true
                                spacing: 6

                                // Stack Header Bar
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 38
                                    radius: Appearance.rounding.small
                                    color: Appearance.colors.colLayer1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        MaterialSymbol {
                                            text: projectItem.collapsed ? "chevron_right" : "expand_more"
                                            iconSize: 20
                                            color: Appearance.colors.colOnLayer1
                                        }

                                        StyledText {
                                            text: projectItem.modelData ? projectItem.modelData.name : ""
                                            font.weight: Font.Bold
                                            font.pixelSize: Appearance.font.pixelSize.normal
                                            color: Appearance.colors.colPrimary
                                        }

                                        StyledText {
                                            text: projectItem.modelData ? ("(" + projectItem.modelData.runningCount + "/" + projectItem.modelData.totalCount + " active)") : ""
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colOnLayer1
                                        }

                                        Item { Layout.fillWidth: true }

                                        RippleButton {
                                            implicitWidth: 28
                                            implicitHeight: 28
                                            buttonRadius: Appearance.rounding.full
                                            colBackground: "transparent"
                                            onClicked: {
                                                if (projectItem.modelData.allRunning) {
                                                    Docker.stopProject(projectItem.modelData.name);
                                                } else {
                                                    Docker.startProject(projectItem.modelData.name);
                                                }
                                            }

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: (projectItem.modelData && projectItem.modelData.allRunning) ? "stop" : "play_arrow"
                                                iconSize: 18
                                                color: (projectItem.modelData && projectItem.modelData.allRunning) ? Appearance.colors.colError : Appearance.colors.colSuccess
                                            }
                                            StyledToolTip { text: (projectItem.modelData && projectItem.modelData.allRunning) ? "Stop all in stack" : "Start all in stack" }
                                        }

                                        RippleButton {
                                            implicitWidth: 28
                                            implicitHeight: 28
                                            buttonRadius: Appearance.rounding.full
                                            colBackground: "transparent"
                                            onClicked: Docker.restartProject(projectItem.modelData.name)

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "restart_alt"
                                                iconSize: 18
                                                color: Appearance.colors.colOnLayer1
                                            }
                                            StyledToolTip { text: "Restart stack" }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.rightMargin: 70
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: projectItem.collapsed = !projectItem.collapsed
                                    }
                                }

                                // Containers in this stack
                                ColumnLayout {
                                    visible: !projectItem.collapsed
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 10
                                    spacing: 6

                                    Repeater {
                                        model: projectItem.filteredContainers
                                        delegate: containerCardDelegate
                                    }
                                }
                            }
                        }

                        // Standalone Containers
                        Repeater {
                            model: Docker.standaloneContainers.filter(function(c) {
                                if (!c) return false;
                                if (!searchInput.text || searchInput.text.trim() === "") return true;
                                var q = searchInput.text.toLowerCase().trim();
                                if (c.name && c.name.toLowerCase().indexOf(q) !== -1) return true;
                                if (c.image && c.image.toLowerCase().indexOf(q) !== -1) return true;
                                if (c.ports) {
                                    for (var i = 0; i < c.ports.length; i++) {
                                        if (c.ports[i].indexOf(q) !== -1) return true;
                                    }
                                }
                                return false;
                            })
                            delegate: containerCardDelegate
                        }
                    }
                }
            }
        }
    }

    Component {
        id: containerCardDelegate

        Rectangle {
            id: card
            required property var modelData
            readonly property var containerData: modelData
            Layout.fillWidth: true
            implicitHeight: cardInner.implicitHeight + 16
            radius: Appearance.rounding.small
            color: (containerData && containerData.state === "running")
                ? (Appearance.colors.colLayer2 || "#252538") 
                : (Appearance.colors.colLayer1 || "#1E1E2E")
            border.width: 1
            border.color: (containerData && containerData.health === "unhealthy")
                ? Appearance.colors.colError 
                : (containerData && containerData.state === "running" ? Appearance.colors.colLayer0Border : "transparent")

            ColumnLayout {
                id: cardInner
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Top Row: Status Dot + Name + Controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Status Indicator Dot
                    Rectangle {
                        implicitWidth: 12
                        implicitHeight: 12
                        radius: 6
                        color: {
                            if (!containerData) return Appearance.colors.colOutline;
                            if (containerData.health === "unhealthy") return Appearance.colors.colError;
                            if (containerData.state === "running") return Appearance.colors.colSuccess;
                            if (containerData.state === "restarting") return Appearance.colors.colWarning;
                            return Appearance.colors.colOutline;
                        }
                        MouseArea {
                            id: dotMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                        StyledToolTip { 
                            extraVisibleCondition: dotMouse.containsMouse
                            alternativeVisibleCondition: dotMouse.containsMouse
                            text: (containerData && containerData.status) ? containerData.status : "" 
                        }
                    }

                    // Container Name & Image
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: (containerData && containerData.name) ? containerData.name : ""
                            font.weight: Font.Bold
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer0
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: (containerData && containerData.image) ? containerData.image : ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Action Buttons
                    RowLayout {
                        spacing: 4

                        // Play / Stop
                        RippleButton {
                            implicitWidth: 30
                            implicitHeight: 30
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colLayer3 || Appearance.colors.colLayer1
                            onClicked: {
                                if (containerData.state === "running") {
                                    Docker.stopContainer(containerData.id);
                                } else {
                                    Docker.startContainer(containerData.id);
                                }
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: (containerData && containerData.state === "running") ? "stop" : "play_arrow"
                                iconSize: 18
                                color: (containerData && containerData.state === "running") ? Appearance.colors.colError : Appearance.colors.colSuccess
                            }
                            StyledToolTip { text: (containerData && containerData.state === "running") ? "Stop container" : "Start container" }
                        }

                        // Restart
                        RippleButton {
                            implicitWidth: 30
                            implicitHeight: 30
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colLayer3 || Appearance.colors.colLayer1
                            onClicked: Docker.restartContainer(containerData.id)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "restart_alt"
                                iconSize: 18
                                color: Appearance.colors.colOnLayer0
                            }
                            StyledToolTip { text: "Restart container" }
                        }

                        // Terminal Logs
                        RippleButton {
                            implicitWidth: 30
                            implicitHeight: 30
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colLayer3 || Appearance.colors.colLayer1
                            onClicked: Docker.openTerminalLogs(containerData.name)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "article"
                                iconSize: 18
                                color: Appearance.colors.colOnLayer0
                            }
                            StyledToolTip { text: "Open live logs in terminal" }
                        }

                        // Exec Shell
                        RippleButton {
                            implicitWidth: 30
                            implicitHeight: 30
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colLayer3 || Appearance.colors.colLayer1
                            onClicked: Docker.openTerminalExec(containerData.name)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "terminal"
                                iconSize: 18
                                color: Appearance.colors.colOnLayer0
                            }
                            StyledToolTip { text: "Open shell inside container" }
                        }

                        // Delete
                        RippleButton {
                            implicitWidth: 30
                            implicitHeight: 30
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colLayer3 || Appearance.colors.colLayer1
                            onClicked: Docker.removeContainer(containerData.id)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "delete"
                                iconSize: 18
                                color: Appearance.colors.colError
                            }
                            StyledToolTip { text: "Remove container" }
                        }
                    }
                }

                // Bottom Row: Live Stats (CPU / RAM) & Clickable Port Chips
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: containerData && (containerData.state === "running" || (containerData.ports && containerData.ports.length > 0))

                    // CPU & RAM stats
                    RowLayout {
                        visible: containerData && containerData.state === "running" && !!containerData.mem
                        spacing: 8

                        StyledText {
                            text: (containerData && containerData.cpu) ? ("CPU: " + containerData.cpu) : ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colPrimary
                        }

                        StyledText {
                            text: (containerData && containerData.mem) ? ("RAM: " + containerData.mem) : ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Clickable Port Chips
                    RowLayout {
                        spacing: 4
                        Repeater {
                            model: (containerData && containerData.ports) ? containerData.ports : []

                            delegate: Rectangle {
                                required property var modelData
                                implicitHeight: 22
                                implicitWidth: portLabel.implicitWidth + 16
                                radius: Appearance.rounding.verysmall
                                color: Appearance.colors.colPrimaryContainer

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    MaterialSymbol {
                                        text: "public"
                                        iconSize: 13
                                        color: Appearance.colors.colOnPrimaryContainer
                                    }
                                    StyledText {
                                        id: portLabel
                                        text: ":" + modelData
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.Bold
                                        color: Appearance.colors.colOnPrimaryContainer
                                    }
                                }

                                MouseArea {
                                    id: portMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Docker.openPortInBrowser(modelData)
                                }
                                StyledToolTip { 
                                    extraVisibleCondition: portMouse.containsMouse
                                    alternativeVisibleCondition: portMouse.containsMouse
                                    text: "Open http://localhost:" + modelData + " in browser" 
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
