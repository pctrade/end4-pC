import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io

Item {
    id: root

    property int columns: 4
    property real previewCellAspectRatio: 4 / 3
    property bool useDarkMode: Appearance.m3colors.darkmode
    property bool loading: WallhavenSearch.fetching
    property bool downloading: false
    property string downloadingId: ""

    signal wallpaperApplied()

    onVisibleChanged: {
        if (visible && !WallhavenSearch.fetching && WallhavenSearch.currentResults.length === 0) {
            WallhavenSearch.browse(WallhavenSearch.sorting === "relevance" ? "toplist" : WallhavenSearch.sorting)
        }
    }

    readonly property var browseModes: [
        { label: Translation.tr("Top"), sort: "toplist" },
        { label: Translation.tr("Hot"), sort: "hot" },
        { label: Translation.tr("Latest"), sort: "date_added" },
        { label: Translation.tr("Random"), sort: "random" },
        { label: Translation.tr("Views"), sort: "views" }
    ]

    function moveGridSelection(delta) { wallhavenGrid.moveSelection(delta) }
    function activateGridCurrent() { wallhavenGrid.activateCurrent() }
    function moveSelection(delta) { moveGridSelection(delta) }
    function activateCurrent() { activateGridCurrent() }

    function downloadAndApply(wallpaper) {
        if (downloading) return
        downloading = true
        downloadingId = wallpaper.id || ""
        WallhavenSearch.downloadWallpaper(wallpaper, function(success, localPath) {
            downloading = false
            downloadingId = ""
            if (success && localPath) {
                Wallpapers.apply(localPath, root.useDarkMode)
                root.wallpaperApplied()
            }
        })
    }

    function downloadOnly(wallpaper) {
        if (downloading) return
        downloading = true
        downloadingId = wallpaper.id || ""
        WallhavenSearch.downloadWallpaper(wallpaper, function(success, localPath) {
            downloading = false
            downloadingId = ""
        })
    }

    property bool showSettings: false

    function toggleSettings() {
        if (root.showSettings) {
            if (settingsPopupLoader.item) settingsPopupLoader.item.dismiss()
        } else {
            root.showSettings = true
        }
    }

    Loader {
        id: settingsPopupLoader
        anchors.fill: parent
        z: 100
        active: root.showSettings
        onLoaded: {
            item.show = true
            item.forceActiveFocus()
        }
        sourceComponent: WallhavenSettingsPopup {
            id: settingsPopup
            onDismiss: {
                root.showSettings = false
                if (settingsPopup.dirty) {
                    WallhavenSearch.saveToConfig()
                    WallhavenSearch.search(WallhavenSearch.currentQuery, 1)
                }
            }
        }
    }

    Item {
        anchors.fill: parent

        // Loading indicator
        ColumnLayout {
            anchors.centerIn: parent
            visible: root.loading && wallhavenGrid.count === 0
            spacing: 12

            MaterialLoadingIndicator {
                Layout.alignment: Qt.AlignHCenter
                colBg: Appearance.colors.colPrimary
            }
            StyledText {
                text: Translation.tr("Searching Wallhaven...")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Error state
        ColumnLayout {
            anchors.centerIn: parent
            visible: WallhavenSearch.lastError.length > 0 && !root.loading
            spacing: 12

            MaterialSymbol {
                text: "error"
                iconSize: 48
                color: Appearance.m3colors.m3error
                Layout.alignment: Qt.AlignHCenter
            }
            StyledText {
                text: WallhavenSearch.lastError
                color: Appearance.colors.colOnLayer0
                font.pixelSize: Appearance.font.pixelSize.small
                Layout.alignment: Qt.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.maximumWidth: root.width * 0.8
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // Empty state (search returned nothing)
        ColumnLayout {
            anchors.centerIn: parent
            visible: !root.loading && WallhavenSearch.lastError.length === 0 && WallhavenSearch.currentResults.length === 0 && WallhavenSearch.currentQuery.length > 0
            spacing: 12

            MaterialSymbol {
                text: "image_not_supported"
                iconSize: 48
                color: Appearance.colors.colSubtext
                Layout.alignment: Qt.AlignHCenter
            }
            StyledText {
                text: Translation.tr("No results found")
                color: Appearance.colors.colOnLayer0
                font.pixelSize: Appearance.font.pixelSize.small
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Initial empty state (no search yet)
        ColumnLayout {
            anchors.centerIn: parent
            visible: !root.loading && WallhavenSearch.lastError.length === 0 && WallhavenSearch.currentResults.length === 0 && WallhavenSearch.currentQuery.length === 0
            spacing: 12

            MaterialSymbol {
                text: "travel_explore"
                iconSize: 48
                color: Appearance.colors.colSubtext
                Layout.alignment: Qt.AlignHCenter
            }
            StyledText {
                text: Translation.tr("Search, or just browse:")
                color: Appearance.colors.colOnLayer0
                font.pixelSize: Appearance.font.pixelSize.small
                Layout.alignment: Qt.AlignHCenter
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                Repeater {
                    model: root.browseModes
                    delegate: RippleButton {
                        required property var modelData
                        implicitHeight: 34
                        leftPadding: 16
                        rightPadding: 16
                        buttonRadius: height / 2
                        colBackground: Appearance.colors.colLayer1
                        onClicked: WallhavenSearch.browse(modelData.sort)
                        contentItem: StyledText {
                            text: modelData.label
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }

        // Grid
        GridView {
            id: wallhavenGrid
            anchors.fill: parent
            visible: WallhavenSearch.currentResults.length > 0
            focus: true

            property int columns: root.columns
            property int currentSelection: -1
            property string pendingSelectionAfterPageChange: ""

            cellWidth: width / root.columns
            cellHeight: cellWidth / root.previewCellAspectRatio
            interactive: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: StyledScrollBar {}

            function moveSelection(delta) {
                if (wallhavenGrid.count === 0) return
                var newIndex = currentSelection + delta

                if (newIndex >= wallhavenGrid.count) {
                    if (!root.loading && WallhavenSearch.currentPage < WallhavenSearch.lastPage) {
                        pendingSelectionAfterPageChange = "first"
                        WallhavenSearch.nextPage()
                    }
                    return
                }
                if (newIndex < 0) {
                    if (!root.loading && WallhavenSearch.currentPage > 1) {
                        pendingSelectionAfterPageChange = "last"
                        WallhavenSearch.previousPage()
                    }
                    return
                }

                currentSelection = newIndex
                positionViewAtIndex(currentSelection, GridView.Contain)
            }

            function activateCurrent() {
                if (currentSelection >= 0 && currentSelection < wallhavenGrid.count) {
                    var wallpaper = WallhavenSearch.currentResults[currentSelection]
                    if (wallpaper) root.downloadAndApply(wallpaper)
                }
            }

            Connections {
                target: WallhavenSearch
                function onSearchCompleted() {
                    if (wallhavenGrid.pendingSelectionAfterPageChange === "first") {
                        wallhavenGrid.currentSelection = 0
                        wallhavenGrid.positionViewAtBeginning()
                    } else if (wallhavenGrid.pendingSelectionAfterPageChange === "last") {
                        wallhavenGrid.currentSelection = wallhavenGrid.count - 1
                        wallhavenGrid.positionViewAtEnd()
                    }
                    wallhavenGrid.pendingSelectionAfterPageChange = ""
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Left) { moveSelection(-1); event.accepted = true }
                else if (event.key === Qt.Key_Right) { moveSelection(1); event.accepted = true }
                else if (event.key === Qt.Key_Up) { moveSelection(-columns); event.accepted = true }
                else if (event.key === Qt.Key_Down) { moveSelection(columns); event.accepted = true }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { activateCurrent(); event.accepted = true }
            }

            model: WallhavenSearch.currentResults

            delegate: Item {
                id: delegateItem
                required property var modelData
                required property int index

                width: wallhavenGrid.cellWidth
                height: wallhavenGrid.cellHeight

                property string thumbnailUrl: modelData ? WallhavenSearch.getThumbnailUrl(modelData, "large") : ""
                property string wallpaperId: modelData?.id ?? ""
                property bool isDownloading: root.downloading && root.downloadingId === wallpaperId

                Image {
                    id: thumb
                    anchors.fill: parent
                    anchors.margins: Appearance.sizes.wallpaperSelectorItemMargins
                    source: delegateItem.thumbnailUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: wallhavenGrid.cellWidth
                    sourceSize.height: wallhavenGrid.cellHeight

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
                        color: delegateItem.index === wallhavenGrid.currentSelection
                            ? Qt.rgba(
                                Appearance.colors.colPrimary.r,
                                Appearance.colors.colPrimary.g,
                                Appearance.colors.colPrimary.b, 0.15)
                            : "transparent"
                        border.width: delegateItem.index === wallhavenGrid.currentSelection ? 2 : 0
                        border.color: Appearance.colors.colPrimary
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer2
                        visible: thumb.status !== Image.Ready
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: thumb.status === Image.Error ? "broken_image" : "image"
                            iconSize: 32
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Appearance.sizes.wallpaperSelectorItemMargins
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colScrim
                    visible: delegateItem.isDownloading

                    MaterialLoadingIndicator {
                        anchors.centerIn: parent
                        colBg: Appearance.colors.colOnPrimary
                    }
                }

                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        margins: Appearance.sizes.wallpaperSelectorItemMargins + 4
                    }
                    visible: delegateItem.modelData?.resolution ? true : false
                    color: Appearance.colors.colScrim
                    radius: Appearance.rounding.small
                    implicitWidth: resolutionText.implicitWidth + 8
                    implicitHeight: resolutionText.implicitHeight + 4

                    StyledText {
                        id: resolutionText
                        anchors.centerIn: parent
                        text: delegateItem.modelData?.resolution ?? ""
                        font.pixelSize: Appearance.font.pixelSize.smaller * 0.85
                        color: "white"
                    }
                }

                MouseArea {
                    id: thumbMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: {
                        wallhavenGrid.currentSelection = delegateItem.index
                        wallhavenGrid.forceActiveFocus()
                    }
                    onExited: {
                        if (wallhavenGrid.currentSelection === delegateItem.index)
                            wallhavenGrid.currentSelection = -1
                    }
                    onClicked: event => {
                        wallhavenGrid.currentSelection = delegateItem.index
                        if (event.button === Qt.LeftButton)
                            root.downloadAndApply(delegateItem.modelData)
                    }
                }

                RowLayout {
                    id: hoverActions
                    anchors {
                        bottom: thumb.bottom
                        right: thumb.right
                        margins: 6
                    }
                    z: 10
                    spacing: 4
                    opacity: delegateItem.index === wallhavenGrid.currentSelection && thumbMouse.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: "transparent"

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "download"
                            iconSize: 15
                            color: Appearance.colors.colOnLayer0
                        }

                        MouseArea {
                            id: downloadMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.downloadOnly(delegateItem.modelData)

                            StyledToolTip {
                                visible: downloadMouseArea.containsMouse
                                text: Translation.tr("Download")
                            }
                        }
                    }

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: "transparent"

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "wallpaper"
                            iconSize: 15
                            color: Appearance.colors.colOnLayer0
                        }

                        MouseArea {
                            id: applyMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.downloadAndApply(delegateItem.modelData)

                            StyledToolTip {
                                visible: applyMouseArea.containsMouse
                                text: Translation.tr("Download and Set as Wallpaper")
                            }
                        }
                    }
                }
            }

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: wallhavenGrid.width
                    height: wallhavenGrid.height
                    radius: Appearance.rounding.normal
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Appearance.colors.colScrim
            visible: root.loading && wallhavenGrid.count > 0
            radius: Appearance.rounding.normal

            MaterialLoadingIndicator {
                anchors.centerIn: parent
                colBg: Appearance.colors.colPrimary
            }
        }
    }
}
