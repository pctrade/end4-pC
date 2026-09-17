pragma ComponentBehavior: Unbound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.background.widgets

/**
 * A fully customizable text/date-time widget.
 *
 * Renders user-supplied text with optional date/time token expansion,
 * badge background, outline/solid styling, and center-anchored positioning.
 * Every property is backed by its own config entry inside
 * `background.widgets.customWidgets`, so multiple widgets are completely
 * independent of each other (CRUD + persistence via CustomWidgets).
 */
AbstractBackgroundWidget {
    id: root

    readonly property var configHelper: CustomWidgets {}

    // configEntry is overridden to resolve from the customWidgets array;
    // the base implementation looks it up by key in the keyed widgets object.
    // Guarded against Config.options not being built yet so the binding never
    // throws mid-startup (a thrown binding is dropped permanently by Qt).
    // We assign to the inherited configEntry property (not declare a new one)
    // so that base-class bindings (placementStrategy, etc.) use the same source.
    configEntry: Config.ready
        ? (root.configHelper.find(root.configEntryName) ?? {})
        : ({})

    readonly property var cfg: root.configEntry

    // ── Interaction ────────────────────────────────────────────────────
    // Per-widget drag toggle (stored in config, defaults to true). The base
    // class offers drag whenever placementStrategy is "free" and widgets are
    // not globally locked; here we additionally require the widget's own flag.
    property bool draggableCfg: root.cfg?.draggable ?? true
    draggable: root.draggableCfg && root.placementStrategy === "free" && !Config.options.background.widgetsLocked

    // ── Content ───────────────────────────────────────────────────────
    property string rawText: cfg.text ?? "Hello World"
    property string displayText: DateTimeFormatter.format(DateTime.clockSeconds.date, root.rawText)

    // ── Typography ────────────────────────────────────────────────────
    property string fontSource: cfg.fontSource ?? "system" // "system" | "google"
    property string fontFamily: cfg.fontFamily ?? ""
    property string appliedFont: cfg.appliedFont ?? ""
    property string textOpacityLabel: qsTr("Text opacity")
    property string badgeBackgroundOpacityLabel: qsTr("Badge background opacity")
    // (no code changes beyond adding labels – UI will refer to these)
    

    // Google Fonts loaded at runtime are registered globally; resolvedFace
    // holds the actual family to use (favours an applied font, then the
    // registered google family, then the system family).
    property string resolvedFamily: {
        if (root.appliedFont !== "") return root.appliedFont
        if (root.fontSource === "google" && root.fontFamily !== "") return root.fontFamily
        return Appearance.font.family.main
    }

    property real fontSize: cfg.fontSize ?? 48
    property real effectiveFontSize: (cfg.fontSizeUnit ?? "px") === "%"
        ? (cfg.fontSize ?? 48) / 100 * root.screenHeight
        : (cfg.fontSize ?? 48)
    property int fontWeight: cfg.fontWeight ?? 400
    property bool fontItalic: cfg.fontItalic ?? false
    property bool fontSolid: cfg.fontSolid ?? true

    // ── Text color ────────────────────────────────────────────────────
    property string textColorName: cfg.textColor ?? ""
    property color effectiveTextColor: root.resolveColorName(root.textColorName, Appearance.colors.colOnSecondaryContainer)

    // Config colors are stored as theme role names ("primary"), for which
    // Appearance.colors exposes "colPrimary"; literal hex strings are used
    // as-is. Empty means "use the fallback".
    function resolveColorName(key, fallback) {
        if (!key) return fallback
        const k = String(key)
        if (k.startsWith("#")) return ColorUtils.normalizeHexColor(k)
        const propName = "col" + k.charAt(0).toUpperCase() + k.slice(1)
        return Appearance.colors[propName] ?? fallback
    }

    // ── Outline ───────────────────────────────────────────────────────
    property string outlineColorName: cfg.outlineColor ?? ""
    property real outlineWidth: cfg.outlineWidth ?? 2

    // ── Layout ────────────────────────────────────────────────────────
    property real letterSpacing: cfg.letterSpacing ?? 0
    property real lineHeight: cfg.lineHeight ?? 1.0
    property real textOpacity: cfg.opacity ?? 1.0
    property real rotationDeg: cfg.rotation ?? 0
    property string textAlignment: cfg.textAlignment ?? "center"

    // ── Badge ─────────────────────────────────────────────────────────
    property bool badgeEnabled: cfg.badge ?? false
    property bool badgeSolid: cfg.badgeSolid ?? true
    property string badgeColorName: cfg.badgeColor ?? ""
    property color effectiveBadgeColor: root.resolveColorName(root.badgeColorName, Appearance.colors.colSecondaryContainer)
    property real badgeOpacity: cfg.badgeOpacity ?? 1.0
    property real badgeBlur: cfg.badgeBlur ?? 0
    // ── Backdrop filter: true scene blur under the translucent badge ──
    // badgeBackdropBlur reuses the pre-existing config key (old values keep
    // working); it is now the radius of real behind-content blur instead of
    // wallpaper sampling.
    property real badgeBackdropBlur: cfg.badgeBackdropBlur ?? 0
    property bool badgeBackdropEnabled: cfg.badgeBackdropEnabled ?? false
    property real badgeBackdropTint: cfg.badgeBackdropTint ?? 0.55
    property real badgeBackgroundOpacity: cfg.badgeBackgroundOpacity ?? 1.0
    property string badgeOutlineColorName: cfg.badgeOutlineColor ?? ""
    property color effectiveBadgeOutlineColor: root.resolveColorName(root.badgeOutlineColorName, root.effectiveBadgeColor)
    property real badgeOutlineWidth: cfg.badgeOutlineWidth ?? 2
    property bool badgeSameRadius: cfg.badgeSameRadius ?? true
    property real badgeRadiusTL: cfg.badgeRadiusTL ?? 16
    property real badgeRadiusTR: cfg.badgeRadiusTR ?? 16
    property real badgeRadiusBL: cfg.badgeRadiusBL ?? 16
    property real badgeRadiusBR: cfg.badgeRadiusBR ?? 16
    // Effective per-corner radii shared by the badge Shape and the
    // backdrop-blur mask so both always use identical geometry.
    readonly property real effRadiusTL: Math.max(0, root.badgeRadiusTL)
    readonly property real effRadiusTR: root.badgeSameRadius ? Math.max(0, root.badgeRadiusTL) : Math.max(0, root.badgeRadiusTR)
    readonly property real effRadiusBR: root.badgeSameRadius ? Math.max(0, root.badgeRadiusTL) : Math.max(0, root.badgeRadiusBR)
    readonly property real effRadiusBL: root.badgeSameRadius ? Math.max(0, root.badgeRadiusTL) : Math.max(0, root.badgeRadiusBL)
    // Stroke inset: ShapePath strokes are centered on the path, so the
    // outlined path is inset by half the line width to keep the full
    // stroke inside the badge bounds (otherwise sides get clipped and
    // corners look thicker than sides).
    readonly property real badgeStrokeInset: root.badgeSolid ? 0 : root.badgeOutlineWidth / 2
    property bool badgeSamePadding: cfg.badgeSamePadding ?? true
    property real badgePadTop: cfg.badgePaddingTop ?? 8
    property real badgePadRight: cfg.badgePaddingRight ?? 12
    property real badgePadBottom: cfg.badgePaddingBottom ?? 8
    property real badgePadLeft: cfg.badgePaddingLeft ?? 12

    // ── Center-based positioning ───────────────────────────────────────
    // configEntry.x / configEntry.y store the CENTER of the widget in screen
    // pixel coordinates — that is the ONE authoritative position state. The
    // base class derives the visual top-left from it (centerAnchored), so the
    // settings X/Y (px or %) and the drag-drop result are interpreted the same
    // way by the render path and the persistence path.
    centerAnchored: true

    // The drag Binding uses RestoreNone, which destroys the declarative
    // x/y binding during dragging, so it is re-established here after
    // every drag. The stored model value is always the widget CENTRE.
    function commitPosition() {
        const e = root.configEntry
        if (e?.id) {
            // root.x/root.y are top-left. Store the center coordinate.
            const cx = Math.round(root.x + root.width / 2)
            const cy = Math.round(root.y + root.height / 2)
            e.x = cx
            e.y = cy
            root.configHelper.save(e)
        }
        root.restoreXYBinding()
    }



    // ── Size (auto-fit to text + badge padding) ───────────────────────
    width: contentItem.implicitWidth
    height: contentItem.implicitHeight

    // ── Rendering ─────────────────────────────────────────────────────
    Item {
        id: contentItem
        width: root.width
        height: root.height
        implicitWidth: textItem.implicitWidth + (root.badgeEnabled ? root.badgePadLeft + root.badgePadRight : 0)
        implicitHeight: textItem.implicitHeight + (root.badgeEnabled ? root.badgePadTop + root.badgePadBottom : 0)

        // Badge rendering is fully declarative (Shape + layer effects), so
        // every property change (color, opacity, radii, outline width)
        // updates live with no manual repaint calls.

        // Badge background with real alpha support.
        // Paint order: badge fill/border -> sharp text.
        Item {
            id: badgeContainer
            anchors.fill: parent
            visible: root.badgeEnabled

            // Badge fill below uses real alpha (badgeBackgroundOpacity), so the
            // live scene behind (plain or depth wallpaper) shows through
            // naturally. (The previous wallpaper-sampled backdrop-blur layer
            // was removed: it went stale under depth layers.)

            // Backdrop filter: true scene blur (wallpaper + depth layers
            // below the badge) under the translucent badge fill. The fill
            // stays untouched, so transparency survives wherever blur
            // shows nothing. Mask uses the largest badge corner so blur
            // never fringes past the fill.
            WidgetBackdropBlur {
                anchors.fill: parent
                cardRadius: Math.max(root.effRadiusTL, root.effRadiusTR, root.effRadiusBL, root.effRadiusBR)
                blurRadius: Math.max(1, root.badgeBackdropBlur)
                tint: root.effectiveBadgeColor
                tintOpacity: root.badgeBackdropTint
                backdropSources: root.backdropSources
                visible: root.badgeEnabled && root.badgeBackdropEnabled
            }

            // Badge background (solid fill OR outlined stroke).
            // Vector Shape with CurveRenderer: per-corner radii, live
            // bindings (no repaint plumbing), crisp antialiased edges.
            // The outlined path is inset by half the line width so the
            // full stroke stays inside the bounds (uniform sides+corners).
            Shape {
                id: badgeShape
                anchors.fill: parent
                opacity: root.badgeSolid ? root.badgeBackgroundOpacity : 1.0
                layer.enabled: root.badgeBlur > 0
                layer.effect: FastBlur {
                    radius: root.badgeBlur
                    transparentBorder: true
                }
                layer.smooth: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: root.badgeSolid ? root.effectiveBadgeColor : "transparent"
                    strokeColor: root.badgeSolid ? "transparent" : root.effectiveBadgeOutlineColor
                    strokeWidth: root.badgeSolid ? 0 : root.badgeOutlineWidth
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap
                    PathMove {
                        x: Math.min(root.effRadiusTL, badgeShape.width / 2, badgeShape.height / 2) + root.badgeStrokeInset
                        y: root.badgeStrokeInset
                    }
                    PathLine { x: badgeShape.width - Math.min(root.effRadiusTR, badgeShape.width / 2, badgeShape.height / 2) - root.badgeStrokeInset; y: root.badgeStrokeInset }
                    PathArc {
                        x: badgeShape.width - root.badgeStrokeInset
                        y: Math.min(root.effRadiusTR, badgeShape.width / 2, badgeShape.height / 2) + root.badgeStrokeInset
                        radiusX: Math.max(0, Math.min(root.effRadiusTR, badgeShape.width / 2, badgeShape.height / 2) - root.badgeStrokeInset)
                        radiusY: Math.max(0, Math.min(root.effRadiusTR, badgeShape.width / 2, badgeShape.height / 2) - root.badgeStrokeInset)
                        direction: PathArc.Clockwise
                    }
                    PathLine { x: badgeShape.width - root.badgeStrokeInset; y: badgeShape.height - Math.min(root.effRadiusBR, badgeShape.width / 2, badgeShape.height / 2) - root.badgeStrokeInset }
                    PathArc {
                        x: badgeShape.width - Math.min(root.effRadiusBR, badgeShape.width / 2, badgeShape.height / 2) - root.badgeStrokeInset
                        y: badgeShape.height - root.badgeStrokeInset
                        radiusX: Math.max(0, Math.min(root.effRadiusBR, badgeShape.width / 2, badgeShape.height / 2) - root.badgeStrokeInset)
                        radiusY: Math.max(0, Math.min(root.effRadiusBR, badgeShape.width / 2, badgeShape.height / 2) - root.badgeStrokeInset)
                        direction: PathArc.Clockwise
                    }
                    PathLine { x: Math.min(root.effRadiusBL, badgeShape.width / 2, badgeShape.height / 2) + root.badgeStrokeInset; y: badgeShape.height - root.badgeStrokeInset }
                    PathArc {
                        x: root.badgeStrokeInset
                        y: badgeShape.height - Math.min(root.effRadiusBL, badgeShape.width / 2, badgeShape.height / 2) - root.badgeStrokeInset
                        radiusX: Math.max(0, Math.min(root.effRadiusBL, badgeShape.width / 2, badgeShape.height / 2) - root.badgeStrokeInset)
                        radiusY: Math.max(0, Math.min(root.effRadiusBL, badgeShape.width / 2, badgeShape.height / 2) - root.badgeStrokeInset)
                        direction: PathArc.Clockwise
                    }
                    PathLine { x: root.badgeStrokeInset; y: Math.min(root.effRadiusTL, badgeShape.width / 2, badgeShape.height / 2) + root.badgeStrokeInset }
                    PathArc {
                        x: Math.min(root.effRadiusTL, badgeShape.width / 2, badgeShape.height / 2) + root.badgeStrokeInset
                        y: root.badgeStrokeInset
                        radiusX: Math.max(0, Math.min(root.effRadiusTL, badgeShape.width / 2, badgeShape.height / 2) - root.badgeStrokeInset)
                        radiusY: Math.max(0, Math.min(root.effRadiusTL, badgeShape.width / 2, badgeShape.height / 2) - root.badgeStrokeInset)
                        direction: PathArc.Clockwise
                    }
                }
            }
        }

        // Configurable text outline. Qt's Text.Outline style is a fixed 1px
        // edge with no width control, so outlined mode renders 8 offset glyph
        // copies (compass directions, distance = outlineWidth) and then masks
        // the glyph itself out of them. The mask is inverted, so the copies
        // survive only OUTSIDE the glyph: the stroke is genuinely hollow, and a
        // transparent text fill (e.g. #RRGGBBAA with alpha 00) leaves just the
        // outline instead of a solid silhouette. With an opaque fill the look
        // is identical to a plain offset stroke, since the fill covers the
        // glyph area anyway. Fully declarative: width/font/colour update live.
        // Main text stays Normal to avoid a double edge.
        Item {
            id: textOutlineLayer
            x: textItem.x - root.outlineWidth
            y: textItem.y - root.outlineWidth
            width: textItem.width + root.outlineWidth * 2
            height: textItem.height + root.outlineWidth * 2
            visible: !root.fontSolid && root.outlineWidth > 0

            // The 8 offset copies. Hidden: only the effect below draws them.
            Item {
                id: textOutlineCopies
                anchors.fill: parent
                visible: false
                Repeater {
                    model: [{dx: 1, dy: 0}, {dx: -1, dy: 0}, {dx: 0, dy: 1}, {dx: 0, dy: -1},
                            {dx: 1, dy: 1}, {dx: 1, dy: -1}, {dx: -1, dy: 1}, {dx: -1, dy: -1}]
                    delegate: Text {
                        required property var modelData
                        x: root.outlineWidth + modelData.dx * root.outlineWidth
                        y: root.outlineWidth + modelData.dy * root.outlineWidth
                        width: textItem.width
                        height: textItem.height
                        text: root.displayText
                        color: root.resolveColorName(root.outlineColorName, Appearance.colors.colShadow)
                        opacity: root.textOpacity
                        font.family: root.resolvedFamily
                        font.pixelSize: root.effectiveFontSize
                        font.weight: root.fontWeight
                        font.letterSpacing: root.letterSpacing
                        font.italic: root.fontItalic
                        horizontalAlignment: textItem.horizontalAlignment
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        lineHeight: root.lineHeight
                        lineHeightMode: Text.ProportionalHeight
                        renderType: Text.NativeRendering
                    }
                }
            }

            // Mask: the un-offset glyph. Inverted in the effect so the copies
            // are clipped away wherever the glyph paints.
            Item {
                id: textOutlineMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Text {
                    x: root.outlineWidth
                    y: root.outlineWidth
                    width: textItem.width
                    height: textItem.height
                    text: root.displayText
                    color: "white"
                    font.family: root.resolvedFamily
                    font.pixelSize: root.effectiveFontSize
                    font.weight: root.fontWeight
                    font.letterSpacing: root.letterSpacing
                    font.italic: root.fontItalic
                    horizontalAlignment: textItem.horizontalAlignment
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    lineHeight: root.lineHeight
                    lineHeightMode: Text.ProportionalHeight
                    renderType: Text.NativeRendering
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: textOutlineCopies
                maskEnabled: true
                maskSource: textOutlineMask
                maskInverted: true
                autoPaddingEnabled: false
            }
        }

        Text {
            id: textItem
            x: root.badgeEnabled ? root.badgePadLeft : 0
            y: root.badgeEnabled ? root.badgePadTop : 0
            width: root.badgeEnabled ? contentItem.width - root.badgePadLeft - root.badgePadRight : textItem.implicitWidth
            text: root.displayText
            color: root.effectiveTextColor
            opacity: root.textOpacity
            font.family: root.resolvedFamily
            font.pixelSize: root.effectiveFontSize
            font.weight: root.fontWeight
            font.letterSpacing: root.letterSpacing
            font.italic: root.fontItalic
            style: Text.Normal
            horizontalAlignment: {
                switch (root.textAlignment) {
                case "left": return Text.AlignLeft
                case "center": return Text.AlignHCenter
                default: return Text.AlignRight
                }
            }
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            lineHeight: root.lineHeight
            lineHeightMode: Text.ProportionalHeight
            renderType: Text.NativeRendering
        }
    }

    transform: Rotation {
        origin.x: root.width / 2
        origin.y: root.height / 2
        angle: root.rotationDeg
    }
}
