"""Run with python3 tests/activity-exit-check.py (Qt 6 QtTest required)."""
import os
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).resolve().parents[1] / 'modules/ii/bar/DynamicIsland.qml').read_text()
slot = source[source.index('    component ActivitySlot:'):source.index('    component SideWidgetDelegate:')]
start = source.index('        visible: contentAvailable || implicitWidth > 0.5')
delegate = source[start:source.index('        HoverHandler {', start)]
qml = """import QtQuick
import QtQuick.Layouts
import QtTest
Item {
    id: root
    width: 300; height: 80
    property real pillHeight: 32
    property bool componentInteractionReady: true
    property bool opened: false
    property string mode: "staged"
    QtObject { id: appearance
        property var animationCurves: ({expressiveDefaultSpatial: [0, 0, 0.2, 1, 1, 1]})
    }
    QtObject { id: config
        property var options: ({bar: {dynamicIsland: {animationStyle: root.mode}}})
    }
    SLOT
    Item {
        id: sideDelegate
        property string modelData: "activity"
        property bool contentAvailable: root.opened
        property real contentImplicitWidth: indicator.width
        property real contentImplicitHeight: root.pillHeight
        DELEGATE
        ActivitySlot {
            id: indicator
            shown: root.opened
            targetWidth: 132
            contentComponent: Rectangle { color: "white" }
        }
    }
    TestCase {
        name: "ActivityExit"
        when: windowShown
        function test_exit_data() {
            return [{tag: "staged", mode: "staged"}, {tag: "simultaneous", mode: "simultaneous"}]
        }
        function test_exit(data) {
            root.mode = data.mode
            root.opened = true
            tryCompare(indicator, "width", 132)
            compare(sideDelegate.implicitWidth, 132)
            root.opened = false
            compare(sideDelegate.implicitWidth, 132)
            wait(80)
            verify(indicator.width > 0 && indicator.width < 132)
            compare(sideDelegate.implicitWidth, indicator.width)
            compare(sideDelegate.visible, true)
            verify(indicator.opacity > 0 && indicator.opacity < 1)
            const closingWidth = indicator.width
            root.opened = true
            compare(sideDelegate.implicitWidth, closingWidth)
            tryCompare(indicator, "width", 132)
            root.opened = false
            tryCompare(indicator, "width", 0)
            compare(sideDelegate.implicitWidth, 0)
            compare(sideDelegate.visible, false)
            compare(indicator.visible, false)
        }
    }
}
""".replace('SLOT', slot).replace('DELEGATE', delegate).replace('Appearance.', 'appearance.').replace('Config.', 'config.')
with tempfile.TemporaryDirectory(prefix='activity-exit-check-') as directory:
    Path(directory, 'tst_exit.qml').write_text(qml)
    subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', directory],
                   env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'software',
                        'QT_QPA_PLATFORMTHEME': ''}, check=True, timeout=15)
