pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The root is a WidgetsLoader so that BOTH the depth wallpaper delegates and
// the widget FadeLoaders become children of THIS item — true siblings in one
// stacking context. A widget's z (depthLayerPosition - 0.5) can therefore sit
// between two wallpaper layers; had WidgetsLoader stayed a nested child, Qt
// would have painted the whole widget block on top of (or under) everything.
WidgetsLoader {
    id: root
    anchors.fill: parent

    required property var monitor

    // ✅ The "background" layer is a fully user-configurable layer like any
    // other — its image comes from the layer config, never from the wallpaper.
    // `isPrimary` guards the "Apply wallpaper" path so the depth composition
    // + Matugen run happens exactly once even on multi-monitor setups (the
    // original ran it per screen, racing two switchwall processes against
    // each other on the same config/kitty files).
    readonly property bool isPrimary: root.screen === (Quickshell.screens ?? [])[0]

    readonly property real screenWidth: root.screen.width
    readonly property real screenHeight: root.screen.height

    property real mouseX: root.screenWidth / 2
    property real mouseY: root.screenHeight / 2

    readonly property real headroomX: root.screenWidth * 0.03
    readonly property real headroomY: root.screenHeight * 0.03

    readonly property int activeWorkspaceId: WM.activeWorkspaceForMonitor(root.monitor?.name)?.id ?? 1

    onActiveWorkspaceIdChanged: {
        console.log("[DepthEffect] workspace ->", root.activeWorkspaceId);
    }

    property var depthLayers: []
    property int depthLayersVersion: 0

    function refreshDepthLayers() {
        const layers = root.getConfigSortedLayers();
        root.depthLayers = layers;
        root.depthLayersVersion++;
        console.log("[DepthEffect] refreshDepthLayers:", layers.map(l => `${l.name}:sc=${l.scale}`).join(","), "version:", root.depthLayersVersion);
    }

    Component.onCompleted: {
        console.log("[DepthEffect] monitor:", root.monitor?.name ?? "null",
                    "screen:", root.screenWidth, "x", root.screenHeight,
                    "workspace:", root.activeWorkspaceId,
                    "layers:", root.getConfigSortedLayers().length);
        Qt.callLater(() => {
            root.refreshDepthLayers();
            if (Config.ready) root.refreshDepthLayers();
        });
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) root.refreshDepthLayers();
        }
    }

    Connections {
        target: Config.options.background.depthEffect
        function onLayersChanged() {
            root.refreshDepthLayers();
            // Layer edits while depth is on re-theme from the new
            // composition (debounced, primary only). Gated on Config.ready
            // so the initial config load never triggers a boot compose.
            if (Config.ready && Config.options.background.depthEffect.enable) root.scheduleDepthAutoCompose();
        }
        function onEnableChanged() {
            // Explicit user toggle only: startup assignments happen before
            // Config.ready, and only the primary screen drives the single
            // compose/apply/restore run on multi-monitor setups.
            if (!Config.ready || !root.isPrimary) return;
            if (Config.options.background.depthEffect.enable) {
                root.preserveNormalWallpaper();
                root.refreshDepthLayers();
                // Enable depth: ensure matugen regenerates from the depth
                // composition. If there's already an existing composite,
                // re-theme from it immediately so the old simple-wallpaper
                // theme is never kept.
                if (GlobalStates.depthWallpaperCompositePath && layerCompositeProc.running === false) {
                    const existing = String(GlobalStates.depthWallpaperCompositePath);
                    if (existing && existing.length > 0) {
                        Wallpapers.apply(existing, Appearance.m3colors.darkmode, true);
                        root.setWallpaperPathSelf("file://" + existing);
                        MaterialThemeLoader.reapplyTheme();
                    }
                }
                root.scheduleDepthAutoCompose();
            } else {
                root.restoreNormalWallpaper();
            }
        }
    }

    // True while THIS effect writes wallpaperPath itself (compose/restore),
    // so the external-change watcher below ignores its own writes. QML
    // property signals fire synchronously, so no async round-trip can slip
    // through with the flag set.
    property bool _selfWallpaperWrite: false
    function setWallpaperPathSelf(path) {
        root._selfWallpaperWrite = true;
        Config.options.background.wallpaperPath = path;
        root._selfWallpaperWrite = false;
    }

    Connections {
        // Catches EVERY wallpaper change that bypasses Wallpapers.apply:
        // the external system picker, scripts, hand-edited config,
        // first-run defaults. The rule is absolute — any real wallpaper
        // change exits depth mode and shows the new wallpaper normally
        // (Matugen already themes it inside switchwall).
        // A self-write (setWallpaperPathSelf) and any path inside the depth
        // wallpaper cache (the compose flow) are ignored: they're our own
        // composite being applied, not a user wallpaper change.
        target: Config.options.background
        function onWallpaperPathChanged() {
            if (root._selfWallpaperWrite || !root.isPrimary) return;
            // switchwall.sh's set_wallpaper_path may store the path with or
            // without the file:// prefix — normalise both before matching the
            // depth cache dir.
            const p = String(Config.options.background.wallpaperPath || "").replace(/^file:\/\//, "");
            if (p.startsWith(String(Directories.depthWallpapers))) return;
            if (Config.options.background.depthEffect.enable) {
                GlobalStates.preDepthWallpaperPath = "";
                Config.options.background.depthEffect.enable = false;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 10000
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: Config.options.background.depthEffect.enable && Config.options.background.depthEffect.mouseParallax
        onPositionChanged: (event) => {
            root.mouseX = event.x;
            root.mouseY = event.y;
        }
    }

    // ✅ GLOBAL pointer tracking via Hyprland IPC. The MouseArea above only
    // fires while the pointer is over the wallpaper surface itself. This keeps
    // the pointer position updated no matter what is under the cursor: launchers,
    // panels, menus, popups, notifications or any normal window/fullscreen app.
    Timer {
        id: cursorPollTimer
        interval: 200
        repeat: true
        running: Config.options.background.depthEffect.enable
                 && Config.options.background.depthEffect.mouseParallax
        onTriggered: {
            if (!cursorPollProc.running) cursorPollProc.running = true;
        }
    }

    Process {
        id: cursorPollProc
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector { id: cursorPollOut }
        onExited: (code, exitStatus) => {
            const m = cursorPollOut.text.trim().match(/(\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)/);
            if (code !== 0 || !m) return;
            // hyprctl reports global (composite) coordinates → make them
            // relative to this monitor so the parallax math stays correct.
            const geo = WM.monitorGeometry(root.screen);
            root.mouseX = parseFloat(m[1]) - (geo?.x ?? 0);
            root.mouseY = parseFloat(m[2]) - (geo?.y ?? 0);
        }
    }

    Timer {
        interval: 700
        repeat: true
        running: Config.options.background.depthEffect.enable
        onTriggered: {
            const raw = root.getConfigSortedLayers();
            const cfgSummary = raw.map(l => `${l.name}:sc=${l.scale}`).join(",");
            const d = layerRepeater.itemAt(0);
            console.log(`[DepthDebug] cfg=[${cfgSummary}] sc=${d ? Math.round(d.layerScale) : -1} ` +
                        `os=${d ? Math.round(d.overscanScale * 100) : -1} renderW=${d ? Math.round(d.renderedW) : -999} ` +
                        `availX=${d ? Math.round(d.availableX) : -1} availY=${d ? Math.round(d.availableY) : -1} ` +
                        `px=${d ? Math.round(d.parallaxX) : -999} py=${d ? Math.round(d.parallaxY) : -999} ` +
                        `mouse=${Math.round(root.mouseX)}x${Math.round(root.mouseY)} ws=${root.activeWorkspaceId}`);
        }
    }

    function getConfigSortedLayers() {
        const layers = Config.options.background.depthEffect.layers || [];
        const sorted = layers.slice().sort((a, b) => {
            const ai = a.name === "background" ? 0 : (parseInt(a.name.replace("layer", "")) || 1);
            const bi = b.name === "background" ? 0 : (parseInt(b.name.replace("layer", "")) || 1);
            return ai - bi;
        });
        return sorted;
    }

    // Ordered back-to-front scene content strictly below a widget sitting at
    // depth slot `depthPos` ("just above layer depthPos-1"): the base
    // wallpaper plus layer delegates 0..depthPos-1. Feeds WidgetBackdropBlur
    // so frosted glass samples the TRUE behind-content (depth layers
    // included) instead of a wallpaper reference. Hidden layers render
    // nothing, hence no ON/OFF special-casing anywhere.
    function backdropSourcesBelow(depthPos) {
        const sources = [];
        if (root.wallpaperItem) sources.push(root.wallpaperItem);
        const n = Math.min(Math.max(0, Math.floor(depthPos)), root.depthLayers.length);
        for (let i = 0; i < n; i++) {
            const it = layerRepeater.itemAt(i);
            if (it) sources.push(it);
        }
        return sources;
    }

    // ✅ Depth ON/OFF <-> Matugen integration through the ORIGINAL wallpaper
    // pipeline only (compose -> Wallpapers.apply -> wallpaperPath). Enabling
    // depth preserves the normal wallpaper, then composes ALL layers and
    // applies the composite (Matugen reads it). Disabling restores the exact
    // preserved wallpaper (Matugen reads that). No colors-only bypass.
    function preserveNormalWallpaper() {
        if (GlobalStates.preDepthWallpaperPath !== "") return;
        const raw = String(Config.options.background.wallpaperPath || "").replace(/^file:\/\//, "");
        if (!raw) return;
        // Never preserve a depth composite itself as the "normal" wallpaper.
        if (raw.startsWith(String(Directories.depthWallpapers))) return;
        GlobalStates.preDepthWallpaperPath = raw;
    }

    Timer {
        id: depthAutoComposeTimer
        interval: 450
        repeat: false
        onTriggered: root.depthAutoCompose()
    }

    function scheduleDepthAutoCompose() {
        if (!Config.options.background.depthEffect.enable) return;
        depthAutoComposeTimer.restart();
    }

    property bool _composeDebounce: false

    function depthAutoCompose() {
        if (!Config.options.background.depthEffect.enable || !root.isPrimary) return;
        if (root._composeDebounce) return;
        root._composeDebounce = true;
        Qt.callLater(() => { root._composeDebounce = false; });

        root.refreshDepthLayers();
        if (layerCompositeProc.running) {
            root.scheduleDepthAutoCompose();
            return;
        }
        const layers = root.getConfigSortedLayers();
        if (layers.length === 0) return;
        const missing = layers.filter(l => !l.image || !String(l.image).trim().length);
        // Incomplete layers: leave the current colors alone. The explicit
        // "Apply wallpaper" button still validates and reports the error.
        if (missing.length > 0) return;
        root.applyAsWallpaper();
    }

    function restoreNormalWallpaper() {
        const prev = String(GlobalStates.preDepthWallpaperPath || "");
        GlobalStates.preDepthWallpaperPath = "";
        if (!prev) return;
        const cur = String(Config.options.background.wallpaperPath || "").replace(/^file:\/\//, "");
        // Already showing it (depth was enabled but never applied): colors
        // already match, so skip the redundant wallpaper switch.
        if (cur === prev) return;
        Wallpapers.apply(prev);
        root.setWallpaperPathSelf("file://" + prev);
        MaterialThemeLoader.reapplyTheme();
    }

    function applyAsWallpaper() {
        // An explicit apply supersedes any pending automatic re-compose.
        depthAutoComposeTimer.stop();
        if (!Config.options.background.depthEffect.enable) return;
        if (!root.isPrimary) return;
        const layers = root.getConfigSortedLayers();

        const missingImages = layers.filter(l => !l.image || !String(l.image).trim().length);

        if (layers.length === 0 || missingImages.length > 0) {
            GlobalStates.depthWallpaperApplyErrorText = Translation.tr("Add an image to every layer or remove empty layers.");
            GlobalStates.depthWallpaperApplyState = "error";
            return;
        }

        GlobalStates.depthWallpaperApplyState = "applying";
        const W = Math.round(root.screenWidth);
        const H = Math.round(root.screenHeight);
        const timestamp = Date.now();
        const tmpDir = `${Directories.depthWallpapers}/compose-${timestamp}`;
        const savePath = `${Directories.depthWallpapers}/depth-wallpaper-${timestamp}.png`;
        layerCompositeProc.compositeTargetPath = savePath;

        // ✅ Per-layer scale identical to the live renderer: manual scale when
        // autoScale is off, otherwise the auto scale required by the parallax
        // sensitivity. The image is resized to the source-aspect "cover" box
        // (nothing cropped!) and the screen-sized window is kept — centered by
        // default, or shifted by the layer's manual X/Y when "Positioning" is
        // ON (top-left corner sits at (X, Y), negatives move it off-screen just
        // like the live renderer). Positioning OFF bakes byte-identical to the
        // legacy centered crop. Fully off-screen layers bake transparent.
        let script = "set -e\n";
        script += `mkdir -p "${tmpDir}"\n`;
        script += `W=${W}\nH=${H}\n\n`;
        script += "compose_layer() {\n";
        script += '  local img="$1" sens="$2" depth="$3" auto="$4" man="$5" manual="$6" px="$7" py="$8" out="$9"\n';
        script += '  local IW IH BW BH L T wid hei dstx dsty\n';
        script += '  read IW IH <<< "$(magick identify -format "%w %h" "$img")"\n';
        script += '  read BW BH L T wid hei dstx dsty <<< "$(awk -v IW="$IW" -v IH="$IH" -v W="$W" -v H="$H" -v sens="$sens" -v depth="$depth" -v auto="$auto" -v man="$man" -v manual="$manual" -v px="$px" -v py="$py" \'BEGIN {\n';
        script += '    c1 = W/IW; c2 = H/IH; CS = (c1 > c2) ? c1 : c2;\n';
        script += '    req = 1 + sens * depth * 0.2;\n';
        script += '    kx = IW * CS / W; ky = IH * CS / H;\n';
        script += '    s = req/kx; if (req/ky > s) s = req/ky; if (s < 1) s = 1;\n';
        script += '    S = 1; # bake the whole-photo FRONT framing (nothing cropped)\n';
        script += '    BW = (IW*CS*S)+0.5; BH = (IH*CS*S)+0.5;\n';
        script += '    # Effective top-left of the resized image on the screen:\n';
        script += '    #   positioning ON  -> image top-left at (px, py)\n';
        script += '    #   positioning OFF -> centered (new image window in screen px)\n';
        script += '    if (manual == 1) { pxe = px; pye = py; } else { pxe = (W - BW)/2; pye = (H - BH)/2; }\n';
        script += '    # Crop = the image pixels covered by the screen, placed at their\n';
        script += '    # exact screen position; uncovered margins stay transparent so the\n';
        script += '    # layers beneath show through, mirroring the live renderer.\n';
        script += '    L = (pxe < 0) ? -pxe : 0; if (L > BW) L = BW;\n';
        script += '    R = W - pxe; if (R < 0) R = 0; if (R > BW) R = BW;\n';
        script += '    wid = R - L; if (wid < 0) wid = 0;\n';
        script += '    T = (pye < 0) ? -pye : 0; if (T > BH) T = BH;\n';
        script += '    B = H - pye; if (B < 0) B = 0; if (B > BH) B = BH;\n';
        script += '    hei = B - T; if (hei < 0) hei = 0;\n';
        script += '    dstx = L + pxe; dsty = T + pye;\n';
        script += '    printf "%d %d %d %d %d %d %d %d", BW, BH, L, T, wid, hei, dstx, dsty;\n';
        script += "  }')\"\n";
        script += '  if [ "${wid}" -gt 0 ] && [ "${hei}" -gt 0 ]; then\n';
        script += '    magick -size "${W}x${H}" xc:transparent \\( -define jpeg:size="${BW}x${BH}" "$img" -auto-orient -resize "${BW}x${BH}" -crop "${wid}x${hei}+${L}+${T}" +repage \\) -geometry "+${dstx}+${dsty}" -composite -depth 8 "$out"\n';
        script += '  else\n';
        script += '    magick -size "${W}x${H}" xc:transparent -depth 8 "$out"\n';
        script += '  fi\n';
        script += "}\n\n";

        for (let i = 0; i < layers.length; i++) {
            const layer = layers[i];
            // ✅ Every layer (including "background") bakes its OWN image.
            let img = String(layer.image).trim();
            const sens = Number(layer.parallaxSensitivity) || 0.55;
            // ✅ Each layer moves only by its OWN settings (no positional weight).
            const depth = 1;
            const auto = (layer.autoScale ?? false) ? 1 : 0;
            const man = (Number(layer.scale) || 100) / 100;
            const manual = (layer.manualPositioning ?? false) ? 1 : 0;
            const posX = (Number(layer.positionX) || 0);
            const posY = (Number(layer.positionY) || 0);
            const out = `${tmpDir}/layer-${i}.png`;
            script += `compose_layer "${img}" ${sens} ${depth} ${auto} ${man} ${manual} ${posX} ${posY} "${out}"\n`;
        }

        script += `magick -size "${W}x${H}" xc:transparent`;
        for (let i = 0; i < layers.length; i++) {
            script += ` "${tmpDir}/layer-${i}.png" -composite`;
        }
        script += ` -depth 8 "${savePath}"\n`;
        // ✅ Never let a blank bake through: a fully off-screen / empty layer
        // set produces a ~byte-size bilevel PNG that would otherwise become
        // the wallpaper AND poison Matugen (the color generator cannot score
        // it). Fail loudly instead so nothing downstream consumes garbage.
        script += `{ sz=$(stat -c%s "${savePath}"); [ "$sz" -gt 10240 ]; } || { echo "Composed wallpaper is blank (${savePath}); check that layers have images and are on-screen."; exit 1; }\n`;
        script += `rm -rf "${tmpDir}"\n`;

        layerCompositeProc.command = ["bash", "-c", script];
        layerCompositeProc.running = true;
    }

    Process {
        id: layerCompositeProc
        property string compositeTargetPath: ""
        stdout: StdioCollector { id: layerCompositeOutput }
        onExited: (code, exitStatus) => {
            const savePath = layerCompositeProc.compositeTargetPath;
            layerCompositeProc.compositeTargetPath = "";
            if (code !== 0 || savePath.length === 0) {
                GlobalStates.depthWallpaperApplyErrorText = layerCompositeOutput.text.trim() || Translation.tr("Failed to compose the layers into a wallpaper.");
                GlobalStates.depthWallpaperApplyState = "error";
            } else if (!Config.options.background.depthEffect.enable) {
                // Toggled off mid-bake: the composite is stale — discard it
                // instead of resurrecting a depth wallpaper (and its theme)
                // over the restored normal one.
                GlobalStates.depthWallpaperApplyState = "idle";
            } else {
                GlobalStates.depthWallpaperCompositePath = savePath;
                // fromDepth: the depth composition's own apply must not
                // turn depth off (see Wallpapers.apply).
                Wallpapers.apply(savePath, Appearance.m3colors.darkmode, true);
                root.setWallpaperPathSelf("file://" + savePath);
                // Explicitly reload the material theme so Appearance.m3colors
                // picks up the new colors from the freshly-generated
                // colors.json without waiting for the FileView watcher.
                MaterialThemeLoader.reapplyTheme();
                GlobalStates.depthWallpaperApplyState = "done";
            }
        }
    }

    Repeater {
        id: layerRepeater
        model: root.depthLayers

        delegate: Item {
            id: layerItem
            required property var modelData
            required property int index

            property var currentLayer: {
                const layers = Config.options.background.depthEffect.layers || [];
                return layers.find(l => l.name === modelData.name) || modelData;
            }

            property string layerName: currentLayer.name
            // ✅ Every layer (including "background") renders its OWN image.
            property string layerImage: currentLayer.image || ""
            property real layerScale: currentLayer.scale ?? 100
            property bool layerAutoScale: currentLayer.autoScale ?? false
            property bool layerBound: currentLayer.bound ?? false
            property bool layerReverseParallax: currentLayer.reverseParallax ?? false
            property bool layerPositioningEnabled: currentLayer.manualPositioning ?? false
            property real layerPositionX: layerPositioningEnabled ? (Number(currentLayer.positionX) || 0) : 0
            property real layerPositionY: layerPositioningEnabled ? (Number(currentLayer.positionY) || 0) : 0
            property real layerParallaxSensitivity: currentLayer.parallaxSensitivity ?? 0.55
            property bool layerWorkspaceParallax: currentLayer.workspaceParallax ?? true
            property bool layerMouseParallax: currentLayer.mouseParallax ?? true
            // ✅ Per-layer settings are used AS-IS. No hidden positional weight:
            // a layer's sensitivity/depth is exactly its own value, so changing
            // one layer never affects another and the background behaves like
            // any normal layer.
            property real depthFactor: 1
            property real layerWorkspaceParallaxSensitivity: currentLayer.workspaceParallaxSensitivity ?? 1

            // ✅ Explicit stacking: index 0 (the sorted "background" entry) is
            // always the backmost layer; higher indexes render in front. This
            // is driven by the sorted model, NOT by creation order.
            z: layerItem.index
            // The container itself is always visible (it also hosts the
            // widgets); only the depth layers hide when depth is disabled —
            // and, on the lock screen, so the lock wallpaper (which lives on
            // the normal wallpaper surface) is never covered by cut-outs.
            visible: Config.options.background.depthEffect.enable && !GlobalStates.screenLocked
            anchors.fill: parent
            clip: true // Prevents the oversized image from bleeding outside the screen bounds

            // ✅ True "cover" size based on the SOURCE aspect ratio. The image
            // is scaled to the minimum size that still covers the whole screen
            // (source aspect preserved, NOTHING cropped).
            property real srcW: layerImageItem.sourceSize.width || root.screenWidth
            property real srcH: layerImageItem.sourceSize.height || root.screenHeight
            property real coverScale: Math.max(root.screenWidth / layerItem.srcW, root.screenHeight / layerItem.srcH)
            property real baseW: layerItem.srcW * layerItem.coverScale
            property real baseH: layerItem.srcH * layerItem.coverScale

            // ✅ Manual scale multiplier (used when autoScale is OFF)
            property real manualScale: Math.max(1, (layerScale / 100.0))

            // ✅ The maximum the mouse can ever translate the image ON TOP of
            // the viewport before the bound clamps it (mouse at screen edge).
            property real maxMouseOffsetX: (root.screenWidth / 2) * layerParallaxSensitivity * depthFactor * 0.2
            property real maxMouseOffsetY: (root.screenHeight / 2) * layerParallaxSensitivity * depthFactor * 0.2

            // ✅ Overscan scale: the image is always rendered LARGER than the
            // viewport by exactly this margin, so even at the maximum parallax
            // translation its own edges stay off-screen and it NEVER exposes
            // the underlying static background. The source image is never
            // cropped — the viewport simply clips the oversized render.
            //
            //   overscanScale = max(
            //       (screenW + 2 * maxMouseOffsetX) / baseW,
            //       (screenH + 2 * maxMouseOffsetY) / baseH)
            //
            property real overscanScale: {
                const sxNeeded = (root.screenWidth + 2 * layerItem.maxMouseOffsetX) / Math.max(1, layerItem.baseW);
                const syNeeded = (root.screenHeight + 2 * layerItem.maxMouseOffsetY) / Math.max(1, layerItem.baseH);
                return Math.max(1, sxNeeded, syNeeded);
            }

            // ✅ Effective render size.
            //   AutoScale ON : auto-size the image to accommodate the requested
            //                  parallax range (overscan), so it always covers.
            //   AutoScale OFF: the user's exact manual scale — NEVER resized.
            property real effectiveRenderScale: layerItem.layerAutoScale ? layerItem.overscanScale : layerItem.manualScale

            // ✅ The parallax image, rendered at the effective scale (whole
            // photo, never cropped to the viewport).
            property real renderedW: baseW * layerItem.effectiveRenderScale
            property real renderedH: baseH * layerItem.effectiveRenderScale

            // ✅ Maximum safe movement on each axis = the oversize of the
            // rendered image beyond the viewport, divided by two:
            //     availableX = max(0, renderedW - viewportW) / 2
            //     availableY = max(0, renderedH - viewportH) / 2
            // Bound uses these to clamp X and Y INDEPENDENTLY.
            property real availableX: Math.max(0, (layerItem.renderedW - root.screenWidth) / 2)
            property real availableY: Math.max(0, (layerItem.renderedH - root.screenHeight) / 2)

            property real wsFraction: {
                const supportN = Math.max(2, Config.options.background.depthEffect.workspaceParallaxSupportNumber || 5);
                if (!root.activeWorkspaceId || root.activeWorkspaceId <= 0) return 0;
                return Math.max(0, Math.min(1, (root.activeWorkspaceId - 1) / (supportN - 1)));
            }

            property real parallaxX: {
                if (!Config.options.background.depthEffect.enable || (!layerMouseParallax && !layerWorkspaceParallax)) return 0;

                let offset = 0;
                if (layerWorkspaceParallax) {
                    offset -= layerItem.wsFraction * 2 * layerItem.availableX * layerItem.layerWorkspaceParallaxSensitivity;
                }
                if (layerMouseParallax) {
                    const dir = layerItem.layerReverseParallax ? 1 : -1;
                    const mouseOffset = (root.mouseX - root.screenWidth / 2) * layerParallaxSensitivity * depthFactor * 0.2;
                    offset += dir * mouseOffset;
                }

                // ✅ BOUND ON: clamp translation on the X axis to its own available
                // coverage (±availableX). Never touches the image scale.
                //   BOUND OFF: unrestricted parallax — overflow into the
                //   static background below is allowed.
                const maxShift = layerItem.layerBound ? layerItem.availableX : (2 * layerItem.availableX + root.headroomX);
                return Math.max(-maxShift, Math.min(maxShift, offset));
            }

            property real parallaxY: {
                if (!Config.options.background.depthEffect.enable || !layerMouseParallax) return 0;

                const dir = layerItem.layerReverseParallax ? 1 : -1;
                let offset = dir * (root.mouseY - root.screenHeight / 2) * layerParallaxSensitivity * depthFactor * 0.2;

                // ✅ BOUND ON: clamp the Y axis to its own available coverage
                // (±availableY), independently from X.
                const maxShift = layerItem.layerBound ? layerItem.availableY : (2 * layerItem.availableY + root.headroomY);
                return Math.max(-maxShift, Math.min(maxShift, offset));
            }

            // ✅ The viewport clips; the oversized image always covers. The static
            // background (layer 0, untouched) is never exposed.
            Behavior on parallaxX {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on parallaxY {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            // ✅ OVERSIZED PARALLAX: rendered larger than the viewport by the
            // overscan margin. The viewport clips it; mouse translation pans
            // within that oversized render. The static background behind
            // (Background.qml layer 0) is never exposed during movement.
            StyledImage {
                id: layerImageItem
                // ✅ Manual positioning: OFF keeps the image centered (top-left at
                // the centering offset) exactly like before. ON anchors the image's
                // top-left corner at (layerPositionX, layerPositionY) — (0,0) is the
                // screen's top-left corner, negatives move it off-screen. When a
                // layer is NOT positioned the anchors.centerIn binding keeps the
                // exact legacy behavior (x/y are ignored while centered).
                anchors.centerIn: layerItem.layerPositioningEnabled ? undefined : parent
                x: layerItem.layerPositioningEnabled ? layerItem.layerPositionX : 0
                y: layerItem.layerPositioningEnabled ? layerItem.layerPositionY : 0
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                width: layerItem.renderedW
                height: layerItem.renderedH
                opacity: layerItem.layerImage !== "" ? 1 : 0
                visible: opacity > 0
                z: 1
                source: layerItem.layerImage.startsWith("file://") ? layerItem.layerImage : (layerItem.layerImage !== "" ? "file://" + layerItem.layerImage : "")

                transform: Translate {
                    x: layerItem.parallaxX
                    y: layerItem.parallaxY
}
    }
}
}
}
