import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/*
 * The day in four steps, sunrise, midday, sunset and night, joined by a track
 * that fills as the day goes. The tile takes the color of the time of day, and
 * a ring around the current step shows how far into it we are.
 */
BentoTile {
    id: root
    required property var sunrise // Date
    required property var sunset // Date
    required property date now

    readonly property var midday: new Date((root.sunrise.getTime() + root.sunset.getTime()) / 2)
    readonly property bool beforeSunrise: root.now < root.sunrise
    readonly property bool afterSunset: root.now >= root.sunset
    readonly property bool night: root.beforeSunrise || root.afterSunset
    readonly property var nextSunrise: root.afterSunset ? new Date(root.sunrise.getTime() + 24 * 3600 * 1000) : root.sunrise

    readonly property string stageName: {
        if (root.night) return Translation.tr("Night");
        if (root.now < root.midday) return Translation.tr("Morning");
        return Translation.tr("Afternoon");
    }
    readonly property string countdown: root.night
        ? Translation.tr("Sunrise in %1").arg(root.formatDuration(root.nextSunrise - root.now))
        : Translation.tr("Sunset in %1").arg(root.formatDuration(root.sunset - root.now))

    function formatDuration(ms) {
        const minutes = Math.max(0, Math.round(ms / 60000));
        const hours = Math.floor(minutes / 60);
        return hours > 0 ? `${hours} h ${String(minutes % 60).padStart(2, "0")}` : `${minutes} min`;
    }
    function formatTime(d) {
        return Qt.locale().toString(d, Config.options?.time.format ?? "hh:mm");
    }
    function fraction(from, to) {
        return Math.max(0, Math.min(1, (root.now - from) / (to - from)));
    }

    readonly property var steps: [
        { icon: "wb_twilight", label: root.formatTime(root.sunrise), reached: !root.beforeSunrise, current: !root.night && root.now < root.midday },
        { icon: "clear_day", label: root.formatTime(root.midday), reached: !root.night && root.now >= root.midday, current: !root.night && root.now >= root.midday },
        { icon: "nights_stay", label: root.formatTime(root.sunset), reached: root.afterSunset, current: false },
        { icon: "bedtime", label: Translation.tr("Night"), reached: root.night, current: root.night }
    ]
    // How full each track between two steps is
    readonly property var previousSunset: root.afterSunset ? root.sunset : new Date(root.sunset.getTime() - 24 * 3600 * 1000)
    // How far into the current step
    readonly property real stageProgress: root.night ? root.fraction(root.previousSunset, root.nextSunrise)
        : root.now < root.midday ? root.tracks[0] : root.tracks[1]
    readonly property var tracks: [
        root.beforeSunrise ? 0 : root.fraction(root.sunrise, root.midday),
        root.beforeSunrise ? 0 : root.fraction(root.midday, root.sunset),
        root.afterSunset ? 1 : 0
    ]

    // Morning, afternoon and night each have their color
    readonly property color colStage: root.night ? Appearance.colors.colSurfaceContainer
        : root.now < root.midday ? Appearance.colors.colSecondaryContainer : Appearance.colors.colTertiaryContainer
    readonly property color colOnStage: root.night ? Appearance.colors.colOnSurface
        : root.now < root.midday ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnTertiaryContainer
    color: root.colStage
    Behavior on color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    implicitHeight: content.implicitHeight + 24

    ColumnLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 16
            rightMargin: 16
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: root.stageName
                color: root.colOnStage
                font {
                    family: "Google Sans Flex"
                    pixelSize: Appearance.font.pixelSize.huge
                    weight: 900
                    variableAxes: ({ "wght": 900 })
                }
            }
            Rectangle {
                implicitWidth: countdownText.implicitWidth + 20
                implicitHeight: countdownText.implicitHeight + 8
                radius: height / 2
                color: Appearance.colors.colPrimary
                StyledText {
                    id: countdownText
                    anchors.centerIn: parent
                    text: root.countdown
                    color: Appearance.colors.colOnPrimary
                    font {
                        pixelSize: Appearance.font.pixelSize.smaller
                        weight: 600
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.steps.length * 2 - 1
                delegate: Loader {
                    id: slot
                    required property int index
                    readonly property bool isStep: index % 2 === 0
                    Layout.fillWidth: !isStep
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: isStep ? 0 : 20
                    sourceComponent: isStep ? stepComponent : trackComponent

                    Component {
                        id: stepComponent
                        ColumnLayout {
                            id: stepItem
                            readonly property var step: root.steps[slot.index / 2]
                            spacing: 2
                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 44
                                implicitHeight: 44
                                CircularProgress {
                                    anchors.centerIn: parent
                                    visible: stepItem.step.current
                                    implicitSize: 44
                                    lineWidth: 3
                                    value: root.stageProgress
                                    colPrimary: Appearance.colors.colPrimary
                                    colSecondary: ColorUtils.transparentize(root.colOnStage, 0.8)
                                }
                                MaterialShapeWrappedMaterialSymbol {
                                    anchors.centerIn: parent
                                    shape: stepItem.step.current ? MaterialShape.Shape.Cookie9Sided : MaterialShape.Shape.Circle
                                    color: stepItem.step.reached ? Appearance.colors.colPrimary : ColorUtils.transparentize(root.colOnStage, 0.85)
                                    colSymbol: stepItem.step.reached ? Appearance.colors.colOnPrimary : root.colOnStage
                                    text: stepItem.step.icon
                                    fill: stepItem.step.reached ? 1 : 0
                                    iconSize: stepItem.step.current ? 18 : 16
                                    padding: 7
                                    implicitWidth: stepItem.step.current ? 34 : 30
                                    implicitHeight: stepItem.step.current ? 34 : 30
                                }
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: stepItem.step.label
                                color: root.colOnStage
                                opacity: stepItem.step.current ? 1 : 0.7
                                font {
                                    pixelSize: Appearance.font.pixelSize.smallest
                                    weight: stepItem.step.current ? 700 : 400
                                }
                            }
                        }
                    }

                    Component {
                        id: trackComponent
                        Rectangle {
                            readonly property real progress: root.tracks[(slot.index - 1) / 2]
                            implicitHeight: 4
                            radius: height / 2
                            color: ColorUtils.transparentize(root.colOnStage, 0.8)
                            Rectangle {
                                width: parent.width * parent.progress
                                height: parent.height
                                radius: height / 2
                                color: Appearance.colors.colPrimary
                                Behavior on width {
                                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
