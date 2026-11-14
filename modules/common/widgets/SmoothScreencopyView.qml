import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland

/**
 * ScreencopyView that shrinks the capture with a Catmull-Rom area filter
 * instead of plain bilinear. Bilinear skips texels when it shrinks a large
 * capture (for example, a 4K window to a 700 px preview), so text aliases.
 *
 * Use it like ScreencopyView: set width/height, or set constraintSize to fit
 * the capture's aspect ratio.
 *
 * Cost: ScreencopyView is not a texture provider, so the capture is copied once
 * into a ShaderEffectSource. That copy is made at half size when the preview is
 * at least 2x smaller. The 2:1 bilinear copy is an exact 2x2 box average, so it
 * loses nothing and needs 4x less memory than a full-size copy. When the
 * preview is close to full size, the filter is off and the plain view is drawn.
 */
Item {
    id: root
    property alias captureSource: view.captureSource
    property alias live: view.live
    property alias paintCursor: view.paintCursor
    readonly property alias hasContent: view.hasContent
    readonly property alias sourceSize: view.sourceSize
    property size constraintSize: Qt.size(0, 0)

    readonly property real fitScale: {
        const sw = view.sourceSize.width, sh = view.sourceSize.height;
        if (sw <= 0 || sh <= 0 || constraintSize.width <= 0 || constraintSize.height <= 0)
            return 1;
        return Math.min(constraintSize.width / sw, constraintSize.height / sh);
    }
    implicitWidth: view.sourceSize.width * fitScale
    implicitHeight: view.sourceSize.height * fitScale

    readonly property real dpr: root.Window.window?.devicePixelRatio ?? Screen.devicePixelRatio ?? 1
    readonly property real outWidth: Math.max(1, width * dpr)
    readonly property real outHeight: Math.max(1, height * dpr)
    // Source texels per output pixel, on the larger axis.
    readonly property real ratio: Math.max(view.width / outWidth, view.height / outHeight)
    // Below 1.5x, bilinear does not skip texels, so the filter is not needed.
    readonly property bool filtered: view.hasContent && ratio >= 1.5
    readonly property int prescale: ratio >= 2 ? 2 : 1

    ScreencopyView {
        id: view
        // Laid out at capture size, so the copy below samples real texels.
        width: sourceSize.width > 0 ? sourceSize.width : root.width
        height: sourceSize.height > 0 ? sourceSize.height : root.height
        // Unfiltered path: draw the view scaled straight into place.
        transform: Scale {
            xScale: root.width / Math.max(1, view.width)
            yScale: root.height / Math.max(1, view.height)
        }
    }

    ShaderEffectSource {
        id: viewTexture
        sourceItem: root.filtered ? view : null
        hideSource: root.filtered
        live: true
        smooth: true
        visible: false
        textureSize: Qt.size(Math.max(1, Math.round(view.width / root.prescale)),
                             Math.max(1, Math.round(view.height / root.prescale)))
    }

    ShaderEffect {
        anchors.fill: parent
        visible: root.filtered
        property var source: viewTexture
        property point texelStep: Qt.point(1 / viewTexture.textureSize.width,
                                           1 / viewTexture.textureSize.height)
        property point footprint: Qt.point(viewTexture.textureSize.width / root.outWidth,
                                           viewTexture.textureSize.height / root.outHeight)
        fragmentShader: Qt.resolvedUrl("shaders/areaDownsample.frag.qsb")
    }
}
