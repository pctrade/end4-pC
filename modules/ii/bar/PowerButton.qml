import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: loader.implicitWidth
    implicitHeight: loader.implicitHeight

    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: isMaterial ? materialStyle : defaultStyle
    }

    Component {
        id: defaultStyle
        RippleButton {
            property real buttonPadding: 5
            implicitWidth: Config.options.bar.cornerStyle === 2 ? 27 : 27 + buttonPadding
            implicitHeight: Config.options.bar.cornerStyle === 2 ? 27 : 27 + buttonPadding
            buttonRadius: Appearance.rounding.full
            colBackgroundHover: Appearance.colors.colLayer1Hover
            colRipple: Appearance.colors.colLayer1Active
            onPressed: {
                GlobalStates.sessionOpen = !GlobalStates.sessionOpen
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: "power_settings_new"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer0
            }
        }
    }

    Component {
        id: materialStyle
        RippleButton {
            implicitWidth: 30
            implicitHeight: 30
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            colRipple: Appearance.colors.colPrimaryActive
            onPressed: {
                GlobalStates.sessionOpen = !GlobalStates.sessionOpen
            }

            MaterialShapeWrappedMaterialSymbol {
                anchors.centerIn: parent
                text: "power_settings_new"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnPrimary
                colSymbol: Appearance.colors.colPrimary
                wrappedShape: MaterialShape.Shape.Cookie12Sided
                padding: 2
            }
        }
    }
}