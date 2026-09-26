import QtQuick

// The island's single entrance motion: fade in while growing from slightly small, with a soft settle
ParallelAnimation {
    id: entrance
    required property Item target
    property int delay: 60
    running: true

    SequentialAnimation {
        PropertyAction { target: entrance.target; property: "opacity"; value: 0 }
        PauseAnimation { duration: entrance.delay }
        NumberAnimation { target: entrance.target; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        PropertyAction { target: entrance.target; property: "scale"; value: 0.82 }
        PauseAnimation { duration: entrance.delay }
        NumberAnimation { target: entrance.target; property: "scale"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
    }
}
