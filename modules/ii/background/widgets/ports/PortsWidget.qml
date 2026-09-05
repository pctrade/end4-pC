import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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
    configEntryName: "ports"
    hoverEnabled: true

    readonly property real cardWidth: 276
    readonly property real cardHeight: 120
    readonly property real cardSpacing: 12

    implicitWidth: root.cardWidth * 2 + root.cardSpacing
    implicitHeight: root.cardHeight * 2 + root.cardSpacing

    property string mode: "list" // "list" | "presets"

    function toggleFlip() { flipAnim.start() }

    Item {
        id: cardWrapper
        anchors.fill: parent

        transform: Scale {
            id: flipScale
            origin.x: cardWrapper.width  / 2
            origin.y: cardWrapper.height / 2
            xScale: 1
        }

        SequentialAnimation {
            id: flipAnim
            NumberAnimation {
                target: flipScale; property: "xScale"
                to: 0; duration: 150; easing.type: Easing.InQuad
            }
            ScriptAction {
                script: root.mode = (root.mode === "list" ? "presets" : "list")
            }
            NumberAnimation {
                target: flipScale; property: "xScale"
                to: 1; duration: 150; easing.type: Easing.OutQuad
            }
        }

        StyledRectangularShadow {
            target: contentRect
            z: -2
        }

        Rectangle {
            id: contentRect
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding?.verylarge ?? 24

            // ==========================================
            // SIDE A: Live Ports List
            // ==========================================
            ColumnLayout {
                id: listPage
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8
                visible: root.mode === "list"

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialShapeWrappedMaterialSymbol {
                        shape: MaterialShape.Shape.Cookie6Sided
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                        text: "router"
                        iconSize: 18
                        fill: 1
                        padding: 6
                        implicitWidth: 34
                        implicitHeight: 34
                    }

                    ColumnLayout {
                        spacing: 0
                        StyledText {
                            text: "Ports & Services"
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        RowLayout {
                            spacing: 4
                            Rectangle {
                                implicitWidth: 6
                                implicitHeight: 6
                                radius: 3
                                color: "#22c55e"
                            }
                            StyledText {
                                text: `${Ports.portsList.filter(p => !p.isSystem).length} active dev ports`
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Refresh Button
                    Rectangle {
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: Appearance.rounding?.small ?? 8
                        color: refreshHover.hovered ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1

                        MaterialSymbol {
                            id: refreshIcon
                            anchors.centerIn: parent
                            text: "refresh"
                            iconSize: 16
                            color: Appearance.colors.colOnLayer1
                            RotationAnimation on rotation {
                                from: 0; to: 360; duration: 600
                                running: Ports.loading
                                loops: Animation.Infinite
                            }
                        }

                        MouseArea {
                            id: refreshHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Ports.refresh()
                        }
                    }

                    // Flip / Presets Button
                    Rectangle {
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: Appearance.rounding?.small ?? 8
                        color: flipHover.hovered ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "tune"
                            iconSize: 16
                            color: Appearance.colors.colOnLayer1
                        }

                        MouseArea {
                            id: flipHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleFlip()
                        }
                    }
                }

                // Port List
                ListView {
                    id: portListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    model: Ports.portsList

                    delegate: Rectangle {
                        id: portRow
                        required property var modelData
                        width: portListView.width
                        height: 38
                        radius: Appearance.rounding?.small ?? 10
                        color: Appearance.colors.colLayer1
                        border.width: 1
                        border.color: Appearance.colors.colLayer1Border

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 6
                            spacing: 8

                            // Port Chip
                            Rectangle {
                                implicitWidth: Math.max(54, portText.implicitWidth + 12)
                                implicitHeight: 24
                                radius: Appearance.rounding?.tiny ?? 6
                                color: {
                                    if (modelData.category === "web") return ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8)
                                    if (modelData.category === "database") return ColorUtils.transparentize(Appearance.colors.colTertiary, 0.8)
                                    if (modelData.category === "ai") return ColorUtils.transparentize(Appearance.m3colors.m3secondary, 0.8)
                                    return ColorUtils.transparentize(Appearance.colors.colSubtext, 0.85)
                                }

                                StyledText {
                                    id: portText
                                    anchors.centerIn: parent
                                    text: `:${modelData.port}`
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Bold
                                    color: {
                                        if (modelData.category === "web") return Appearance.colors.colPrimary
                                        if (modelData.category === "database") return Appearance.colors.colTertiary
                                        if (modelData.category === "ai") return Appearance.m3colors.m3secondary
                                        return Appearance.colors.colSubtext
                                    }
                                }
                            }

                            // Process name & binding
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.process || "Unknown process"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: `${modelData.ip} ${modelData.pid ? '• PID ' + modelData.pid : ''}`
                                    font.pixelSize: Appearance.font.pixelSize.tiny ?? 10
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                }
                            }

                            // Actions: Open in Browser
                            Rectangle {
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: 6
                                color: openHover.hovered ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8) : "transparent"
                                visible: modelData.category === "web" || modelData.port === 80 || modelData.port === 3000 || modelData.port === 5173 || modelData.port === 8080 || modelData.port === 8000

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "open_in_new"
                                    iconSize: 14
                                    color: openHover.hovered ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                }

                                MouseArea {
                                    id: openHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Ports.openBrowser(modelData.port)
                                }
                            }

                            // Copy URL
                            Rectangle {
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: 6
                                color: copyHover.hovered ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8) : "transparent"

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "content_copy"
                                    iconSize: 14
                                    color: copyHover.hovered ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                }

                                MouseArea {
                                    id: copyHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Ports.copyUrl(modelData.port)
                                }
                            }

                            // 1-Click Kill Port Action
                            Rectangle {
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: 6
                                color: killHover.hovered ? Appearance.m3colors.m3error : ColorUtils.transparentize(Appearance.m3colors.m3error, 0.85)

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: 14
                                    color: killHover.hovered ? Appearance.m3colors.m3onError : Appearance.m3colors.m3error
                                }

                                MouseArea {
                                    id: killHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Ports.killPort(modelData.port, modelData.pid, modelData.process)
                                }
                            }
                        }
                    }

                    // Empty state
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: portListView.count === 0

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "cloud_done"
                            iconSize: 32
                            color: Appearance.colors.colSubtext
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "No active dev ports"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }

            // ==========================================
            // SIDE B: Dev Presets & Port Cheatsheet
            // ==========================================
            ColumnLayout {
                id: presetsPage
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                visible: root.mode === "presets"

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialShapeWrappedMaterialSymbol {
                        shape: MaterialShape.Shape.Cookie6Sided
                        color: Appearance.colors.colSecondary
                        colSymbol: Appearance.colors.colOnSecondary
                        text: "bolt"
                        iconSize: 18
                        fill: 1
                        padding: 6
                        implicitWidth: 34
                        implicitHeight: 34
                    }

                    StyledText {
                        text: "Quick Dev Actions"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    Item { Layout.fillWidth: true }

                    // Back to list button
                    Rectangle {
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: Appearance.rounding?.small ?? 8
                        color: backHover.hovered ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "arrow_back"
                            iconSize: 16
                            color: Appearance.colors.colOnLayer1
                        }

                        MouseArea {
                            id: backHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleFlip()
                        }
                    }
                }

                // Preset Buttons
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: "Bulk Process Termination:"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Kill Node
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Appearance.rounding?.small ?? 8
                            color: nodeHover.hovered ? Appearance.m3colors.m3error : Appearance.colors.colLayer1
                            border.width: 1
                            border.color: nodeHover.hovered ? Appearance.m3colors.m3error : Appearance.colors.colLayer1Border

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialSymbol { text: "terminal"; iconSize: 14; color: nodeHover.hovered ? Appearance.m3colors.m3onError : Appearance.colors.colOnLayer1 }
                                StyledText { text: "Kill All Node"; font.pixelSize: Appearance.font.pixelSize.small; color: nodeHover.hovered ? Appearance.m3colors.m3onError : Appearance.colors.colOnLayer1 }
                            }

                            MouseArea {
                                id: nodeHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Ports.killAllByName("node")
                            }
                        }

                        // Kill Python
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Appearance.rounding?.small ?? 8
                            color: pyHover.hovered ? Appearance.m3colors.m3error : Appearance.colors.colLayer1
                            border.width: 1
                            border.color: pyHover.hovered ? Appearance.m3colors.m3error : Appearance.colors.colLayer1Border

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialSymbol { text: "code"; iconSize: 14; color: pyHover.hovered ? Appearance.m3colors.m3onError : Appearance.colors.colOnLayer1 }
                                StyledText { text: "Kill All Python"; font.pixelSize: Appearance.font.pixelSize.small; color: pyHover.hovered ? Appearance.m3colors.m3onError : Appearance.colors.colOnLayer1 }
                            }

                            MouseArea {
                                id: pyHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Ports.killAllByName("python")
                            }
                        }
                    }
                }

                // Port Cheatsheet Reference
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    StyledText {
                        text: "Common Backend Ports:"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding?.small ?? 8
                        color: Appearance.colors.colLayer1
                        border.width: 1
                        border.color: Appearance.colors.colLayer1Border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                StyledText { text: ":3000 / :5173"; font.weight: Font.Bold; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colPrimary }
                                Item { Layout.fillWidth: true }
                                StyledText { text: "Frontend / Vite / Next.js"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                StyledText { text: ":8000 / :8080"; font.weight: Font.Bold; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colTertiary }
                                Item { Layout.fillWidth: true }
                                StyledText { text: "FastAPI / Django / Spring"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                StyledText { text: ":5432 / :6379"; font.weight: Font.Bold; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.m3colors.m3secondary }
                                Item { Layout.fillWidth: true }
                                StyledText { text: "PostgreSQL / Redis Cache"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                StyledText { text: ":11434 / :27017"; font.weight: Font.Bold; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colPrimary }
                                Item { Layout.fillWidth: true }
                                StyledText { text: "Ollama AI / MongoDB"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                            }
                        }
                    }
                }
            }
        }
    }
}
