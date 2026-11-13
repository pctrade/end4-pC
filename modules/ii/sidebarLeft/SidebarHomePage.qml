import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    required property var pages
    property bool active: true
    signal pageRequested(string key)

    readonly property var liveMatches: Football.matches.filter(match => Football.isLiveish(match))
    readonly property var nextMatch: {
        const now = Date.now();
        const upcoming = Football.matches
            .filter(match => match.state === "pre" && new Date(match.date).getTime() > now)
            .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
        return upcoming.length > 0 ? upcoming[0] : null;
    }
    readonly property var player: MprisController.activePlayer

    function styleFor(key) {
        switch (key) {
        case "ai": return { shape: MaterialShape.Shape.Cookie9Sided, container: Appearance.colors.colTertiaryContainer, onContainer: Appearance.colors.colOnTertiaryContainer, accent: Appearance.colors.colTertiary, onAccent: Appearance.colors.colOnTertiary };
        case "translator": return { shape: MaterialShape.Shape.Clover4Leaf, container: Appearance.colors.colSecondaryContainer, onContainer: Appearance.colors.colOnSecondaryContainer, accent: Appearance.colors.colSecondary, onAccent: Appearance.colors.colOnSecondary };
        case "media": return { shape: MaterialShape.Shape.Sunny, container: Appearance.colors.colPrimaryContainer, onContainer: Appearance.colors.colOnPrimaryContainer, accent: Appearance.colors.colPrimary, onAccent: Appearance.colors.colOnPrimary };
        case "apps": return { shape: MaterialShape.Shape.Pill, container: Appearance.colors.colPrimaryContainer, onContainer: Appearance.colors.colOnPrimaryContainer, accent: Appearance.colors.colPrimary, onAccent: Appearance.colors.colOnPrimary };
        case "sports": return { shape: MaterialShape.Shape.Flower, container: Appearance.colors.colTertiaryContainer, onContainer: Appearance.colors.colOnTertiaryContainer, accent: Appearance.colors.colTertiary, onAccent: Appearance.colors.colOnTertiary };
        default: return { shape: MaterialShape.Shape.Cookie6Sided, container: Appearance.colors.colSecondaryContainer, onContainer: Appearance.colors.colOnSecondaryContainer, accent: Appearance.colors.colSecondary, onAccent: Appearance.colors.colOnSecondary };
        }
    }

    function subtitleFor(key) {
        switch (key) {
        case "ai": {
            const name = Ai.models[Ai.currentModelId]?.name ?? "";
            const count = Ai.messageIDs.length;
            return count > 0 ? `${name} · ${Translation.tr("%1 messages").arg(count)}` : name;
        }
        case "apps":
            return Translation.tr("%1 installed").arg(AppSearch.list.length);
        case "translator":
            return Translation.tr("Translate text");
        case "media":
            return root.player ? `${root.player.trackTitle || Translation.tr("Unknown Title")} · ${root.player.trackArtist || Translation.tr("Unknown Artist")}` : Translation.tr("Nothing playing");
        case "sports":
            if (root.liveMatches.length > 0) return Translation.tr("%1 live now").arg(root.liveMatches.length);
            if (root.nextMatch) return `${root.nextMatch.home.name} – ${root.nextMatch.away.name} · ${Qt.formatDateTime(new Date(root.nextMatch.date), "ddd HH:mm")}`;
            return Translation.tr("No matches");
        case "anime":
            return Translation.tr("Browse images");
        default:
            return "";
        }
    }

    function isLive(key) {
        if (key === "media") return root.player?.isPlaying ?? false;
        if (key === "sports") return root.liveMatches.length > 0;
        return false;
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.height + 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: column
            x: 10
            y: 10
            width: flick.width - 20
            height: Math.max(implicitHeight, flick.height - 20)
            spacing: 10

            SidebarPop {
                id: clockCard
                Layout.fillWidth: true
                implicitHeight: 176
                active: root.active
                animIndex: 3
                travelX: 300
                travelY: -120

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.large
                    color: Appearance.colors.colPrimaryContainer

                    Item {
                        anchors.fill: parent

                        MaterialShape {
                            id: sunShape
                            shape: MaterialShape.Shape.Sunny
                            implicitSize: 190
                            color: Appearance.colors.colPrimary
                            anchors.right: parent.right
                            anchors.rightMargin: -sunShape.implicitSize * 0.3
                            anchors.top: parent.top
                            anchors.topMargin: -sunShape.implicitSize * 0.15
                        }

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 16
                            spacing: 0

                            StyledText {
                                text: Qt.locale().toString(DateTime.clock.date, "dddd MMMM d")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                text: DateTime.use12HourFormat ? DateTime.time.replace(/\s*[ap]\.?\s?m\.?\s*$/i, "") : DateTime.time
                                color: Appearance.colors.colOnPrimaryContainer
                                font {
                                    pixelSize: 56
                                    weight: Config.options.background.widgets.clock.digital.font.weight
                                    family: Config.options.background.widgets.clock.digital.font.family
                                    variableAxes: ({
                                        "wdth": Config.options.background.widgets.clock.digital.font.width,
                                        "ROND": Config.options.background.widgets.clock.digital.font.roundness
                                    })
                                }
                            }

                            StyledText {
                                Layout.topMargin: -10
                                visible: DateTime.use12HourFormat
                                text: Qt.locale().toString(DateTime.clock.date, "AP")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: Appearance.colors.colPrimary
                            }
                        }

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 16
                            spacing: 0

                            StyledText {
                                text: Weather.data.city
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnPrimaryContainer
                            }

                            StyledText {
                                text: [Weather.data.temp, Weather.data.description].filter(part => part && part.length > 0).join(" · ")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.7
                            }
                        }
                    }
                }
            }

            GridLayout {
                id: cardGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: 10
                columnSpacing: 10

                Repeater {
                    model: root.pages
                    delegate: SidebarHomeCard {
                        id: homeCard
                        required property var modelData
                        required property int index

                        readonly property var look: root.styleFor(modelData.key)
                        readonly property bool lastOdd: index === root.pages.length - 1 && root.pages.length % 2 === 1

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 112
                        Layout.columnSpan: lastOdd ? 2 : 1
                        Layout.preferredWidth: 1

                        icon: modelData.icon
                        title: modelData.name
                        subtitle: root.subtitleFor(modelData.key)
                        live: root.isLive(modelData.key)
                        decoShape: look.shape
                        colContainer: look.container
                        colOnContainer: look.onContainer
                        colAccent: look.accent
                        colOnAccent: look.onAccent
                        active: root.active
                        animIndex: 4 + index
                        travelX: index % 2 === 0 ? -260 : 260
                        travelY: ((index * 37) % 5 - 2) * 70
                        onClicked: root.pageRequested(modelData.key)
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: root.pages.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Enable features in Settings to see them here")
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }
        }
    }
}
