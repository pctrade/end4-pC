import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    required property Item pager
    property int staggerMs: 45
    property int selectedIndex: 0
    property string target: "desktop"
    DashboardSettingsCatalog {
        id: catalog
    }

    function randomWallpaper() {
        if (paths.length === 0) return;
        const candidates = paths.filter(p => p !== desktopPath);
        const pool = candidates.length > 0 ? candidates : paths;
        const path = pool[Math.floor(Math.random() * pool.length)];
        selectedIndex = Math.max(0, paths.indexOf(path));
        grid.positionViewAtIndex(selectedIndex, GridView.Contain);
        applyTo(path);
    }

    readonly property string query: pager.searchQuery ?? ""
    readonly property var paths: Wallpapers.wallpapers.filter(p => Images.isValidImageByName(p))
    readonly property string desktopPath: FileUtils.trimFileProtocol(Config.options.background.wallpaperPath ?? "")
    readonly property string lockPath: FileUtils.trimFileProtocol(Config.options.background.lockWall ?? "")
    readonly property bool synced: lockPath === ""
    readonly property int columns: Math.max(2, Math.round(width / 270))

    function applyDesktop(path) {
        if (synced) Config.options.background.lockWall = desktopPath;
        Wallpapers.apply(path);
    }

    function applyLock(path) {
        Config.options.background.lockWall = path;
    }

    function applyBoth(path) {
        Config.options.background.lockWall = "";
        Wallpapers.apply(path);
    }

    function applyTo(path) {
        if (synced) applyBoth(path);
        else if (target === "lock") applyLock(path);
        else applyDesktop(path);
    }

    function activate() {
        const path = paths[selectedIndex];
        if (path) applyTo(path);
    }

    function activateLock() {
        const path = paths[selectedIndex];
        if (path && !synced) applyLock(path);
    }

    function setSynced(value) {
        Config.options.background.lockWall = value ? "" : desktopPath;
    }

    function moveSelection(dx, dy) {
        const next = selectedIndex + dx + dy * columns;
        if (next < 0 || next >= paths.length) return;
        selectedIndex = next;
        grid.positionViewAtIndex(next, GridView.Contain);
    }

    readonly property int tileWidth: Math.max(1, Math.floor(width / columns) - 12)
    readonly property int tileHeight: Math.max(1, Math.round(Math.floor(width / columns) * 0.76) - 12)

    property bool ready: false

    function generateThumbnails() {
        const size = Images.thumbnailSizeNameForDimensions(tileWidth, tileHeight);
        const key = Wallpapers.effectiveDirectory + "|" + size;
        if (pager.thumbsRequested[key]) return;
        pager.thumbsRequested[key] = true;
        Wallpapers.generateThumbnail(size);
    }

    Timer {
        interval: 60
        running: true
        onTriggered: root.ready = true
    }

    Timer {
        id: thumbTimer
        interval: 700
        running: true
        onTriggered: root.generateThumbnails()
    }

    Component.onCompleted: Wallpapers.load()

    Connections {
        target: Wallpapers
        function onDirectoryChanged() { thumbTimer.restart() }
    }
    Component.onDestruction: Wallpapers.searchQuery = ""

    Binding {
        target: Wallpapers
        property: "searchQuery"
        value: root.query
    }

    onPathsChanged: selectedIndex = Math.min(selectedIndex, Math.max(0, paths.length - 1))

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 290
            Layout.minimumHeight: 290
            Layout.maximumHeight: 290
            spacing: 12

            DashboardWallpaperPreviewCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 5
                Layout.fillHeight: true
                desktopPath: root.desktopPath
                lockPath: root.synced ? root.desktopPath : root.lockPath
                synced: root.synced
                target: root.target
                onTargetSelected: value => root.target = value
                onSyncToggled: value => root.setSynced(value)
                pager: root.pager
                staggerMs: root.staggerMs
                animIndex: 0
                travelX: -200
                travelY: 0
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 6
                Layout.fillHeight: true
                columns: 2
                rowSpacing: 12
                columnSpacing: 12

                DashboardWallpaperToolsCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 1
                    title: Translation.tr("Wallpaper tools")
                    pager: root.pager
                    staggerMs: root.staggerMs
                    animIndex: 1
                    travelX: 0
                    travelY: -120
                    onRandomRequested: root.randomWallpaper()
                    onFoldersRequested: GlobalStates.wallpaperSelectorOpen = true
                }

                DashboardSpinCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 1
                    controlKey: "desktop:Wallpaper change interval (min)"
                    title: Translation.tr("Change every (min)")
                    icon: "timer"
                    tileShape: MaterialShape.Shape.Gem
                    pager: root.pager
                    staggerMs: root.staggerMs
                    animIndex: 2
                    travelX: 0
                    travelY: -120
                }

                DashboardComboCard {
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    Layout.fillHeight: true
                    Layout.preferredHeight: 1
                    controlKey: "desktop:Transitions"
                    override: catalog.controlFor("desktop:Transitions")
                    title: Translation.tr("Transition")
                    icon: "animation"
                    tileShape: MaterialShape.Shape.Puffy
                    pager: root.pager
                    staggerMs: root.staggerMs
                    animIndex: 3
                    travelX: 200
                    travelY: 0
                }
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: Math.floor(width / root.columns)
            cellHeight: Math.round(cellWidth * 0.76)
            model: root.ready ? root.paths : []
            cacheBuffer: 0

            delegate: Item {
                id: cell
                required property int index
                required property string modelData

                readonly property bool selected: root.selectedIndex === index
                readonly property bool isDesktop: modelData === root.desktopPath
                readonly property bool isLock: root.synced ? isDesktop : modelData === root.lockPath

                width: grid.cellWidth
                height: grid.cellHeight

                DashboardCard {
                    id: tile
                    anchors.fill: parent
                    anchors.margins: 6
                    tint: Appearance.colors.colLayer1
                    pager: root.pager
                    staggerMs: root.staggerMs
                    animIndex: cell.index % 8
                    travelX: 0
                    travelY: 80

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: tile.cardRadius
                        color: "transparent"

                        ThumbnailImage {
                            id: thumb
                            anchors.fill: parent
                            generateThumbnail: false
                            sourcePath: cell.modelData
                            cache: false
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: root.tileWidth
                            sourceSize.height: root.tileHeight

                            Connections {
                                target: Wallpapers

                                function onThumbnailGenerated(directory) {
                                    if (thumb.status !== Image.Error) return;
                                    thumb.source = "";
                                    thumb.source = thumb.thumbnailPath;
                                }

                                function onThumbnailGeneratedFile(filePath) {
                                    if (thumb.status !== Image.Error) return;
                                    if (Qt.resolvedUrl(thumb.sourcePath) !== Qt.resolvedUrl(filePath)) return;
                                    thumb.source = "";
                                    thumb.source = thumb.thumbnailPath;
                                }
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: parent.height * 0.55
                            opacity: hover.containsMouse || cell.selected ? 1 : 0
                            gradient: Gradient {
                                GradientStop { position: 0; color: "transparent" }
                                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.75) }
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 8
                            spacing: 6

                            Repeater {
                                model: [
                                    { icon: "desktop_windows", on: cell.isDesktop },
                                    { icon: "lock", on: cell.isLock }
                                ]

                                delegate: Rectangle {
                                    required property var modelData

                                    visible: modelData.on
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: Appearance.colors.colPrimary

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        iconSize: 18
                                        fill: 1
                                        color: Appearance.colors.colOnPrimary
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedIndex = cell.index;
                                root.pager.forceActiveFocus();
                                root.applyTo(cell.modelData);
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: tile.cardRadius
                        color: "transparent"
                        border.width: cell.selected ? 3 : 0
                        border.color: Appearance.colors.colPrimary
                    }
                }
            }
        }
    }
}
