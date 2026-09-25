import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// A finished download, with what you would do next: open it, find it, keep it in the drawer, unpack it
RowLayout {
    id: done
    required property Item di
    anchors {
        fill: parent
        leftMargin: 6
        rightMargin: 10
    }
    spacing: 8

    readonly property var payload: IslandEvents.downloadDone.payload ?? ({})
    readonly property string path: done.payload.path ?? ""
    readonly property string name: done.payload.name ?? ""
    readonly property bool archive: done.payload.archive ?? false

    component Action: Rectangle {
        id: action
        property string icon
        property var onTap: null
        implicitWidth: 26
        implicitHeight: 26
        radius: 13
        color: actionMouse.containsMouse ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)

        Behavior on color {
            ColorAnimation { duration: IslandMotion.micro }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: action.icon
            iconSize: 15
            fill: 1
            color: actionMouse.containsMouse ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (action.onTap) action.onTap()
        }
    }

    // The file itself can be pulled straight out of the island into a chat or a folder
    Item {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 26
        implicitHeight: 26

        MaterialShapeWrappedMaterialSymbol {
            id: doneMark
            anchors.centerIn: parent
            wrappedShape: MaterialShape.Shape.Cookie9Sided
            color: ColorUtils.transparentize(IslandEvents.colorSuccess, 0.75)
            colSymbol: IslandEvents.colorSuccess
            text: dragArea.drag.active ? "drag_pan" : "download_done"
            iconSize: 14
            fill: 1
            padding: 5

            Drag.active: dragArea.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": `file://${done.path}` })

            Binding {
                target: done.di
                property: "dragging"
                value: true
                when: dragArea.drag.active
                restoreMode: Binding.RestoreValue
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            cursorShape: Qt.OpenHandCursor
            drag.target: doneMark
            onReleased: doneMark.Drag.drop()
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: -3

        StyledText {
            Layout.fillWidth: true
            text: done.name
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            text: `${Translation.tr("Downloaded")} · ${IslandEvents.formatBytes(done.payload.bytes ?? 0, false)}`
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideRight
        }
    }

    Action {
        icon: "open_in_new"
        onTap: () => {
            IslandEvents.openDownload(done.path)
            IslandEvents.downloadDone.dismiss()
        }
    }
    Action {
        icon: "folder_open"
        onTap: () => {
            IslandEvents.revealDownload(done.path)
            IslandEvents.downloadDone.dismiss()
        }
    }
    Action {
        icon: "folder_zip"
        visible: done.archive
        onTap: () => {
            IslandEvents.extractDownload(done.path)
            IslandEvents.downloadDone.dismiss()
        }
    }
    Action {
        icon: "inventory_2"
        onTap: () => {
            DropShelf.addItems([`file://${done.path}`])
            IslandEvents.downloadDone.dismiss()
        }
    }
}
