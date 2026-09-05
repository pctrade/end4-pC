import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    property string searchQuery: ""

    function filterMatches(c) {
        if (!c) return false;
        if (!root.searchQuery || root.searchQuery.trim() === "") return true;
        var q = root.searchQuery.toLowerCase().trim();
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

    ColumnLayout {
        id: mainLayout
        implicitWidth: 460
        spacing: 10

        // Header Card
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 96
            radius: Appearance.rounding.normal
            color: Appearance.colors.colSurfaceContainerHigh

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialShapeWrappedMaterialSymbol {
                        iconSize: Appearance.font.pixelSize.larger
                        text: "deployed_code"
                        shape: MaterialShape.Shape.Cookie4Sided
                        color: Appearance.colors.colPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: "Docker Manager"
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnSurface
                        }

                        StyledText {
                            text: Docker.isAvailable 
                                ? (Docker.runningCount + " running · " + Docker.stoppedCount + " stopped · " + Docker.totalCount + " total")
                                : "Docker daemon unreachable"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Docker.unhealthyCount > 0 
                                ? Appearance.colors.colError 
                                : Appearance.colors.colOnSurfaceVariant
                        }
                    }

                    // Bulk Actions
                    RowLayout {
                        spacing: 4

                        RippleButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: Appearance.rounding.circle
                            color: Appearance.colors.colSurfaceContainerLowest
                            onClicked: Docker.refresh()

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "refresh"
                                iconSize: 18
                                color: Appearance.colors.colOnSurface
                            }
                            StyledToolTip { text: "Refresh status & stats" }
                        }

                        RippleButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: Appearance.rounding.circle
                            color: Appearance.colors.colSurfaceContainerLowest
                            onClicked: Docker.pruneContainers()

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "delete_sweep"
                                iconSize: 18
                                color: Appearance.colors.colError
                            }
                            StyledToolTip { text: "Prune stopped containers" }
                        }
                    }
                }

                // Search Bar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colSurfaceContainerLowest

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        MaterialSymbol {
                            text: "search"
                            iconSize: 16
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurface
                            clip: true
                            onTextChanged: root.searchQuery = text

                            Text {
                                text: "Filter containers, ports, stacks..."
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSurfaceVariant
                                opacity: 0.6
                                visible: !searchInput.text && !searchInput.activeFocus
                            }
                        }

                        MaterialSymbol {
                            visible: searchInput.text.length > 0
                            text: "close"
                            iconSize: 14
                            color: Appearance.colors.colOnSurfaceVariant
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    searchInput.text = "";
                                    root.searchQuery = "";
                                }
                            }
                        }
                    }
                }
            }
        }

        // Scrollable Containers List
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(380, containerColumn.implicitHeight)
            contentHeight: containerColumn.implicitHeight
            contentWidth: width
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: containerColumn
                width: parent.width
                spacing: 8

                // Empty state
                Rectangle {
                    visible: Docker.containers.length === 0
                    Layout.fillWidth: true
                    implicitHeight: 100
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerLow

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "inbox"
                            iconSize: 32
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Docker.isAvailable ? "No containers found" : "Docker daemon is not running"
                            color: Appearance.colors.colOnSurfaceVariant
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }

                // Stacks (Compose Projects)
                Repeater {
                    model: Docker.projects

                    delegate: ColumnLayout {
                        id: projectDelegate
                        required property var modelData
                        property bool collapsed: false
                        readonly property var visibleContainers: modelData ? modelData.containers.filter(root.filterMatches) : []
                        visible: visibleContainers.length > 0
                        Layout.fillWidth: true
                        spacing: 4

                        // Stack Header
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colSurfaceContainerLow

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 6
                                spacing: 6

                                MaterialSymbol {
                                    text: projectDelegate.collapsed ? "chevron_right" : "expand_more"
                                    iconSize: 18
                                    color: Appearance.colors.colOnSurfaceVariant
                                }

                                StyledText {
                                    text: projectDelegate.modelData ? projectDelegate.modelData.name : ""
                                    font.weight: Font.DemiBold
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colPrimary
                                }

                                StyledText {
                                    text: projectDelegate.modelData ? ("(" + projectDelegate.modelData.runningCount + "/" + projectDelegate.modelData.totalCount + ")") : ""
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSurfaceVariant
                                }

                                Item { Layout.fillWidth: true }

                                // Stack Start/Stop
                                RippleButton {
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    radius: Appearance.rounding.circle
                                    color: "transparent"
                                    onClicked: {
                                        if (projectDelegate.modelData.allRunning) {
                                            Docker.stopProject(projectDelegate.modelData.name);
                                        } else {
                                            Docker.startProject(projectDelegate.modelData.name);
                                        }
                                    }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: (projectDelegate.modelData && projectDelegate.modelData.allRunning) ? "stop" : "play_arrow"
                                        iconSize: 16
                                        color: (projectDelegate.modelData && projectDelegate.modelData.allRunning) ? Appearance.colors.colError : Appearance.colors.colSuccess
                                    }
                                    StyledToolTip { text: (projectDelegate.modelData && projectDelegate.modelData.allRunning) ? "Stop stack" : "Start stack" }
                                }

                                RippleButton {
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    radius: Appearance.rounding.circle
                                    color: "transparent"
                                    onClicked: Docker.restartProject(projectDelegate.modelData.name)

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "restart_alt"
                                        iconSize: 16
                                        color: Appearance.colors.colOnSurfaceVariant
                                    }
                                    StyledToolTip { text: "Restart stack" }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.rightMargin: 60
                                onClicked: projectDelegate.collapsed = !projectDelegate.collapsed
                            }
                        }

                        // Stack Containers
                        ColumnLayout {
                            visible: !projectDelegate.collapsed
                            Layout.fillWidth: true
                            Layout.leftMargin: 8
                            spacing: 6

                            Repeater {
                                model: projectDelegate.visibleContainers
                                delegate: containerRowDelegate
                            }
                        }
                    }
                }

                // Standalone Containers
                Repeater {
                    model: Docker.standaloneContainers.filter(root.filterMatches)
                    delegate: containerRowDelegate
                }
            }
        }
    }

    Component {
        id: containerRowDelegate

        Rectangle {
            id: containerRow
            required property var modelData
            readonly property var containerData: modelData
            Layout.fillWidth: true
            implicitHeight: cardContent.implicitHeight + 14
            radius: Appearance.rounding.small
            color: (containerData && containerData.state === "running")
                ? Appearance.colors.colSurfaceContainer 
                : Appearance.colors.colSurfaceContainerLowest
            border.width: 1
            border.color: (containerData && containerData.health === "unhealthy")
                ? Appearance.colors.colError 
                : (containerData && containerData.state === "running" ? Appearance.colors.colLayer0Border : "transparent")

            ColumnLayout {
                id: cardContent
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // Top Line: Status + Name + Actions
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Status Indicator Dot
                    Rectangle {
                        implicitWidth: 10
                        implicitHeight: 10
                        radius: 5
                        color: {
                            if (!containerData) return Appearance.colors.colOutline;
                            if (containerData.health === "unhealthy") return Appearance.colors.colError;
                            if (containerData.state === "running") return Appearance.colors.colSuccess;
                            if (containerData.state === "restarting") return Appearance.colors.colWarning;
                            return Appearance.colors.colOutline;
                        }
                        StyledToolTip { text: (containerData && containerData.status) ? containerData.status : "" }
                    }

                    // Name and Image
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        StyledText {
                            text: (containerData && containerData.name) ? containerData.name : ""
                            font.weight: Font.Bold
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurface
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: (containerData && containerData.image) ? containerData.image : ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSurfaceVariant
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Actions: Start/Stop, Restart, Logs, Exec, Delete
                    RowLayout {
                        spacing: 2

                        // Play / Stop
                        RippleButton {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: Appearance.rounding.circle
                            color: Appearance.colors.colSurfaceContainerHigh
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
                                iconSize: 16
                                color: (containerData && containerData.state === "running") ? Appearance.colors.colError : Appearance.colors.colSuccess
                            }
                            StyledToolTip { text: (containerData && containerData.state === "running") ? "Stop container" : "Start container" }
                        }

                        // Restart
                        RippleButton {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: Appearance.rounding.circle
                            color: Appearance.colors.colSurfaceContainerHigh
                            onClicked: Docker.restartContainer(containerData.id)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "restart_alt"
                                iconSize: 16
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                            StyledToolTip { text: "Restart container" }
                        }

                        // Terminal Logs
                        RippleButton {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: Appearance.rounding.circle
                            color: Appearance.colors.colSurfaceContainerHigh
                            onClicked: Docker.openTerminalLogs(containerData.name)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "article"
                                iconSize: 16
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                            StyledToolTip { text: "View live logs in terminal" }
                        }

                        // Exec Shell
                        RippleButton {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: Appearance.rounding.circle
                            color: Appearance.colors.colSurfaceContainerHigh
                            onClicked: Docker.openTerminalExec(containerData.name)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "terminal"
                                iconSize: 16
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                            StyledToolTip { text: "Open terminal shell inside container" }
                        }

                        // Delete
                        RippleButton {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: Appearance.rounding.circle
                            color: Appearance.colors.colSurfaceContainerHigh
                            onClicked: Docker.removeContainer(containerData.id)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "delete"
                                iconSize: 16
                                color: Appearance.colors.colError
                            }
                            StyledToolTip { text: "Remove container" }
                        }
                    }
                }

                // Bottom Line: Live Stats (CPU / RAM) & Clickable Port Chips
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: containerData && (containerData.state === "running" || (containerData.ports && containerData.ports.length > 0))

                    // CPU & RAM stats
                    RowLayout {
                        visible: containerData && containerData.state === "running" && !!containerData.mem
                        spacing: 6

                        StyledText {
                            text: (containerData && containerData.cpu) ? ("CPU: " + containerData.cpu) : ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        StyledText {
                            text: (containerData && containerData.mem) ? ("RAM: " + containerData.mem) : ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Port Chips (Clickable to open localhost:PORT in browser)
                    RowLayout {
                        spacing: 4
                        Repeater {
                            model: (containerData && containerData.ports) ? containerData.ports : []

                            delegate: Rectangle {
                                required property var modelData
                                implicitHeight: 20
                                implicitWidth: portText.implicitWidth + 14
                                radius: Appearance.rounding.verysmall
                                color: Appearance.colors.colPrimaryContainer

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    MaterialSymbol {
                                        text: "public"
                                        iconSize: 12
                                        color: Appearance.colors.colOnPrimaryContainer
                                    }
                                    StyledText {
                                        id: portText
                                        text: ":" + modelData
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.Bold
                                        color: Appearance.colors.colOnPrimaryContainer
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Docker.openPortInBrowser(modelData)
                                }
                                StyledToolTip { text: "Open http://localhost:" + modelData + " in browser" }
                            }
                        }
                    }
                }
            }
        }
    }
}
