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
    configEntryName: "notes"
    hoverEnabled: true

    implicitWidth: 276
    implicitHeight: 252

    property string mode: "list" // "list" | "edit"
    property var pendingNoteId: null
    property string editingText: ""
    onModeChanged: GlobalStates.desktopWidgetKeyboardFocus = (mode === "edit")

    function toggleFlip() { cardWrapper.flip() }

    function openNewNote() {
        root.pendingNoteId = null
        root.editingText = ""
        toggleFlip()
    }

    function openNote(note) {
        root.pendingNoteId = note.id
        root.editingText = note.content
        toggleFlip()
    }

    function saveAndBack() {
        if (root.editingText.length > 0) {
            if (root.pendingNoteId) {
                Notes.updateNote(root.pendingNoteId, root.editingText)
            } else {
                Notes.addNote(root.editingText)
            }
        }
        toggleFlip()
    }

    FlipCard {
        id: cardWrapper
        anchors.fill: parent
        onFlipped: root.mode = (root.mode === "list" ? "edit" : "list")

        WidgetCard {
            id: contentRect
            anchors.fill: parent
            widget: root

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
                        text: "Notes"
                    }
                    Item { Layout.fillWidth: true }

                    ToolbarPairedFab {
                        Layout.rightMargin: 4
                        Layout.alignment: Qt.AlignVCenter
                        baseSize: 38
                        iconText: "add"
                        onClicked: root.openNewNote()
                    }
                }

                StyledListView {
                    id: notesListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: Notes.list

                    delegate: SwipeDelegate {
                        id: noteCard
                        required property var modelData
                        required property int index

                        width: notesListView.width
                        implicitHeight: 55
                        padding: 0
                        background: null
                        clip: true

                        property color bg: {
                            const cyclePos = index % 3
                            if (cyclePos === 0) return Appearance.colors.colPrimary
                            if (cyclePos === 1) return Appearance.colors.colSecondary
                            return Appearance.colors.colTertiary
                        }
                        property color fg: {
                            const cyclePos = index % 3
                            if (cyclePos === 0) return Appearance.colors.colOnPrimary
                            if (cyclePos === 1) return Appearance.colors.colOnSecondary
                            return Appearance.colors.colOnTertiary
                        }

                        onClicked: root.openNote(noteCard.modelData)

                        contentItem: Rectangle {
                            radius: Appearance.rounding.normal
                            color: noteCard.bg
                            width: parent.width - Math.abs(noteCard.swipe.position) * 6

                            StyledText {
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 12; rightMargin: 12
                                }
                                color: noteCard.fg
                                text: noteCard.modelData.content
                                elide: Text.ElideRight
                                maximumLineCount: 1
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

                            SwipeDelegate.onClicked: Notes.deleteNote(noteCard.modelData.id)
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
                        ContextMenu.menu: StyledTextEditMenu { editor: editTextArea }
                        anchors.fill: parent
                        anchors.margins: 8
                        text: root.editingText
                        wrapMode: TextArea.Wrap
                        placeholderText: "Type your note..."
                        color: Appearance.colors.colOnLayer0
                        background: null
                        onTextChanged: root.editingText = text
                    }
                }
            }
        }
    }
}