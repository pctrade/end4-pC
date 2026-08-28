import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "todo"
    hoverEnabled: true

    readonly property real cardWidth: 276
    readonly property real cardHeight: 120
    readonly property real cardSpacing: 12

    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight * 2 + root.cardSpacing

    property string mode: "list" // "list" | "edit"
    property string editingText: ""
    onModeChanged: GlobalStates.desktopWidgetKeyboardFocus = (mode === "edit")

    function toggleFlip() { flipAnim.start() }

    function openNewTask() {
        root.editingText = ""
        toggleFlip()
    }

    function saveAndBack() {
        if (root.editingText.trim().length > 0) {
            Todo.addTask(root.editingText.trim())
        }
        toggleFlip()
    }

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
                script: root.mode = (root.mode === "list" ? "edit" : "list")
            }
            NumberAnimation {
                target: flipScale; property: "xScale"
                to: 1; duration: 150; easing.type: Easing.OutQuad
            }
        }

        StyledDropShadow { target: contentRect }

        Rectangle {
            id: contentRect
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding?.verylarge ?? 30

            // List
            ColumnLayout {
                id: listPage
                anchors { fill: parent; margins: 12 }
                spacing: 10
                visible: root.mode === "list"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        Layout.topMargin: -4
                        Layout.leftMargin: 8
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimaryContainer
                        text: "To-Do"
                    }
                    Item { Layout.fillWidth: true }

                    ToolbarPairedFab {
                        Layout.rightMargin: 4
                        Layout.alignment: Qt.AlignVCenter
                        baseSize: 38
                        iconText: "add"
                        onClicked: root.openNewTask()
                    }
                }

                StyledListView {
                    id: todoListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: Todo.list

                    delegate: SwipeDelegate {
                        id: taskCard
                        required property var modelData
                        required property int index

                        width: todoListView.width
                        implicitHeight: 55
                        padding: 0
                        background: null
                        clip: true

                        property color bg: {
                            const cyclePos = index % 3
                            if (cyclePos === 0) return Appearance.colors.colTertiary
                            if (cyclePos === 1) return Appearance.colors.colSecondary
                            return Appearance.colors.colPrimary
                        }
                        property color fg: {
                            const cyclePos = index % 3
                            if (cyclePos === 0) return Appearance.colors.colOnTertiary
                            if (cyclePos === 1) return Appearance.colors.colOnSecondary
                            return Appearance.colors.colOnPrimary
                        }

                        contentItem: Rectangle {
                            radius: Appearance.rounding.normal
                            color: taskCard.bg
                            width: parent.width - Math.abs(taskCard.swipe.position) * 6
                            opacity: taskCard.modelData.done ? 0.6 : 1

                            RowLayout {
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 4; rightMargin: 12
                                }
                                spacing: 4

                                Rectangle {
                                    Layout.leftMargin: 8
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    radius: Appearance.rounding.full
                                    color: taskCard.modelData.done
                                        ? ColorUtils.transparentize(taskCard.fg, 0.8)
                                        : "transparent"
                                    border.width: 2
                                    border.color: taskCard.fg

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        visible: taskCard.modelData.done
                                        text: "check"
                                        iconSize: Appearance.font.pixelSize.normal
                                        color: taskCard.fg
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (taskCard.modelData.done)
                                                Todo.markUnfinished(taskCard.index)
                                            else
                                                Todo.markDone(taskCard.index)
                                        }
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    color: taskCard.fg
                                    text: taskCard.modelData.content
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    font.strikeout: taskCard.modelData.done
                                }
                            }
                        }

                        swipe.right: Rectangle {
                            width: 64
                            anchors.right: parent.right
                            height: parent.height
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colError

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "delete"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnError
                            }

                            SwipeDelegate.onClicked: Todo.deleteItem(taskCard.index)
                        }
                    }
                }
            }

            // Edit
            ColumnLayout {
                id: editPage
                anchors { fill: parent; margins: 12 }
                spacing: 10
                visible: root.mode === "edit"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Rectangle {
                        radius: Appearance.rounding.full
                        color: "transparent"
                        implicitWidth: 28; implicitHeight: 28
                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: Appearance.font.pixelSize.normal
                            text: "arrow_back"
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleFlip()
                        }
                    }
                    Item { Layout.fillWidth: true }

                    ToolbarPairedFab {
                        Layout.rightMargin: 4
                        Layout.alignment: Qt.AlignVCenter
                        baseSize: 38
                        iconText: "save"
                        onClicked: root.saveAndBack()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerLow

                    TextArea {
                        id: editTextArea
                        anchors.fill: parent
                        anchors.margins: 8
                        text: root.editingText
                        wrapMode: TextArea.Wrap
                        placeholderText: "Type your task..."
                        color: Appearance.colors.colOnLayer0
                        background: null
                        onTextChanged: root.editingText = text
                    }
                }
            }
        }
    }
}