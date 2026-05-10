import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io


Item {
    id: root

    signal wallpaperSelected(string path)
    property real cellWidth: grid.cellWidth
    property real cellHeight: grid.cellHeight

    function moveSelection(delta) { grid.moveSelection(delta) }
    function activateCurrent() { grid.activateCurrent() }

    property int columns: Config.options.wallpaperSelector.columns || 4
    property real previewCellAspectRatio: 4 / 3

    Process {
        id: deleteProc
        property string filePath: ""
        function deleteFile(path) {
            filePath = path;
            command = ["gio", "trash", path];
            running = true;
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) console.log("Error deleting file:", filePath);
        }
    }

    // ─── Context menu ───
    Item {
        id: contextMenu
        visible: false
        z: 3

        property string targetPath: ""
        property real targetX: 0
        property real targetY: 0
        property real targetWidth: grid.cellWidth
        property real targetHeight: grid.cellHeight

        x: targetX
        y: targetY
        width: targetWidth
        height: targetHeight

        Rectangle {
            anchors.fill: parent
            anchors.margins: 8
            color: Qt.rgba(0, 0, 0, 0.45)
            radius: Appearance.rounding.normal
        }
        Row {
            anchors.centerIn: parent
            spacing: 12
            RippleButton {
                implicitWidth: 36; implicitHeight: 36
                buttonRadius: height / 2
                colBackground: Appearance.colors.colPrimaryContainer
                onClicked: contextMenu.visible = false
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colPrimary
                }
            }
            RippleButton {
                implicitWidth: 36; implicitHeight: 36
                buttonRadius: height / 2
                colBackground: Appearance.colors.colErrorContainer
                onClicked: {
                    contextMenu.visible = false
                    deleteProc.deleteFile(contextMenu.targetPath)
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "check"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colPrimary
                }
            }
        }
    }

    // ─── Progress bars ───
    StyledIndeterminateProgressBar {
        id: indeterminateProgressBar
        visible: Wallpapers.thumbnailGenerationRunning && value == 0
        anchors {
            bottom: grid.top
            left: parent.left
            right: parent.right
            leftMargin: 4
            rightMargin: 4
        }
    }

    StyledProgressBar {
        visible: Wallpapers.thumbnailGenerationRunning && value > 0
        value: Wallpapers.thumbnailGenerationProgress
        anchors.fill: indeterminateProgressBar
    }

    // ─── Grid ───
    GridView {
        id: grid
        anchors.fill: parent
        visible: Wallpapers.folderModel.count > 0

        readonly property int columns: root.columns
        readonly property int rows: Math.max(1, Math.ceil(count / columns))
        property int currentIndex: 0

        cellWidth: width / root.columns
        cellHeight: cellWidth / root.previewCellAspectRatio
        interactive: true
        clip: true
        keyNavigationWraps: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: StyledScrollBar {}

        function moveSelection(delta) {
            currentIndex = Math.max(0, Math.min(grid.model.count - 1, currentIndex + delta));
            positionViewAtIndex(currentIndex, GridView.Contain);
        }

        function activateCurrent() {
            const filePath = grid.model.get(currentIndex, "filePath");
            root.wallpaperSelected(filePath);
        }

        model: Wallpapers.folderModel
        onModelChanged: currentIndex = 0

        delegate: WallpaperDirectoryItem {
            required property var modelData
            required property int index
            fileModelData: modelData
            width: grid.cellWidth
            height: grid.cellHeight
            colBackground: (index === grid?.currentIndex || containsMouse)
                ? Appearance.colors.colPrimary
                : (fileModelData.filePath === Config.options.background.wallpaperPath)
                    ? Appearance.colors.colSecondaryContainer
                    : ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
            colText: (index === grid.currentIndex || containsMouse)
                ? Appearance.colors.colOnPrimary
                : (fileModelData.filePath === Config.options.background.wallpaperPath)
                    ? Appearance.colors.colOnSecondaryContainer
                    : Appearance.colors.colOnLayer0

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                z: 2
                onClicked: event => {
                    if (event.button === Qt.RightButton) {
                        var pos = mapToItem(contextMenu.parent, 0, 0)
                        contextMenu.targetX = pos.x
                        contextMenu.targetY = pos.y
                        contextMenu.targetPath = modelData.filePath
                        contextMenu.visible = true
                    }
                }
            }

            onEntered: grid.currentIndex = index
            onActivated: root.wallpaperSelected(fileModelData.filePath)
        }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: grid.width
                height: grid.height
                radius: Appearance.rounding.screenRounding + 5
            }
        }
    }
}
