import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common
import qs.services
import qs.modules.common.models
import qs.modules.common.functions

Item {
    id: root
    visible: false

    property var player: MprisController.activePlayer
    readonly property bool playing: player?.playbackState === MprisPlaybackState.Playing
    readonly property string artUrl: player?.trackArtUrl ?? ""
    readonly property string artFilePath: `${Directories.coverArt}/${Qt.md5(artUrl)}`
    property bool downloaded: false
    readonly property string downloadedArtFilePath: downloaded ? Qt.resolvedUrl(artFilePath) : ""
    readonly property string trackKey: `${player?.uniqueId ?? ""}|${player?.trackTitle ?? ""}|${player?.trackArtist ?? ""}`

    property string displayedArtFilePath: ""
    property real displayedArtWidth: 0
    property string displayedTrackKey: ""

    function considerArt(path, width) {
        if (root.trackKey === root.displayedTrackKey && root.displayedArtFilePath !== "" && width < root.displayedArtWidth * 0.8)
            return;
        root.displayedArtFilePath = path;
        root.displayedArtWidth = width;
        root.displayedTrackKey = root.trackKey;
    }

    onTrackKeyChanged: {
        if (root.trackKey === root.displayedTrackKey) return;
        root.displayedArtFilePath = "";
        root.displayedArtWidth = 0;
    }

    Image {
        id: artProbe
        visible: false
        asynchronous: true
        cache: false
        source: root.downloadedArtFilePath
        onStatusChanged: {
            if (status === Image.Ready && implicitWidth > 0)
                root.considerArt(source.toString(), implicitWidth);
        }
    }

    readonly property color artDominantColor: ColorUtils.mix(
        quantizer.colors[0] ?? Appearance.colors.colPrimary,
        Appearance.colors.colPrimaryContainer,
        0.8
    )
    property QtObject blendedColors: AdaptedMaterialScheme {
        color: root.artDominantColor
    }

    function refreshArt() {
        if (!root.artUrl || root.artUrl.length === 0) {
            root.downloaded = false;
            return;
        }
        if (downloader.running) {
            downloader.rerun = true;
            return;
        }
        downloader.targetFile = root.artUrl;
        downloader.filePath = root.artFilePath;
        root.downloaded = false;
        downloader.running = true;
    }

    onArtFilePathChanged: refreshArt()
    Component.onCompleted: refreshArt()

    Timer {
        running: root.playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    Process {
        id: downloader
        property string targetFile: ""
        property string filePath: ""
        property bool rerun: false
        command: ["bash", "-c", `[ -s '${filePath}' ] || { curl -sSLf -m 20 '${targetFile}' -o '${filePath}.part' && mv -f '${filePath}.part' '${filePath}'; rm -f '${filePath}.part'; }; [ -s '${filePath}' ]`]
        onExited: (code, status) => {
            if (rerun || filePath !== root.artFilePath) {
                rerun = false;
                root.refreshArt();
                return;
            }
            root.downloaded = code === 0;
        }
    }

    ColorQuantizer {
        id: quantizer
        source: root.displayedArtFilePath
        depth: 0
        rescaleSize: 1
    }
}
