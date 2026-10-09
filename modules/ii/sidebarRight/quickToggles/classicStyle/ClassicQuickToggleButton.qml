import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.models.quickToggles
import qs.modules.common.widgets
import qs.services

GroupButton {
    id: root

    required property string buttonType
    property var toggleModel: null
    property bool editMode: false
    property bool isUnused: false
    property bool isDragPlaceholder: false
    property bool isDraggingThis: false

    signal removeRequested()
    signal addRequested()
    signal openMenu()
    signal dragStarted(string bType, bool unused, point scenePos)
    signal dragMoved(point scenePos)
    signal dragEnded(point scenePos)

    property string buttonIcon: toggleModel?.icon ?? "close"
    toggled: !editMode && (toggleModel?.toggled ?? false)
    enabled: editMode || (toggleModel?.available ?? true)

    // Keep size completely fixed to prevent pushing adjacent icons into next line
    bounce: false
    baseWidth: 40
    baseHeight: 40
    clickedWidth: 40
    clickedHeight: 40
    enableImplicitWidthAnimation: false
    enableImplicitHeightAnimation: false

    buttonRadius: Appearance?.rounding?.normal ?? 17
    buttonRadiusPressed: Appearance?.rounding?.small ?? 12

    opacity: isDragPlaceholder ? 0.25 : (isUnused ? 0.6 : 1.0)
    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    mouseArea.cursorShape: isDraggingThis ? Qt.ClosedHandCursor : (editMode ? Qt.OpenHandCursor : Qt.PointingHandCursor)

    DragHandler {
        id: dragHandler
        enabled: root.editMode
        acceptedButtons: Qt.LeftButton
        dragThreshold: 8
        grabPermissions: PointerHandler.CanTakeOverFromAnything

        onActiveChanged: {
            root.isDraggingThis = active;
            if (active) {
                root.dragStarted(root.buttonType, root.isUnused, dragHandler.centroid.scenePosition);
            } else {
                root.dragEnded(dragHandler.centroid.scenePosition);
            }
        }

        onCentroidChanged: {
            if (active) {
                root.dragMoved(dragHandler.centroid.scenePosition);
            }
        }
    }

    onClicked: {
        if (editMode) {
            if (isUnused) {
                root.addRequested();
            } else {
                root.removeRequested();
            }
            return;
        }
        if (toggleModel?.mainAction) {
            toggleModel.mainAction();
        }
    }

    altAction: {
        if (editMode) return null;
        if (toggleModel?.hasMenu) {
            return () => root.openMenu();
        }
        return toggleModel?.altAction ?? null;
    }

    contentItem: Item {
        anchors.fill: parent
        scale: root.down ? 0.88 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: 22
            fill: root.toggled ? 1 : 0
            color: root.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.buttonIcon

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }

    // Delete badge in edit mode (for active toggles)
    Rectangle {
        id: deleteBadge
        visible: root.editMode && !root.isUnused && !root.isDragPlaceholder
        z: 10
        width: 18
        height: 18
        radius: 9
        color: deleteHover.containsMouse ? Appearance.colors.colError : ColorUtils.transparentize(Appearance.colors.colError, 0.2)
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: -4
        anchors.leftMargin: -4

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "close"
            iconSize: 12
            color: Appearance.colors.colOnError
        }

        MouseArea {
            id: deleteHover
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.removeRequested();
            }
        }
    }

    // Add badge in edit mode (for unused toggles)
    Rectangle {
        id: addBadge
        visible: root.editMode && root.isUnused && !root.isDragPlaceholder
        z: 10
        width: 18
        height: 18
        radius: 9
        color: Appearance.colors.colPrimary
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -4
        anchors.rightMargin: -4

        MaterialSymbol {
            anchors.centerIn: parent
            text: "add"
            iconSize: 12
            color: Appearance.colors.colOnPrimary
        }
    }

    StyledToolTip {
        text: root.editMode
            ? (root.isUnused ? Translation.tr("Click to add %1").arg(root.toggleModel?.name ?? root.buttonType) : Translation.tr("Click to remove %1").arg(root.toggleModel?.name ?? root.buttonType))
            : (root.toggleModel?.tooltipText || root.toggleModel?.name || "")
    }
}
