import QtQuick
import Qt5Compat.GraphicalEffects
import qs.modules.common

/*
 * True scene backdrop blur for desktop widget cards.
 *
 * Unlike the old wallpaper-sampled blur, this samples the ACTUAL scene
 * content physically beneath the card — the base wallpaper item plus the
 * depth wallpaper layer delegates below the widget's own slot — so it stays
 * correct with plain wallpapers AND depth wallpapers, with no mode
 * switching and nothing that can go stale.
 *
 * Why this cannot feed back: every sampled item is a sibling-or-uncle of
 * the widget (never an ancestor of this item). Hidden layers (depth OFF,
 * empty images) render nothing, so the same source list works in all
 * states. The card's own real-alpha fill stays underneath untouched, so
 * transparency keeps working even where blur shows nothing.
 */
Item {
    id: root

    // Ordered back-to-front scene items beneath the card:
    // [base wallpaper item, ...depth layer delegates below the widget].
    required property var backdropSources

    property real blurRadius: Config.options.background.widgets.blurRadius ?? 32
    property real cardRadius: 30
    property color tint: Appearance.colors.colLayer1
    property real tintOpacity: 0.55

    readonly property real oversample: root.blurRadius * 1.5

    Item {
        id: stack
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: stack.width
                height: stack.height
                radius: root.cardRadius
            }
        }

        Repeater {
            model: root.backdropSources
            delegate: FastBlur {
                x: -root.oversample
                y: -root.oversample
                width: root.width + root.oversample * 2
                height: root.height + root.oversample * 2
                radius: root.blurRadius
                transparentBorder: true
                visible: modelData && modelData.visible
                source: ShaderEffectSource {
                    sourceItem: modelData
                    sourceRect: {
                        if (!modelData) return Qt.rect(0, 0, 0, 0);
                        const pt = root.mapToItem(modelData, -root.oversample, -root.oversample);
                        return Qt.rect(pt.x, pt.y,
                            root.width + root.oversample * 2,
                            root.height + root.oversample * 2);
                    }
                    hideSource: false
                    live: true
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.cardRadius
            color: root.tint
            opacity: root.tintOpacity
        }
    }
}
