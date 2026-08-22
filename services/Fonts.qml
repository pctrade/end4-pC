pragma Singleton

import Quickshell
import QtQuick

Singleton {
    property string iconMaterialFamily: materialSymbolsLoader.name

    FontLoader {
        id: materialSymbolsLoader
        source: Qt.resolvedUrl(`${Quickshell.shellPath("assets/fonts")}/MaterialSymbolsRounded.ttf`)
    }
}
