import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    required property var screen
    required property string wallpaperPath
    required property bool wallpaperIsVideo

    readonly property bool centeredWallpaperConfigEnabled: Config.options.background.centeredWallpaper
    property bool centeredWallpaperEnabled: false
    property bool centeredWallpaperPendingDisable: false
    property bool centeredOnlyWhenLocked: Config.options.background.centeredWallpaperOnlyWhenLocked
    property int centeredWallpaperShape: CF.ShapeUtils.getShape(Config.options.background.centeredWallpaperShape)
    property int centeredWallpaperSize: Config.options.background.centeredWallpaperSize
    property color centeredWallpaperColor: Appearance.getColorFromName(Config.options.background.centeredWallpaperColor)

    onCenteredOnlyWhenLockedChanged: {
        root.setCenteredProgress(GlobalStates.screenLocked ? 0 : (root.centeredOnlyWhenLocked ? 1 : 0))
    }

    onCenteredWallpaperConfigEnabledChanged: {
        if (root.centeredWallpaperConfigEnabled) {
            root.centeredWallpaperPendingDisable = false
            root.centeredWallpaperEnabled = true
            root.centeredProgress = 1
            root.setCenteredProgress(GlobalStates.screenLocked ? 0 : (root.centeredOnlyWhenLocked ? 1 : 0))
        } else {
            if (root.centeredProgress === 1) {
                root.centeredWallpaperEnabled = false
            } else {
                root.centeredWallpaperPendingDisable = true
                root.setCenteredProgress(1)
            }
        }
    }

    // Size the shape (with the wallpaper inside) must reach so its masked
    // area fully covers the screen; the shape then leaves the screen.
    // The shape item is rendered at this fixed size and only transformed
    // (scaled) during the transition, so the 2D canvas + mask are painted
    // once instead of re-rasterized every frame at a changing size.
    property real centeredShapeMax: Math.max(1, Math.ceil(
        Math.hypot(root.screen.width / 2, root.screen.height / 2)
        / CF.ShapeUtils.centeredShapeMinBoundaryRadius(root.centeredWallpaperShape) * 1.02))
    // Pixel size the shape item/layer is rendered at. Kept at roughly the
    // screen diagonal instead of centeredShapeMax (which can be 2.5x that)
    // so the layer + OpacityMask + 2D canvases are ~6x cheaper per frame;
    // the scale below compensates, so the silhouette and the picture inside
    // stay identical (edges soften only while the shape outgrows the layer).
    property real centeredShapeRenderSize: Math.max(1, Math.ceil(
        Math.hypot(root.screen.width, root.screen.height)))

    // 0 = locked (wallpaper rests centered inside the shape), 1 = unlocked
    // (wallpaper fills the screen). This is the only animated driver: the
    // mappings below derive every size/opacity from it, so no secondary
    // animations fight and the transition cannot blink.
    property bool centeredAnimationReady: false
    property bool centeredAnimating: false
    property real centeredProgress: 0

    // Unlock is slower (0.8s) than lock (0.65s); the helper picks the
    // animation by direction. It also skips the animation while the config
    // is still loading, so the initial set never plays a grow-in on startup.
    function setCenteredProgress(value) {
        if (!root.centeredWallpaperEnabled || !Config.ready) {
            root.centeredProgress = value
            return
        }
        if (!root.centeredAnimationReady) {
            root.centeredProgress = value
            root.centeredAnimationReady = true
            return
        }
        if (value === root.centeredProgress) return
        const anim = value > root.centeredProgress ? centeredUnlockAnim : centeredLockAnim
        anim.to = value
        anim.restart()
    }
    NumberAnimation {
        id: centeredLockAnim
        target: root
        property: "centeredProgress"
        duration: 650
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
        onRunningChanged: root.centeredAnimating = running
    }
    NumberAnimation {
        id: centeredUnlockAnim
        target: root
        property: "centeredProgress"
        duration: 800
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
        onRunningChanged: {
            root.centeredAnimating = running
            if (!running && root.centeredWallpaperPendingDisable) {
                root.centeredWallpaperPendingDisable = false
                root.centeredWallpaperEnabled = false
            }
        }
    }

    // The centered shape is actually shown on screen only while the
    // progress has not reached the desktop end (locked state + transitions).
    readonly property bool centeredShapeActive: root.centeredWallpaperEnabled
        && (root.centeredProgress < 1 || root.centeredAnimating)

    // The full-screen wallpaper must stay rendered while it is visible
    // (fading in/out, desktop); only turn it off once fully transparent.
    readonly property bool centeredHidesFullWallpaper: root.centeredWallpaperEnabled
        && root.centeredFullWallpaperOpacity() <= 0

    property real centeredFade: 0.05

    // Size of the centered shape: grows from centeredWallpaperSize to
    // centeredShapeMax as the progress goes 0 (locked) -> 1 (unlocked).
    function centeredShapeSize() {
        if (!root.centeredWallpaperEnabled) return 1
        return root.centeredWallpaperSize
            + root.centeredProgress * (root.centeredShapeMax - root.centeredWallpaperSize)
    }
    function centeredImageScale() {
        if (!root.centeredWallpaperEnabled) return 1
        const minDim = Math.min(root.screen.width, root.screen.height)
        const size = root.centeredShapeSize()
        const overscan = size >= minDim ? 1
            : 1.08 - 0.08 * (size - root.centeredWallpaperSize) / (minDim - root.centeredWallpaperSize)
        return overscan * root.centeredShapeRenderSize
            / Math.max(size, minDim)
    }
    function centeredFullWallpaperOpacity() {
        if (!root.centeredWallpaperEnabled) return 1
        return Math.max(0, Math.min(1,
            (root.centeredProgress - (1 - root.centeredFade)) / root.centeredFade))
    }
    function centeredBgOpacity() {
        if (!root.centeredWallpaperEnabled) return 0
        if (root.wallpaperIsVideo) return 0
        return Math.max(0, Math.min(1, (1 - root.centeredProgress) / root.centeredFade))
    }

    Component.onCompleted: {
        root.centeredWallpaperEnabled = root.centeredWallpaperConfigEnabled
        root.setCenteredProgress(GlobalStates.screenLocked ? 0 : (root.centeredOnlyWhenLocked ? 1 : 0))
        if (Config.ready)
            root.centeredAnimationReady = true
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (!Config.ready) return
            root.setCenteredProgress(GlobalStates.screenLocked ? 0 : (root.centeredOnlyWhenLocked ? 1 : 0))
            root.centeredAnimationReady = true
        }
    }

    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            root.setCenteredProgress(GlobalStates.screenLocked ? 0 : (root.centeredOnlyWhenLocked ? 1 : 0))
        }
    }

    Rectangle {
        id: centeredWallpaperBg
        anchors.fill: parent
        color: root.centeredWallpaperColor
        opacity: root.centeredBgOpacity()
        visible: opacity > 0
    }

    MaterialShape {
        id: centeredWallpaperShapeItem
        anchors.centerIn: parent
        width: root.centeredShapeRenderSize
        height: root.centeredShapeRenderSize
        color: root.wallpaperIsVideo ? "transparent" : root.centeredWallpaperColor
        shape: root.centeredWallpaperShape
        transformOrigin: Item.Center
        property real shapeZoom: 1
        scale: (root.centeredShapeSize() / root.centeredShapeRenderSize) * shapeZoom
        visible: root.centeredWallpaperEnabled
            && (root.centeredProgress < 1 || root.centeredAnimating)

        SequentialAnimation {
            id: shapeZoomAnim
            NumberAnimation { target: centeredWallpaperShapeItem; property: "shapeZoom"; to: 1.06; duration: 300; easing.type: Easing.OutQuad }
            NumberAnimation { target: centeredWallpaperShapeItem; property: "shapeZoom"; to: 1.0;  duration: 500; easing.type: Easing.InOutQuad }
        }
        SequentialAnimation {
            id: imageFollowAnim
            PauseAnimation { duration: 200 }
            NumberAnimation { target: centeredWallpaperImage; property: "imageZoom"; to: 1.08; duration: 250; easing.type: Easing.OutQuad }
            NumberAnimation { target: centeredWallpaperImage; property: "imageZoom"; to: 1.0;  duration: 350; easing.type: Easing.InOutQuad }
        }
        function thump() {
            if (shapeZoomAnim.running || imageFollowAnim.running) return
            shapeZoomAnim.restart()
            imageFollowAnim.restart()
        }

        Connections {
            target: GlobalStates
            function onCenteredWallpaperThumpRequested() {
                centeredWallpaperShapeItem.thump()
            }
        }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: MaterialShape {
                width: centeredWallpaperShapeItem.width
                height: centeredWallpaperShapeItem.height
                shape: root.centeredWallpaperShape
            }
        }

        StyledImage {
            id: centeredWallpaperImage
            width: root.width
            height: root.height
            anchors.centerIn: parent
            source: root.wallpaperPath
            fillMode: Image.PreserveAspectCrop
            cache: false
            mipmap: true
            antialiasing: true
            sourceSize.width: root.width
            sourceSize.height: root.height
            property real imageZoom: 1
            scale: root.centeredImageScale() * (1 / centeredWallpaperShapeItem.shapeZoom) * imageZoom
        }

        MouseArea {
            anchors.fill: parent
            z: 1
            acceptedButtons: Qt.LeftButton
                onClicked: centeredWallpaperShapeItem.thump()
            onWheel: (wheel) => {
                if (!Config.options.background.centeredWallpaperShapeCycle) return
                if (shapeCycleCooldown.running) return
                GlobalStates.cycleCenteredWallpaperShape(wheel.angleDelta.y > 0 ? 1 : -1)
                shapeCycleCooldown.restart()
                wheel.accepted = true
            }
            Timer {
                id: shapeCycleCooldown
                interval: 400
            }
        }
    }
}