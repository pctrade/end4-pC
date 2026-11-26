import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.services

Menu {
    id: root

    required property Item editor

    readonly property bool hasSelection: root.editor.selectedText.length > 0
    readonly property bool editable: !root.editor.readOnly
    readonly property bool copyable: root.hasSelection && (root.editor.echoMode ?? TextInput.Normal) === TextInput.Normal

    padding: 6
    topPadding: 6
    bottomPadding: 6

    transformOrigin: Item.TopLeft

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "scale"
                from: 0.6
                to: 1
                duration: 500
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.animationCurves.expressiveEffectsDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveEffects
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "scale"
                to: 0.85
                duration: 160
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
            }
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: 140
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
            }
        }
    }

    background: Rectangle {
        implicitWidth: 190
        radius: Appearance.rounding.small + 4
        color: Appearance.colors.colUiPopupBackground
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
    }

    component Entry: MenuItem {
        id: entry

        property string iconName: ""

        implicitHeight: 38
        leftPadding: 12
        rightPadding: 12

        background: Rectangle {
            radius: Appearance.rounding.small
            color: entry.highlighted && entry.enabled ? Appearance.colors.colLayer1Hover : "transparent"
        }

        contentItem: RowLayout {
            spacing: 12
            opacity: entry.enabled ? 1 : 0.38

            MaterialSymbol {
                text: entry.iconName
                iconSize: 20
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: entry.text
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                elide: Text.ElideRight
            }
        }
    }

    component Divider: MenuSeparator {
        topPadding: 4
        bottomPadding: 4
        contentItem: Rectangle {
            implicitHeight: 1
            color: Appearance.colors.colOutlineVariant
        }
    }

    Entry {
        text: Translation.tr("Undo")
        iconName: "undo"
        enabled: root.editable && root.editor.canUndo
        onTriggered: root.editor.undo()
    }
    Entry {
        text: Translation.tr("Redo")
        iconName: "redo"
        enabled: root.editable && root.editor.canRedo
        onTriggered: root.editor.redo()
    }

    Divider {}

    Entry {
        text: Translation.tr("Cut")
        iconName: "content_cut"
        enabled: root.editable && root.copyable
        onTriggered: root.editor.cut()
    }
    Entry {
        text: Translation.tr("Copy")
        iconName: "content_copy"
        enabled: root.copyable
        onTriggered: root.editor.copy()
    }
    Entry {
        text: Translation.tr("Paste")
        iconName: "content_paste"
        enabled: root.editable && root.editor.canPaste
        onTriggered: root.editor.paste()
    }
    Entry {
        text: Translation.tr("Delete")
        iconName: "delete"
        enabled: root.editable && root.hasSelection
        onTriggered: root.editor.remove(root.editor.selectionStart, root.editor.selectionEnd)
    }

    Divider {}

    Entry {
        text: Translation.tr("Select All")
        iconName: "select_all"
        enabled: root.editor.length > 0
        onTriggered: root.editor.selectAll()
    }
}
