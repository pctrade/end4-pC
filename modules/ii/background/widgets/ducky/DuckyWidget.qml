import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "ducky"
    hoverEnabled: true

    property string sizeMode: root.configEntry.sizeMode ?? "2x2"

    implicitWidth: sizeMode === "1x4" ? 380 : 260
    implicitHeight: sizeMode === "1x4" ? 130 : 255

    Behavior on implicitWidth {
        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
    }

    property int petCount: 0

    readonly property string speechText: {
        const level = Math.round(ResourceUsage.memoryUsedPercentage * 100);
        return "Headache level: " + level + "% 🧠";
    }

    function triggerPet() {
        petCount++;
        if (Persistent.states.ducky) {
            Persistent.states.ducky.petCount = petCount;
        }

        // Restart 3-minute (180s) inactivity timer
        petInactivityTimer.restart();

        // Flash screen text "u are the duck" when petCount hits 100 (or multiples of 100)
        if (petCount > 0 && petCount % 100 === 0) {
            flashOverlayTimer.restart();
        }

        // Smooth bounce animation
        avatarScaleAnim.restart();
        avatarWobbleAnim.restart();

        // Spawn heart particle
        spawnHeartParticle();
    }

    function spawnHeartParticle() {
        const emojis = ["💖", "✨", "⭐", "🐤", "💛", "🧠"];
        const emoji = emojis[Math.floor(Math.random() * emojis.length)];
        const rx = (Math.random() - 0.5) * 60;
        particleModel.append({
            id: Date.now() + Math.random(),
            emojiText: emoji,
            startX: rx
        });
    }

    // 3-Minute (180,000 ms) Inactivity Timer to clear tap count and hide badge
    Timer {
        id: petInactivityTimer
        interval: 180000
        repeat: false
        running: false
        onTriggered: {
            root.petCount = 0;
            if (Persistent.states.ducky) {
                Persistent.states.ducky.petCount = 0;
            }
        }
    }

    ListModel {
        id: particleModel
    }

    // 100-Tap Easter Egg Fullscreen Overlay: "u are the duck"
    PanelWindow {
        id: flashWindow
        visible: flashOverlayTimer.running
        color: "#e6000000"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Item {
            anchors.centerIn: parent

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20

                StyledText {
                    text: "u are the duck"
                    font.pixelSize: 68
                    font.weight: Font.Black
                    color: Appearance.colors.colPrimary
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    text: "~ Shivangi"
                    font.pixelSize: 44
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Timer {
        id: flashOverlayTimer
        interval: 3200
        repeat: false
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Appearance.rounding?.verylarge ?? 28
        color: Appearance.colors.colPrimaryContainer

        StyledRectangularShadow {
            target: card
            z: -2
        }

        // Particle Emitter Container
        Item {
            id: particleContainer
            anchors.fill: parent
            z: 20

            Repeater {
                model: particleModel
                delegate: Item {
                    id: pItem
                    required property int index
                    required property string emojiText
                    required property real startX

                    x: parent.width / 2 + startX
                    y: parent.height / 2

                    StyledText {
                        text: emojiText
                        font.pixelSize: 18
                        anchors.centerIn: parent
                    }

                    ParallelAnimation {
                        running: true
                        NumberAnimation {
                            target: pItem
                            property: "y"
                            from: parent.height / 2
                            to: parent.height / 2 - 80
                            duration: 800
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: pItem
                            property: "opacity"
                            from: 1.0
                            to: 0.0
                            duration: 800
                            easing.type: Easing.InQuad
                        }
                        onFinished: {
                            if (index >= 0 && index < particleModel.count) {
                                particleModel.remove(index);
                            }
                        }
                    }
                }
            }
        }

        // Main Layout 2x2
        ColumnLayout {
            visible: root.sizeMode === "2x2"
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 8

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialShapeWrappedMaterialSymbol {
                    wrappedShape: MaterialShape.Shape.Cookie4Sided
                    color: Appearance.colors.colPrimary
                    colSymbol: Appearance.colors.colOnPrimary
                    text: "pets"
                    iconSize: 18
                    fill: 1
                    padding: 4
                    implicitWidth: 28
                    implicitHeight: 28
                }

                ColumnLayout {
                    spacing: -2
                    Layout.fillWidth: true

                    StyledText {
                        text: "Buffer ducky"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimaryContainer
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: "Buffer Buddy 🐣"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                // Pet Counter Badge (Hidden when not in active use: root.petCount > 0 && petInactivityTimer.running)
                Rectangle {
                    radius: 12
                    color: Appearance.colors.colPrimary
                    implicitWidth: petRow.implicitWidth + 12
                    implicitHeight: 22
                    visible: root.petCount > 0 && petInactivityTimer.running

                    RowLayout {
                        id: petRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: "favorite"
                            iconSize: 11
                            color: Appearance.colors.colOnPrimary
                        }

                        StyledText {
                            text: root.petCount.toString()
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }

            // Speech Bubble (Displays constant Headache level)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 28
                radius: 14
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                StyledText {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    text: root.speechText
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer0
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }

            // Central Continuous Animated Psyduck Avatar Canvas
            Item {
                id: avatarCanvas
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.triggerPet()
                }

                // Continuous Animated Psyduck Image from ~/Downloads/psyduck.gif
                AnimatedImage {
                    id: duckyImage
                    anchors.centerIn: parent
                    source: "assets/psyduck.gif"
                    width: 175
                    height: 175
                    playing: true
                    fillMode: Image.PreserveAspectFit
                    smooth: true

                    // Position Offset for Idle Bobbing
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2 + idleBobbing.bobY

                    scale: transformItem.customScale
                    rotation: transformItem.customRotation

                    Item {
                        id: transformItem
                        property real customScale: 1.0
                        property real customRotation: 0
                    }

                    // Smooth Idle Bobbing Motion
                    Item {
                        id: idleBobbing
                        property real bobY: 0
                        SequentialAnimation on bobY {
                            running: true
                            loops: Animation.Infinite
                            NumberAnimation { from: -3; to: 3; duration: 1400; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 3; to: -3; duration: 1400; easing.type: Easing.InOutSine }
                        }
                    }

                    // Bounce & Wobble Physics Animations
                    NumberAnimation {
                        id: avatarScaleAnim
                        target: transformItem
                        property: "customScale"
                        from: 1.25
                        to: 1.0
                        duration: 350
                        easing.type: Easing.OutBack
                    }
                    SequentialAnimation {
                        id: avatarWobbleAnim
                        NumberAnimation { target: transformItem; property: "customRotation"; from: -10; to: 10; duration: 80 }
                        NumberAnimation { target: transformItem; property: "customRotation"; from: 10; to: -5; duration: 80 }
                        NumberAnimation { target: transformItem; property: "customRotation"; from: -5; to: 0; duration: 80 }
                    }
                }
            }
        }

        // Layout 1x4 Compact Horizontal Mode
        RowLayout {
            visible: root.sizeMode === "1x4"
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 12

            // Left Avatar
            Item {
                width: 90
                height: 90
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.triggerPet()
                }

                AnimatedImage {
                    anchors.centerIn: parent
                    source: "assets/psyduck.gif"
                    width: 76; height: 76
                    playing: true
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }

            // Right Info & Actions
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: "Buffer ducky"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    Item { Layout.fillWidth: true }

                    // Pet counter in 1x4 (Hidden when not in active use)
                    RowLayout {
                        spacing: 4
                        visible: root.petCount > 0 && petInactivityTimer.running

                        MaterialSymbol {
                            text: "favorite"
                            iconSize: 11
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: root.petCount.toString()
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Appearance.colors.colPrimary
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 24
                    radius: 12
                    color: Appearance.colors.colLayer0

                    StyledText {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        text: root.speechText
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer0
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Resize Handle in bottom right corner
        Rectangle {
            id: resizeHandle
            width: 14; height: 14; radius: 3
            color: Appearance.colors.colOnPrimaryContainer
            anchors { right: card.right; bottom: card.bottom; margins: 4 }
            opacity: (root.containsMouse || resizeArea.containsMouse || resizeArea.pressed) ? 0.4 : 0
            visible: opacity > 0 && !Config.options.background.widgetsLocked
            Behavior on opacity { NumberAnimation { duration: 150 } }

            MouseArea {
                id: resizeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                preventStealing: true
                property real startWidth: 0
                property real startX: 0
                onPressed: (mouse) => {
                    startWidth = root.width
                    startX = mapToItem(null, mouse.x, mouse.y).x
                }
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    var globalX = mapToItem(null, mouse.x, mouse.y).x
                    var dx = globalX - startX
                    var newW = startWidth + dx

                    if (newW > 330) {
                        root.sizeMode = "1x4"
                    } else {
                        root.sizeMode = "2x2"
                    }
                }
                onReleased: {
                    root.configEntry.sizeMode = root.sizeMode
                }
            }
        }
    }
}
