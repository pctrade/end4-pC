import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: xshot
    required property Item di
    spacing: 10
    implicitWidth: 360
    readonly property real wantedWidth: 360

    readonly property var payload: IslandEvents.screenshot.payload ?? ({})
    readonly property string path: xshot.payload.path ?? ""

    component ActionButton: Rectangle {
        id: action
        property string icon
        property string label
        property var onTap
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 17
        color: actionMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

        RowLayout {
            anchors.centerIn: parent
            spacing: 5
            MaterialSymbol {
                text: action.icon
                iconSize: 16
                fill: 1
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                text: action.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.onTap()
        }
    }

    Rectangle {
        id: preview
        Layout.fillWidth: true
        Layout.preferredHeight: 190
        radius: 14
        color: Appearance.colors.colLayer1
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: preview.width
                height: preview.height
                radius: preview.radius
            }
        }

        Image {
            id: shotImage
            anchors.fill: parent
            source: xshot.path ? `file://${xshot.path}` : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 720
            asynchronous: true
            cache: false

            Drag.active: dragArea.drag.active

            Binding {
                target: xshot.di
                property: "dragging"
                value: true
                when: dragArea.drag.active
                restoreMode: Binding.RestoreValue
            }
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": `file://${xshot.path}` })
        }

        Rectangle {
            anchors {
                left: parent.left
                bottom: parent.bottom
                margins: 8
            }
            implicitWidth: dragHint.implicitWidth + 16
            implicitHeight: 22
            radius: 11
            color: Qt.rgba(0, 0, 0, 0.55)
            StyledText {
                id: dragHint
                anchors.centerIn: parent
                text: Translation.tr("Drag to share")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: "white"
            }
        }

        Item { id: dragProxy }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: dragProxy
            onReleased: dragProxy.x = dragProxy.y = 0
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        ActionButton {
            icon: "edit"
            label: Translation.tr("Edit")
            onTap: () => {
                Quickshell.execDetached(["swappy", "-f", xshot.path])
                xshot.di.collapse()
            }
        }
        ActionButton {
            icon: "content_copy"
            label: Translation.tr("Copy")
            onTap: () => Quickshell.execDetached(["bash", "-c", `wl-copy < '${xshot.path}'`])
        }
        ActionButton {
            icon: "folder_open"
            label: Translation.tr("Folder")
            onTap: () => {
                Quickshell.execDetached(["xdg-open", xshot.path.substring(0, xshot.path.lastIndexOf("/"))])
                xshot.di.collapse()
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        ActionButton {
            icon: "document_scanner"
            label: Translation.tr("Copy text")
            onTap: () => IslandEvents.ocrImage(xshot.path)
        }
        ActionButton {
            icon: "image_search"
            label: "Google Lens"
            onTap: () => IslandEvents.lensSearch(xshot.path)
        }
        ActionButton {
            icon: "inventory_2"
            label: Translation.tr("Drawer")
            onTap: () => DropShelf.addItems([`file://${xshot.path}`])
        }
    }
}
