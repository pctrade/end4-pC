import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string provider: "wallhaven"  // "wallhaven" | "unsplash"
    property string resolution: "1080p"
    property int columns: Config.options.wallpaperSelector.columns || 4
    property real previewCellAspectRatio: 4 / 3
    property var hoveredItem: null

    signal wallpaperSelected(string path)
    signal updateThumbnailsRequested()

    readonly property bool unsplashMissingKey:
        root.provider === "unsplash" &&
        (KeyringStorage.keyringData?.apiKeys?.unsplash ?? "").length === 0

    onProviderChanged:   { root.hoveredItem = null; _syncAndFetch() }
    onResolutionChanged: _syncAndFetch()

    function _syncAndFetch() {
        if (root.unsplashMissingKey) return;
        OnlineWallpapers.provider   = root.provider;
        OnlineWallpapers.resolution = root.resolution;
        OnlineWallpapers.fetch();
    }

    Component.onCompleted: _syncAndFetch()

    ListModel { id: wallpaperModel }

    Connections {
        target: OnlineWallpapers
        function onFetched() {
            wallpaperModel.clear();
            root.hoveredItem = null;
            for (const item of OnlineWallpapers.results) {
                wallpaperModel.append(item);
            }
        }
        function onFetchError(message) {
            console.log("[OnlineWallpaperGrid] Error:", message);
        }
    }

    // ─── Download proc ───
    Process {
        id: downloadProc
        property string filePath: ""
        property bool applyAfter: false

        stdout: SplitParser {
            onRead: data => console.log("[download]", data)
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                if (applyAfter) {
                    root.wallpaperSelected(filePath)
                }
                Wallpapers.setDirectory(Wallpapers.effectiveDirectory)
                Qt.callLater(() => root.updateThumbnailsRequested())
                Quickshell.execDetached(["notify-send",
                    applyAfter ? Translation.tr("Wallpaper applied") : Translation.tr("Download complete"),
                    filePath, "-a", "Shell"
                ]);
            } else {
                Quickshell.execDetached(["notify-send",
                    Translation.tr("Download failed"), filePath, "-a", "Shell"
                ]);
            }
        }
    }

    // ─── Request API key (Unsplash only) ───
    Item {
        anchors.fill: parent
        visible: root.unsplashMissingKey

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "key_off"
                iconSize: 48
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Unsplash API key not set")
                font.pixelSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Open the launcher and run:\n/unsplash YOUR_API_KEY")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.normal
                font.family: Appearance.font.family.mono
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Get your free key at unsplash.com/developers")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }

    // ─── Loading ───
    StyledIndeterminateProgressBar {
        visible: OnlineWallpapers.loading
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: 4
            rightMargin: 4
        }
    }

    // ─── Grid online ───
    Item {
        id: gridContainer
        anchors.fill: parent
        visible: !root.unsplashMissingKey

        // ─── Unsplash header ───
        Item {
            id: unsplashHeader
            visible: root.provider === "unsplash" 
            height: visible ? headerLayout.implicitHeight + 20 : 0
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                leftMargin: 16
                rightMargin: 16
                topMargin: 8
            }

            ColumnLayout {
                id: headerLayout
                anchors.fill: parent
                spacing: -6

                StyledText {
                    text: "F E A T U R E D"
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.letterSpacing: 4
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    text: root.hoveredItem?.title ?? ""
                    font.pixelSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 6
                    StyledText {
                        text: Translation.tr("by") + " • " + (root.hoveredItem?.author ?? "")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: "·"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                    StyledText {
                        text: root.hoveredItem
                            ? (root.hoveredItem.width + " × " + root.hoveredItem.height)
                            : ""
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: root.hoveredItem
                            ? "♥ " + root.hoveredItem.likes
                            : ""
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }

        // ─── Grid ───
        GridView {
            id: grid
            anchors {
                top: unsplashHeader.visible ? unsplashHeader.bottom : parent.top
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            visible: wallpaperModel.count > 0

            property int currentIndex: 0

            cellWidth: width / root.columns
            cellHeight: cellWidth / root.previewCellAspectRatio
            interactive: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: wallpaperModel

            delegate: Item {
                id: delegateItem
                required property var model
                required property int index

                width: grid.cellWidth
                height: grid.cellHeight

                Image {
                    id: thumb
                    anchors.fill: parent
                    anchors.margins: Appearance.sizes.wallpaperSelectorItemMargins
                    source: delegateItem.model.thumb
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: thumb.width
                            height: thumb.height
                            radius: Appearance.rounding.normal
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: (delegateItem.index === grid.currentIndex)
                            ? Qt.rgba(
                                Appearance.colors.colPrimary.r,
                                Appearance.colors.colPrimary.g,
                                Appearance.colors.colPrimary.b, 0.35)
                            : "transparent"
                        border.width: delegateItem.index === grid.currentIndex ? 2 : 0
                        border.color: Appearance.colors.colPrimary
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer2
                        visible: thumb.status !== Image.Ready
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "image"
                            iconSize: 32
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: {
                        grid.currentIndex = delegateItem.index
                        root.hoveredItem = delegateItem.model
                    }
                    onClicked: event => {
                        const url = delegateItem.model.full.toLowerCase();
                        const ext = url.includes(".png") ? "png" : url.includes(".webp") ? "webp" : "jpg";
                        const fileName = `${delegateItem.model.provider}-${delegateItem.model.id}.${ext}`;
                        const picturesPath = Directories.pictures.toString().replace("file://", "");
                        const fullPath = `${picturesPath}/Wallpapers/${fileName}`;
                        console.log("[download] starting:", fullPath, "from:", delegateItem.model.full)

                        downloadProc.filePath = fullPath;
                        downloadProc.applyAfter = event.button === Qt.LeftButton;
                        downloadProc.command = ["bash", "-c",
                            `mkdir -p '${picturesPath}/Wallpapers' && curl -L --silent '${delegateItem.model.full}' -o '${fullPath}'`
                        ];
                        downloadProc.running = true;
                    }
                }
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

        // ─── Empty state ───
        ColumnLayout {
            anchors.centerIn: parent
            visible: wallpaperModel.count === 0 && !OnlineWallpapers.loading
            spacing: 12

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "cloud_off"
                iconSize: 48
                color: Appearance.colors.colSubtext
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("No results — try fetching again")
                color: Appearance.colors.colSubtext
            }

            RippleButton {
                Layout.alignment: Qt.AlignHCenter
                implicitHeight: 36
                buttonRadius: height / 2
                colBackground: Appearance.colors.colSecondaryContainer
                onClicked: OnlineWallpapers.fetch()
                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialSymbol {
                        text: "refresh"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        text: Translation.tr("Retry")
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
            }
        }
    }
}
