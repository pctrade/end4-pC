import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: xa
    required property Item di
    spacing: 10
    implicitWidth: 340
    // Layouts overwrite implicitWidth with their children's; the container reads this instead
    readonly property real wantedWidth: 340

    readonly property bool brightnessMode: xa.di.expandedId === "osd" && GlobalStates.osdIndicatorType === "brightness"
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(xa.focusedScreen)
    readonly property real brightnessValue: IslandEvents.realBrightness >= 0 ? IslandEvents.realBrightness : (xa.brightnessMonitor?.brightness ?? 0)
    readonly property real volumeMax: xa.di.cfg.volumeMax ?? 1.5
    readonly property bool boosted: !xa.brightnessMode && Audio.value > 1.005

    Component.onCompleted: IslandEvents.refreshAudioProfiles()

    Binding {
        target: IslandEvents
        property: "brightnessWatch"
        value: true
        when: xa.brightnessMode
        restoreMode: Binding.RestoreValue
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MaterialSymbol {
            text: xa.brightnessMode ? "light_mode" : ((Audio.sink?.audio?.muted ?? false) ? "volume_off" : "volume_up")
            iconSize: 20
            fill: 1
            color: Appearance.colors.colPrimary

            MouseArea {
                anchors.fill: parent
                enabled: !xa.brightnessMode
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.toggleMute()
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: xa.brightnessMode ? Translation.tr("Brightness") : Translation.tr("Volume")
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
        }
        StyledText {
            text: `${Math.round((xa.brightnessMode ? xa.brightnessValue : Audio.value) * 100)}%`
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: xa.boosted ? Font.DemiBold : Font.Normal
            font.features: { "tnum": 1 }
            color: xa.boosted ? IslandEvents.colorAttention : Appearance.colors.colOnLayer0
        }
    }

    StyledSlider {
        Layout.fillWidth: true
        from: 0
        to: xa.brightnessMode ? 1 : xa.volumeMax
        value: xa.brightnessMode ? xa.brightnessValue : Audio.value
        highlightColor: xa.boosted ? IslandEvents.colorAttention : Appearance.colors.colPrimary
        handleColor: xa.boosted ? IslandEvents.colorAttention : Appearance.colors.colPrimary
        onMoved: {
            if (xa.brightnessMode) xa.brightnessMonitor?.setBrightness(value)
            else if (Audio.sink?.audio) Audio.sink.audio.volume = value
        }
    }

    StyledText {
        visible: !xa.brightnessMode
        text: Translation.tr("Output")
        font.pixelSize: Appearance.font.pixelSize.smallest
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    Repeater {
        model: xa.brightnessMode ? [] : Audio.outputDevices
        delegate: Rectangle {
            id: deviceRow
            required property var modelData
            readonly property bool current: deviceRow.modelData === Audio.sink
            Layout.fillWidth: true
            implicitHeight: 36
            radius: 12
            color: deviceRow.current ? Appearance.colors.colPrimaryContainer
                : (deviceMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1)

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 8

                MaterialSymbol {
                    text: IslandEvents.sinkIcon(deviceRow.modelData)
                    iconSize: 18
                    fill: 1
                    color: deviceRow.current ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                }
                StyledText {
                    Layout.fillWidth: true
                    text: IslandEvents.shortName(Audio.friendlyDeviceName(deviceRow.modelData))
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: deviceRow.current ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }
                MaterialSymbol {
                    visible: deviceRow.current
                    text: "check"
                    iconSize: 18
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }

            MouseArea {
                id: deviceMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.setDefaultSink(deviceRow.modelData)
            }
        }
    }

    // Outputs that are not devices right now, because the card is in another profile. Selecting one switches
    // the profile — which is the only way back to the laptop speakers once a monitor took the card over.
    Repeater {
        model: xa.brightnessMode ? [] : IslandEvents.audioProfiles.filter(p => !p.active)

        delegate: Rectangle {
            id: profileRow
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 38
            radius: 12
            color: profileMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

            Behavior on color {
                ColorAnimation { duration: 140 }
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 8

                MaterialSymbol {
                    text: profileRow.modelData.hdmi ? "tv" : "speaker"
                    iconSize: 18
                    fill: 1
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
                }
                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: profileRow.modelData.description
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
                    elide: Text.ElideRight
                }
                StyledText {
                    text: Translation.tr("switch")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colPrimary
                }
            }

            MouseArea {
                id: profileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: IslandEvents.setAudioProfile(profileRow.modelData)
            }
        }
    }

    // Per-app volume: turning the video down without turning the call down
    StyledText {
        visible: !xa.brightnessMode && IslandEvents.audioStreams.length > 0
        text: Translation.tr("Apps")
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    Repeater {
        model: xa.brightnessMode ? [] : IslandEvents.audioStreams

        delegate: RowLayout {
            id: streamRow
            required property var modelData
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: streamRow.modelData.muted ? "volume_off" : "graphic_eq"
                iconSize: 16
                fill: 1
                color: streamRow.modelData.muted ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                opacity: streamRow.modelData.muted ? 1 : 0.8

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: IslandEvents.toggleStreamMute(streamRow.modelData.node)
                }
            }

            StyledText {
                Layout.preferredWidth: 96
                Layout.minimumWidth: 0
                text: streamRow.modelData.name
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer0
                opacity: streamRow.modelData.muted ? 0.5 : 1
                elide: Text.ElideRight
            }

            StyledSlider {
                Layout.fillWidth: true
                value: streamRow.modelData.volume
                from: 0
                to: 1
                onMoved: IslandEvents.setStreamVolume(streamRow.modelData.node, value)
            }

            StyledText {
                text: `${Math.round(streamRow.modelData.volume * 100)}%`
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
                opacity: 0.7
            }
        }
    }
}
