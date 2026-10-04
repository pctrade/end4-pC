"""Run with python3 tests/session-animation-check.py (Qt 6 QML runtime required)."""
import os
import re
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).resolve().parents[1] / 'modules/ii/bar/DynamicIsland.qml').read_text()
start = source.index('    property real sessionOpacity:')
state = source[start:source.index('    readonly property string centerWidget:', start)]
state = state.replace('GlobalStates.diSessionOpen', 'root.opened').replace('Config.options', 'root.config')
start = source.index('                opacity: root.sessionOpacity', source.index('id: sessionComponent'))
visual = source[start:source.index('                DiSession', start)].replace('GlobalStates.diSessionOpen', 'root.opened')
geometry = source[source.index('    readonly property real leftContentWidth:'):source.index('    HoverHandler { id: islandHover }')]
center_x = re.search(r'id: centerLoader\s+active: [^\n]+\s+x: ([\s\S]*?)\n        anchors', source)[1]
qml = '''import QtQuick
import QtQuick.Window
Window {
    width: 240; height: 80; visible: true
    Item {
        id: root
        width: implicitWidth; height: 40
        property bool centerEnabled: true
        property real primaryWidth: 0
        property real sessionWidth: 164
        property real pillHeight: 40
        property real contentPadding: 8
        property real widgetSpacing: 8
        property real maxLeftExtent: 120
        property real maxRightExtent: 600
        QtObject { id: leftWidgets; property real implicitWidth: 90 }
        QtObject { id: rightWidgets; property real implicitWidth: 260 }
        QtObject { id: centerLoader; property real implicitWidth: 100; property real x: CENTER_X }
        GEOMETRY
        property bool opened: false
        property bool vertical: false
        property var config: ({bar: {dynamicIsland: {centerEnabled: true,
            centerWidget: "workspaces", sessionMenuMode: "MODE"}}})
        STATE
        Loader {
            id: menu
            active: root.sessionReplacesCenter || root.sessionExclusive
            sourceComponent: Item { width: 164; height: 40; VISUAL }
        }
        function check(condition, message) {
            if (!condition) { console.error(message); Qt.exit(1) }
        }
        Timer {
            interval: 100; repeat: true; running: true
            property int tick: 0
            property real initialWidth: 0
            onTriggered: {
                switch (tick++) {
                case 0:
                    root.check(!menu.active, "Menu must start unloaded")
                    initialWidth = root.width
                    root.opened = true
                    break
                case 1:
                    root.check(menu.item && menu.item.opacity > 0 && menu.item.opacity < 1, "Entry must animate")
                    root.check(root.width !== initialWidth, "Island geometry must animate with entry")
                    root.check(Math.abs(root.barCenterOffset - root.width / 2 + centerLoader.x + 50) < 0.001,
                        "Centered widget must stay fixed while fading")
                    root.check(root.sessionReplacesCenter === ("MODE" === "replaceWorkspaces"), "Correct replacement mode")
                    break
                case 4:
                    root.check(menu.item.opacity === 1 && menu.item.scale === 1, "Entry must finish")
                    root.check("MODE" === "exclusive" ? root.width === 180 : root.centerHalfWidth === 82, "Island must reach menu geometry")
                    root.opened = false
                    break
                case 5:
                    root.check(menu.active && menu.item.opacity > 0 && menu.item.opacity < 1, "Exit must retain the menu")
                    root.check(!menu.item.enabled, "Closing actions must be disabled")
                    root.opened = true
                    break
                case 9:
                    root.check(menu.active && menu.item.opacity === 1, "Reopening must cancel exit")
                    root.opened = false
                    break
                case 13:
                    root.check(!menu.active && !menu.item, "Menu must unload after exit")
                    root.check(root.width === initialWidth, "Exit must restore island geometry")
                    console.log("Session animation checks passed: MODE")
                    Qt.quit()
                }
            }
        }
    }
}
'''.replace('CENTER_X', center_x.replace('implicitWidth', 'centerLoader.implicitWidth')).replace('GEOMETRY', geometry).replace('STATE', state).replace('VISUAL', visual)
with tempfile.TemporaryDirectory(prefix='session-animation-check-') as directory:
    for mode in ['replaceWorkspaces', 'exclusive']:
        path = Path(directory, 'check.qml')
        path.write_text(qml.replace('MODE', mode))
        result = subprocess.run(['/usr/lib/qt6/bin/qml', str(path)],
            env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'software',
                 'QT_QPA_PLATFORMTHEME': '', 'QT_LOGGING_RULES': 'qml.debug=true;qml.warning=true'}, capture_output=True, text=True, timeout=10)
        assert result.returncode == 0, result.stdout + result.stderr
        print(f'Session animation checks passed: {mode}')
