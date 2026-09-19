pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

// Standalone popup, opened only via the "equalizer" button inside the media
// popup's controls (PlayerControls.qml / PlayerControlsLyrics.qml) - there is
// no separate bar icon for it. Sized on its own terms - nothing here
// references Appearance.sizes.mediaControlsWidth.
//
// Visually styled like Player.qml's media card (blurred now-playing art, cava
// wave visualizer, border) since that's the "look" being matched, even though
// this popup isn't tied to any one player/track - it just reflects whatever
// MprisController.activePlayer currently is, same as the bar's media widget.
//
// Uses the same Loader-active pattern as modules/ii/mediaControls/MediaControls.qml:
// the PanelWindow is created/destroyed by the Loader in step with
// GlobalStates.equalizerOpen, so the popup's entrance/exit is whatever native
// map/unmap animation the compositor (Hyprland) already plays for every other
// quickshell layer-shell surface - the same "pop" you see opening media -
// rather than a hand-rolled QML slide.
Scope {
    id: root

    readonly property real popupWidth: 820
    readonly property real popupHeight: 600
    readonly property real popupRounding: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

    // No standalone "equalizer" bar entry anymore - it only opens via the
    // button inside the media popup, so position it the same way the media
    // popup itself is positioned (wherever "media" sits in the bar layout).
    readonly property string equalizerPosition: {
        if (Config.options.bar.layouts.leftLayout.includes("media")) return "left"
        if (Config.options.bar.layouts.middleLayout.includes("media")) return "center"
        if (Config.options.bar.layouts.rightLayout.includes("media")) return "right"
        return "center"
    }

    readonly property bool barVertical: Config.options.bar.vertical
    readonly property string barEdge: {
        if (!barVertical) return Config.options.bar.bottom ? "bottom" : "top"
        return Config.options.bar.bottom ? "right" : "left"
    }
    readonly property real gap: Config.options.bar.cornerStyle === 3 ? Appearance.sizes.hyprlandGapsOut : 0
    readonly property bool cornerStyleReducesGap: Config.options.bar.cornerStyle === 1 || Config.options.bar.cornerStyle === 2
    readonly property real barThickness: barVertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight

    // Now-playing art, purely decorative here (same download-cache approach
    // Player.qml uses) - if nothing is playing this just stays blank and the
    // card falls back to a plain tinted background.
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property var artUrl: activePlayer?.trackArtUrl ?? ""
    readonly property string artFilePath: `${Directories.coverArt}/${Qt.md5(root.artUrl)}`

    // Only updated once the *new* track's art has actually finished
    // downloading - never blanked out in between. Blanking it the instant
    // the track changed (before the new file existed) meant blurredArt AND
    // colorQuantizer.source both went empty for a moment, which reset the
    // quantized color to the plain matugen fallback (colPrimary) - a visible
    // flash to the wrong color on every track change instead of a clean
    // swap once the new art was ready. Keeping the old one showing the
    // whole time avoids that flash entirely.
    property string displayedArtFilePath: ""

    // ColorQuantizer needs an actual local file it can decode - it can't read
    // a remote https:// MPRIS art URL, which most players hand back. Pointing
    // it at root.displayedArtFilePath (the *visible* art, shown immediately
    // for the no-flash behavior above) meant it sat on an unreadable remote
    // URL forever, since coverArtDownloader.onExited never told it a local
    // copy was ready - colors[0] silently stayed empty and artDominantColor
    // permanently fell back to plain matugen colPrimary. This tracks the
    // last known-local file separately: swaps immediately for file:// art,
    // otherwise keeps the previous track's local copy showing until the new
    // one finishes downloading, so the quantizer is never pointed at
    // something it can't read.
    property string colorSourceFilePath: ""

    function syncArt() {
        if (!root.artUrl || root.artUrl.length === 0) {
            root.displayedArtFilePath = ""
            root.colorSourceFilePath = ""
            return
        }
        // Show the new art immediately. StyledImage/Image and ColorQuantizer
        // can consume the MPRIS art URL directly, so there is no blank/fallback
        // frame while the cache copy is being downloaded. The downloader then
        // stores the same art locally for subsequent use.
        root.displayedArtFilePath = root.artUrl
        if (root.artUrl.startsWith("file://")) {
            root.colorSourceFilePath = root.artUrl
            return
        }
        coverArtDownloader.targetFile = root.artUrl
        coverArtDownloader.targetPath = root.artFilePath
        coverArtDownloader.running = true
    }
    readonly property color artDominantColor: ColorUtils.mix(
        (colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary),
        Appearance.colors.colPrimaryContainer,
        0.8) || Appearance.m3colors.m3secondaryContainer
    readonly property QtObject blendedColors: AdaptedMaterialScheme {
        color: root.artDominantColor
    }

    // Component.onCompleted covers the track that's already playing when this
    // Scope is first created - onArtFilePathChanged alone misses it, since
    // QML doesn't fire onXChanged for a property's initial value, only for
    // later changes.
    Component.onCompleted: root.syncArt()
    onArtFilePathChanged: root.syncArt()

    Process {
        id: coverArtDownloader
        property string targetFile: root.artUrl
        property string targetPath: root.artFilePath
        command: ["bash", "-c", `[ -f ${targetPath} ] || curl -4 -sSL '${targetFile}' -o '${targetPath}'`]
        // Keep the visible art on the live MPRIS URL for the current frame -
        // do not replace it on download completion, since that can make the
        // background briefly wait on a local-file reload and can race when
        // tracks change quickly. The color source is different: it only ever
        // points at local files, so swapping it here is safe and is what
        // actually lets ColorQuantizer read the art at all.
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) root.colorSourceFilePath = Qt.resolvedUrl(root.artFilePath)
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.colorSourceFilePath
        depth: 0
        rescaleSize: 1
    }

    Loader {
        id: equalizerLoader
        active: GlobalStates.equalizerOpen

        sourceComponent: PanelWindow {
            id: panelWindow
            visible: true

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            implicitWidth: root.popupWidth
            implicitHeight: root.popupHeight
            color: "transparent"
            WlrLayershell.namespace: "quickshell:equalizer"
            // Layer-shell surfaces don't get keyboard input by default (they're
            // built for click-through overlays). This popup now has a text
            // field (custom preset naming), which needs the surface to
            // actually be grantable keyboard focus - OnDemand means it only
            // takes focus when something inside (like that TextInput) asks
            // for it, so it doesn't steal focus from the rest of the desktop
            // the rest of the time.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            anchors {
                top: true
                left: true
            }
            margins {
                top: {
                    if (root.barEdge === "top") return root.barThickness + (root.cornerStyleReducesGap ? -root.gap - 6 : root.gap)
                    if (root.barEdge === "bottom") return panelWindow.screen.height - root.barThickness - (root.cornerStyleReducesGap ? -root.gap : root.gap) - root.popupHeight
                    if (root.equalizerPosition === "left") return 0
                    if (root.equalizerPosition === "right") return panelWindow.screen.height - root.popupHeight - root.gap
                    return (panelWindow.screen.height - root.popupHeight) / 2
                }
                left: {
                    if (root.barEdge === "left") return root.barThickness + (root.cornerStyleReducesGap ? -root.gap : root.gap)
                    if (root.barEdge === "right") return panelWindow.screen.width - root.barThickness - (root.cornerStyleReducesGap ? -root.gap : root.gap) - root.popupWidth
                    if (root.equalizerPosition === "left") return 0
                    if (root.equalizerPosition === "right") return panelWindow.screen.width - root.popupWidth - root.gap
                    return (panelWindow.screen.width - root.popupWidth) / 2
                }
            }

            mask: Region {
                item: cardBackground
            }

            Component.onCompleted: GlobalFocusGrab.addDismissable(panelWindow)
            Component.onDestruction: GlobalFocusGrab.removeDismissable(panelWindow)
            Connections {
                target: GlobalFocusGrab
                function onDismissed() { GlobalStates.equalizerOpen = false }
            }

            StyledRectangularShadow {
                target: cardBackground
            }

            Rectangle {
                id: cardBackground
                anchors.fill: parent
                anchors.margins: Appearance.sizes.elevationMargin
                radius: root.popupRounding
                color: ColorUtils.applyAlpha(root.blendedColors.colLayer0, 1)
                border.width: 2
                border.color: Qt.rgba(0, 0, 0, 0.55)

                // root.blendedColors settles onto new album art in place (see
                // EqualizerView's colorSignature fix for the same issue on the
                // curve graph) - without this, the whole card would hard-snap
                // to the new tint the instant it resolves instead of easing
                // into it the way the rest of the popup now does.
                Behavior on color {
                    ColorAnimation { duration: 420; easing.type: Easing.OutCubic }
                }

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: cardBackground.width
                        height: cardBackground.height
                        radius: cardBackground.radius
                    }
                }

                Image {
                    id: blurredArt
                    anchors.fill: parent
                    source: root.displayedArtFilePath
                    sourceSize.width: cardBackground.width
                    sourceSize.height: cardBackground.height
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    antialiasing: true
                    asynchronous: true
                    visible: root.displayedArtFilePath.length > 0
                    // Fades in once the async load actually finishes, rather
                    // than popping straight to a fully-loaded frame the
                    // instant `visible` flips true.
                    opacity: blurredArt.status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                    }

                    layer.enabled: true
                    layer.effect: StyledBlurEffect {
                        source: blurredArt
                    }

                    Rectangle {
                        // Neutral dark scrim, no color tint - keeps the blurred
                        // art readable without recoloring it pink/whatever from
                        // matugen's blend. Buttons/sliders elsewhere still use
                        // root.blendedColors (album-tinted) as before.
                        //
                        // Alpha is user-controlled via eqView.dimAmount (the
                        // slider next to Auto in the header, persisted to
                        // eq_state.json) instead of a fixed 0.3 -
                        // bright/high-contrast covers could otherwise
                        // flash-bang the user on open with no way to tone
                        // it down.
                        anchors.fill: parent
                        color: ColorUtils.transparentize(Appearance.colors.colScrim, eqView.dimAmount)

                        Behavior on color {
                            ColorAnimation { duration: 420; easing.type: Easing.OutCubic }
                        }
                    }
                }

                WaveVisualizer {
                    anchors.fill: parent
                    live: root.activePlayer?.isPlaying ?? false
                    points: GlobalStates.visualizerPoints
                    maxVisualizerValue: 1000
                    smoothing: 2
                    color: root.blendedColors.colPrimary

                    Behavior on color {
                        ColorAnimation { duration: 420; easing.type: Easing.OutCubic }
                    }
                }

                EqualizerView {
                    id: eqView
                    anchors.fill: parent
                    blendedColors: root.blendedColors
                    player: root.activePlayer
                    displayedArtFilePath: root.displayedArtFilePath
                    onCloseRequested: GlobalStates.equalizerOpen = false
                }
            }
        }
    }
}
