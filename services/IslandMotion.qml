pragma Singleton

import QtQuick
import Quickshell

/**
 * Motion tokens for the Dynamic Island. Four speeds, one job each:
 *
 *   micro  150  hover, press, colour and small opacity flips
 *   short  220  a control changing state: toggles, chips, a row arming
 *   medium 320  content swapping or sliding: a line rising in, a list refilling
 *   long   460  size and layout: the island widening, a card growing
 *
 */
Singleton {
    readonly property int micro: 150
    readonly property int short: 220
    readonly property int medium: 320
    readonly property int long: 460

    // Springs for the expanded island's own shape (stiffness + damping ratio, see DiSpring.qml)
    readonly property var springOpen: ({ stiffness: 320, dampingRatio: 0.8 })
    readonly property var springResize: ({ stiffness: 380, dampingRatio: 0.86 })
    readonly property var springClose: ({ stiffness: 520, dampingRatio: 1 })
}
