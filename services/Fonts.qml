pragma Singleton

import Quickshell
import QtQml.Models
import QtQuick

Singleton {
    id: root
    property string iconMaterialFamily: materialSymbolsLoader.name

    // Bundled in assets/fonts/handwriting, used by the desktop text widget
    readonly property list<string> handwritingFamilies: ["Caveat", "Dancing Script", "Pacifico", "Indie Flower", "Great Vibes", "Permanent Marker", "Patrick Hand", "Kalam"]

    FontLoader {
        id: materialSymbolsLoader
        source: Qt.resolvedUrl(`${Quickshell.shellPath("assets/fonts")}/MaterialSymbolsRounded.ttf`)
    }

    Instantiator {
        model: ["Caveat", "DancingScript", "Pacifico", "IndieFlower", "GreatVibes", "PermanentMarker", "PatrickHand", "Kalam"]
        delegate: FontLoader {
            required property string modelData
            source: Qt.resolvedUrl(`${Quickshell.shellPath("assets/fonts/handwriting")}/${modelData}.ttf`)
        }
    }
}
