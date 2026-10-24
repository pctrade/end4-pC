import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool requestDockShow: false
    property var contextMenu: null
    // Owner of the shared hover state; the preview popup lives in DragApps.
    property var appListRoot: null
    property alias media: dockMedia
    readonly property var activeUnpinned: TaskbarApps.apps.filter(
        a => !a.pinned && a.appId !== "SEPARATOR" && a.toplevels.length > 0
    )
    readonly property bool hasActive: activeUnpinned.length > 0 || dockMedia.visible

    Layout.fillHeight: !DockStyle.vertical
    Layout.fillWidth: DockStyle.vertical
    implicitWidth: DockStyle.vertical ? parent.width : activeRow.implicitWidth
    implicitHeight: DockStyle.vertical ? activeRow.implicitHeight : parent.height

    Behavior on implicitWidth {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    Behavior on implicitHeight {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    GridLayout {
        id: activeRow
        anchors.fill: parent
        columns: DockStyle.vertical ? 1 : -1
        rowSpacing: DockStyle.activeSpacing + DockStyle.iconSpacing
        columnSpacing: DockStyle.activeSpacing + DockStyle.iconSpacing

        DockMedia {
            id: dockMedia
            visible: Config.options.dock.showMedia
            Layout.fillHeight: !DockStyle.vertical
            Layout.fillWidth: DockStyle.vertical
            Layout.topMargin: DockStyle.mTop(DockStyle.mediaInnerMargin, DockStyle.mediaOuterMargin)
            Layout.bottomMargin: DockStyle.mBottom(DockStyle.mediaInnerMargin, DockStyle.mediaOuterMargin)
            Layout.leftMargin: DockStyle.mLeft(DockStyle.mediaInnerMargin, DockStyle.mediaOuterMargin)
            Layout.rightMargin: DockStyle.mRight(DockStyle.mediaInnerMargin, DockStyle.mediaOuterMargin)
            buttonPadding: DockStyle.padding
        }

        Repeater {
            model: root.activeUnpinned
            delegate: DockAppButton {
                required property var modelData
                appToplevel: modelData
                Layout.topMargin: DockStyle.mTop(DockStyle.pinnedInnerMargin, 0)
                Layout.bottomMargin: DockStyle.mBottom(DockStyle.pinnedInnerMargin, 0)
                Layout.leftMargin: DockStyle.mLeft(DockStyle.pinnedInnerMargin, 0)
                Layout.rightMargin: DockStyle.mRight(DockStyle.pinnedInnerMargin, 0)
                appListRoot: root.appListRoot ?? appListBridge
                contextMenu: root.contextMenu
                innerInset: DockStyle.iconInset
                outerInset: DockStyle.iconInset
            }
        }
    }

    QtObject {
        id: appListBridge
        property Item lastHoveredButton: null
        property bool buttonHovered: false
    }
}
