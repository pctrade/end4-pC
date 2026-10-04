"""Run with python3 tests/media-cursor-check.py (installed Qt 6 development tools)."""
import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
media = (repo / 'modules/ii/bar/DiMedia.qml').read_text()
island = (repo / 'modules/ii/bar/DynamicIsland.qml').read_text()
controls = media[media.index('        RowLayout {\n            id: mediaControlsRow'):media.rindex('\n    }\n}')]
start = island.index('    MouseArea {', island.index('// Keep the original widgets loaded'))
blocker = island[start:island.index('\n    Loader {', start)]
qml = """import QtQuick
import QtQuick.Layouts
Window {
    id: root
    width: 300; height: 80; visible: true
    property bool sessionVisible: false
    property bool isMaterial: false
    property var activePlayer: ({canGoPrevious: true, canGoNext: true, isPlaying: true})
    QtObject { id: config; property var options: ({bar: {dynamicIsland: {showMediaControls: true}}}) }
    QtObject { id: appearance; property var colors: ({colOnLayer0: "white"}) }
    component MaterialSymbol: Text { property real fill; property real iconSize }
    CONTROLS
    BLOCKER
}
""".replace('CONTROLS', controls).replace('BLOCKER', blocker).replace('Config.', 'config.').replace('Appearance.', 'appearance.')
cpp = """#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QCursor>
#include <QTest>
int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine(QUrl::fromLocalFile(argv[1]));
    if (engine.rootObjects().isEmpty()) return 1;
    auto *window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
    QTest::qWait(100);
    for (int x : {249, 267, 285}) {
        QTest::mouseMove(window, QPoint(x, 40));
        QTest::qWait(30);
        if (window->cursor().shape() != Qt::PointingHandCursor) {
            qWarning("Unexpected cursor %d at x=%d", int(window->cursor().shape()), x);
            return 1;
        }
    }
    window->setProperty("sessionVisible", true);
    QTest::mouseMove(window, QPoint(268, 40));
    QTest::qWait(30);
    if (window->cursor().shape() != Qt::ArrowCursor) return 1;
    window->setProperty("sessionVisible", false);
    QTest::mouseMove(window, QPoint(267, 40));
    QTest::qWait(30);
    if (window->cursor().shape() != Qt::PointingHandCursor) return 1;
    qInfo("Previous/play/next window cursors and session overlay checks passed");
}
"""
with tempfile.TemporaryDirectory(prefix='media-cursor-check-') as directory:
    path = Path(directory)
    (path / 'check.qml').write_text(qml)
    (path / 'check.cpp').write_text(cpp)
    flags = subprocess.check_output(['pkg-config', '--cflags', '--libs', 'Qt6Quick', 'Qt6Test'], text=True).split()
    subprocess.run(['c++', '-std=c++17', '-fPIC', str(path / 'check.cpp'),
                    '-o', str(path / 'check'), *flags], check=True)
    subprocess.run([str(path / 'check'), str(path / 'check.qml')],
                   env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen',
                        'QT_QUICK_BACKEND': 'software', 'QT_QPA_PLATFORMTHEME': ''},
                   check=True, timeout=10)
