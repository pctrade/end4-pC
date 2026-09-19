import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

/*
 * Free text on the desktop. Double-click to edit, drag the corner handle to resize.
 */
AbstractBackgroundWidget {
    id: root
    configEntryName: "customText"
    hoverEnabled: true
    needsColText: root.configEntry.color === ""

    readonly property real minFontSize: 12
    readonly property real maxFontSize: 400
    readonly property real padding: 16

    property real fontSize: root.configEntry.fontSize
    property bool editing: false

    readonly property color textColor: root.configEntry.color === "" ? root.colText : Appearance.getColorFromName(root.configEntry.color)

    implicitWidth: Math.max(editor.implicitWidth, editor.length === 0 ? placeholder.implicitWidth : 0) + root.padding * 2
    implicitHeight: editor.implicitHeight + root.padding * 2
    draggable: placementStrategy === "free" && !Config.options.background.widgetsLocked && !root.editing

    onEditingChanged: GlobalStates.desktopWidgetKeyboardFocus = root.editing
    Component.onDestruction: if (root.editing) GlobalStates.desktopWidgetKeyboardFocus = false

    onDoubleClicked: (mouse) => {
        if (mouse.button === Qt.LeftButton && !root.editing) root.startEditing();
    }

    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) root.finishEditing(true);
        }
    }

    function startEditing() {
        editor.text = root.configEntry.content;
        root.editing = true;
        editor.cursorPosition = editor.length;
        editor.forceActiveFocus();
    }

    function finishEditing(save) {
        if (!root.editing) return;
        if (save) root.configEntry.content = editor.text;
        editor.text = Qt.binding(() => root.configEntry.content);
        root.editing = false;
    }

    // Resizing scales the font by how much the widget box is stretched
    property real resizeStartFontSize: -1
    property real resizeStartHeight: 0

    function resizeBy(dx, dy, startWidth) {
        if (root.resizeStartFontSize < 0) {
            root.resizeStartFontSize = root.fontSize;
            root.resizeStartHeight = root.height;
        }
        const factor = Math.max((startWidth + dx) / startWidth, (root.resizeStartHeight + dy) / root.resizeStartHeight);
        root.fontSize = Math.round(Math.min(Math.max(root.resizeStartFontSize * factor, root.minFontSize), root.maxFontSize));
    }

    function commitFontSize() {
        if (root.resizeStartFontSize < 0) return;
        root.resizeStartFontSize = -1;
        root.configEntry.fontSize = root.fontSize;
        root.fontSize = Qt.binding(() => root.configEntry.fontSize);
    }

    TextEdit {
        id: editor
        anchors.centerIn: parent
        enabled: root.editing
        text: root.configEntry.content
        textFormat: TextEdit.PlainText
        selectByMouse: true
        color: root.textColor
        selectionColor: Appearance.colors.colPrimary
        selectedTextColor: Appearance.colors.colOnPrimary
        horizontalAlignment: ({ left: TextEdit.AlignLeft, right: TextEdit.AlignRight })[root.configEntry.alignment] ?? TextEdit.AlignHCenter
        font {
            family: root.configEntry.fontFamily
            pixelSize: root.fontSize
        }

        layer.enabled: root.configEntry.shadow
        layer.effect: DropShadow {
            radius: 8
            samples: radius * 2 + 1
            verticalOffset: 2
            color: Appearance.colors.colShadow
            transparentBorder: true
        }

        Keys.onEscapePressed: root.finishEditing(false)
        Keys.onReturnPressed: (event) => {
            if (event.modifiers & Qt.ControlModifier) root.finishEditing(true);
            else event.accepted = false;
        }
        Keys.onEnterPressed: (event) => {
            if (event.modifiers & Qt.ControlModifier) root.finishEditing(true);
            else event.accepted = false;
        }
    }

    Text {
        id: placeholder
        anchors.centerIn: parent
        visible: editor.length === 0
        text: Translation.tr("Your text")
        color: root.textColor
        opacity: 0.5
        font: editor.font
    }

    Rectangle {
        anchors.fill: parent
        visible: root.editing
        color: "transparent"
        radius: Appearance.rounding.normal
        border.width: 2
        border.color: Appearance.colors.colPrimary
    }

    RowLayout {
        visible: root.editing
        anchors {
            top: parent.bottom
            topMargin: 8
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 8

        Toolbar {
            StyledText {
                Layout.leftMargin: 12
                Layout.rightMargin: 4
                text: Translation.tr("Ctrl+Enter to save · Esc to cancel")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
            IconToolbarButton {
                text: "close"
                onClicked: root.finishEditing(false)
            }
        }

        ToolbarPairedFab {
            iconText: "check"
            onClicked: root.finishEditing(true)
        }
    }

    ResizeHandler {
        anchorItem: root
        hoverActive: root.containsMouse
        locked: Config.options.background.widgetsLocked || root.editing
        currentWidth: root.width
        resizeMode: "diagonal"
        strokeCol: root.textColor
        onResizedXY: (dx, dy, startWidth) => root.resizeBy(dx, dy, startWidth)
        onResizeFinished: root.commitFontSize()
    }
}
