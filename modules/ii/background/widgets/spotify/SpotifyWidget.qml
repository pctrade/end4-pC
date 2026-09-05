pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "spotify"
    hoverEnabled: true

    readonly property real cardWidth: 320
    readonly property real cardHeight: 280

    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight

    property string mode: "player" // "player" | "playlists"

    // Search for Spotify player first, or fallback to active player
    readonly property var spotifyPlayer: {
        for (var i = 0; i < MprisController.players.length; i++) {
            var p = MprisController.players[i];
            if (p && ((p.identity && p.identity.toLowerCase().indexOf("spotify") !== -1) || 
                     (p.desktopEntry && p.desktopEntry.toLowerCase().indexOf("spotify") !== -1))) {
                return p;
            }
        }
        return MprisController.activePlayer;
    }

    readonly property bool isPlaying: spotifyPlayer && spotifyPlayer.playbackState === MprisPlaybackState.Playing
    readonly property string trackTitle: spotifyPlayer && spotifyPlayer.trackTitle ? spotifyPlayer.trackTitle : "Spotify"
    readonly property string trackArtist: spotifyPlayer && spotifyPlayer.trackArtist ? spotifyPlayer.trackArtist : (spotifyPlayer ? "Ready to play" : "Not running — click to start")
    readonly property string trackAlbum: spotifyPlayer && spotifyPlayer.trackAlbum ? spotifyPlayer.trackAlbum : ""
    readonly property string artUrl: spotifyPlayer && spotifyPlayer.trackArtUrl ? spotifyPlayer.trackArtUrl : ""

    readonly property real mediaProgress: {
        if (!spotifyPlayer || !spotifyPlayer.length || spotifyPlayer.length <= 0) return 0;
        return Math.max(0, Math.min(1, spotifyPlayer.position / spotifyPlayer.length));
    }

    function formatTime(seconds) {
        if (!seconds || isNaN(seconds) || seconds < 0) return "0:00";
        var m = Math.floor(seconds / 60);
        var s = Math.floor(seconds % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function toggleFlip() {
        flipAnim.start();
    }

    function launchSpotify() {
        Hyprland.dispatch("exec spotify || flatpak run com.spotify.Client || xdg-open https://open.spotify.com");
    }

    function playUri(uri) {
        Hyprland.dispatch("exec xdg-open " + uri);
    }

    Item {
        id: cardWrapper
        anchors.fill: parent

        transform: Scale {
            id: flipScale
            origin.x: cardWrapper.width / 2
            origin.y: cardWrapper.height / 2
            xScale: 1
        }

        SequentialAnimation {
            id: flipAnim
            NumberAnimation {
                target: flipScale
                property: "xScale"
                to: 0
                duration: 150
                easing.type: Easing.InQuad
            }
            ScriptAction {
                script: root.mode = (root.mode === "player" ? "playlists" : "player")
            }
            NumberAnimation {
                target: flipScale
                property: "xScale"
                to: 1
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        // Ambient Pulse Glow when playing
        Rectangle {
            id: glowEffect
            anchors.centerIn: parent
            width: parent.width + 14
            height: parent.height + 14
            radius: Appearance.rounding.verylarge || 32
            color: "#1DB954"
            opacity: root.isPlaying ? 0.25 : 0.05
            z: -1

            Behavior on opacity {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }
        }

        StyledDropShadow { target: contentRect }

        Rectangle {
            id: contentRect
            anchors.fill: parent
            color: Appearance.colors.colLayer0Base || Appearance.m3colors.m3surface || "#141414"
            radius: Appearance.rounding.verylarge || 28
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            clip: true

            // Glowing top gradient aura
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 100
                opacity: root.isPlaying ? 0.22 : 0.10
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#1DB954" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // ==========================================
            // FRONT VIEW: Player Deck
            // ==========================================
            ColumnLayout {
                id: playerView
                visible: root.mode === "player"
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // Header: Drag handle / Badge + Flip button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 13
                        color: "#1DB954"

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "graphic_eq"
                            iconSize: 16
                            color: "#FFFFFF"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: "SPOTIFY"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                            color: "#1DB954"
                        }

                        StyledText {
                            text: root.spotifyPlayer ? (root.spotifyPlayer.identity || "Local Player") : "Click to launch app"
                            font.pixelSize: 10
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Equalizer animation
                    RowLayout {
                        spacing: 2
                        visible: root.isPlaying
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                width: 3
                                height: 8 + Math.abs(Math.sin((Date.now() / 200) + index * 1.5)) * 10
                                radius: 1.5
                                color: "#1DB954"
                            }
                        }
                    }

                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colLayer1
                        onClicked: root.toggleFlip()

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "queue_music"
                            iconSize: 18
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledToolTip {
                            extraVisibleCondition: parent.hovered
                            alternativeVisibleCondition: parent.hovered
                            text: "Playlists & Liked Songs"
                        }
                    }
                }

                // Center: Big Album Art + Track Information
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Album Art
                    Rectangle {
                        implicitWidth: 78
                        implicitHeight: 78
                        radius: Appearance.rounding.small || 12
                        color: Appearance.colors.colLayer1
                        clip: true

                        Image {
                            id: albumImage
                            anchors.fill: parent
                            source: root.artUrl
                            fillMode: Image.PreserveAspectCrop
                            visible: root.artUrl.length > 0
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: !albumImage.visible || albumImage.status !== Image.Ready
                            text: "album"
                            iconSize: 44
                            color: Appearance.colors.colOnLayer1
                        }
                    }

                    // Track & Artist Info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: root.trackTitle
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnLayer0
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: root.trackArtist
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: root.trackAlbum
                            font.pixelSize: 10
                            color: Appearance.colors.colOnLayer1
                            opacity: 0.7
                            elide: Text.ElideRight
                            visible: root.trackAlbum.length > 0
                            Layout.fillWidth: true
                        }
                    }
                }

                // Interactive Progress Bar
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Appearance.colors.colLayer1

                        Rectangle {
                            height: parent.height
                            width: parent.width * root.mediaProgress
                            radius: 3
                            color: "#1DB954"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                if (root.spotifyPlayer && root.spotifyPlayer.length > 0) {
                                    var pos = (mouse.x / width) * root.spotifyPlayer.length;
                                    root.spotifyPlayer.position = pos;
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            text: root.spotifyPlayer ? root.formatTime(root.spotifyPlayer.position) : "0:00"
                            font.pixelSize: 10
                            color: Appearance.colors.colOnLayer1
                        }
                        Item { Layout.fillWidth: true }
                        StyledText {
                            text: root.spotifyPlayer ? root.formatTime(root.spotifyPlayer.length) : "0:00"
                            font.pixelSize: 10
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }

                // Playback Controls Row
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    // Liked Songs
                    RippleButton {
                        implicitWidth: 34
                        implicitHeight: 34
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        onClicked: root.playUri("spotify:collection:tracks")

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "favorite"
                            iconSize: 18
                            color: "#1DB954"
                        }
                        StyledToolTip {
                            extraVisibleCondition: parent.hovered
                            alternativeVisibleCondition: parent.hovered
                            text: "Play Liked Songs"
                        }
                    }

                    // Previous Track
                    RippleButton {
                        implicitWidth: 38
                        implicitHeight: 38
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colLayer1
                        onClicked: {
                            if (root.spotifyPlayer) root.spotifyPlayer.previous();
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "skip_previous"
                            iconSize: 22
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    // Main Play / Pause Button
                    RippleButton {
                        implicitWidth: 50
                        implicitHeight: 50
                        buttonRadius: Appearance.rounding.full
                        colBackground: "#1DB954"
                        onClicked: {
                            if (root.spotifyPlayer) {
                                root.spotifyPlayer.playPause();
                            } else {
                                root.launchSpotify();
                            }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.isPlaying ? "pause" : "play_arrow"
                            iconSize: 30
                            color: "#FFFFFF"
                        }
                    }

                    // Next Track
                    RippleButton {
                        implicitWidth: 38
                        implicitHeight: 38
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colLayer1
                        onClicked: {
                            if (root.spotifyPlayer) root.spotifyPlayer.next();
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "skip_next"
                            iconSize: 22
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    // Open / Focus Spotify App
                    RippleButton {
                        implicitWidth: 34
                        implicitHeight: 34
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        onClicked: root.launchSpotify()

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "open_in_new"
                            iconSize: 18
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledToolTip {
                            extraVisibleCondition: parent.hovered
                            alternativeVisibleCondition: parent.hovered
                            text: "Open / Focus Spotify"
                        }
                    }
                }
            }

            // ==========================================
            // BACK VIEW: Playlists, Liked Songs & Quick Jukebox
            // ==========================================
            ColumnLayout {
                id: playlistsView
                visible: root.mode === "playlists"
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RippleButton {
                        implicitWidth: 30
                        implicitHeight: 30
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colLayer1
                        onClicked: root.toggleFlip()

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "arrow_back"
                            iconSize: 18
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    StyledText {
                        text: "Playlists & Jukebox"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnLayer0
                        Layout.fillWidth: true
                    }

                    RippleButton {
                        implicitWidth: 30
                        implicitHeight: 30
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colLayer1
                        onClicked: root.launchSpotify()

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "open_in_new"
                            iconSize: 16
                            color: "#1DB954"
                        }
                    }
                }

                // Quick Play: Liked Songs Card
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: Appearance.rounding.small || 12
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#450af5" }
                        GradientStop { position: 1.0; color: "#8e8ee5" }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        MaterialSymbol {
                            text: "favorite"
                            iconSize: 22
                            color: "#FFFFFF"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: "Liked Songs"
                                font.weight: Font.Bold
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: "#FFFFFF"
                            }

                            StyledText {
                                text: "Your saved Spotify library"
                                font.pixelSize: 10
                                color: "#E0E0E0"
                            }
                        }

                        MaterialSymbol {
                            text: "play_circle"
                            iconSize: 26
                            color: "#FFFFFF"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.playUri("spotify:collection:tracks")
                    }
                }

                // Curated Mixes & Top Playlists
                StyledListView {
                    id: playlistList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6

                    model: [
                        { name: "Discover Weekly", subtitle: "Updated Mondays", icon: "auto_awesome", uri: "spotify:playlist:37i9dQZEVXcQ9JaJVQI8vd", color: "#1DB954" },
                        { name: "Daily Mix 1", subtitle: "Personalized for you", icon: "queue_music", uri: "spotify:station:user:daily-mix:1", color: "#E91E63" },
                        { name: "Release Radar", subtitle: "New releases", icon: "radar", uri: "spotify:playlist:37i9dQZEVXbo6nv60i6207", color: "#FF9800" },
                        { name: "Lofi Beats", subtitle: "Chill study & focus", icon: "headphones", uri: "spotify:playlist:37i9dQZF1DXdLEN7aqioXM", color: "#9C27B0" },
                        { name: "Top Gaming Tracks", subtitle: "High energy beats", icon: "sports_esports", uri: "spotify:playlist:37i9dQZF1DXdfO2leQ833Q", color: "#00BCD4" },
                        { name: "Deep Focus", subtitle: "Ambient coding sessions", icon: "code", uri: "spotify:playlist:37i9dQZF1DWZeKCadgRdKQ", color: "#4CAF50" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        width: playlistList.width
                        implicitHeight: 38
                        radius: Appearance.rounding.small || 8
                        color: playlistMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            MaterialSymbol {
                                text: modelData.icon
                                iconSize: 18
                                color: modelData.color
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    text: modelData.name
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: modelData.subtitle
                                    font.pixelSize: 9
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MaterialSymbol {
                                text: "play_arrow"
                                iconSize: 16
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        MouseArea {
                            id: playlistMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.playUri(modelData.uri)
                        }
                    }
                }
            }
        }
    }
}
