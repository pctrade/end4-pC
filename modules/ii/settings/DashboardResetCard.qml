import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    property string title: ""
    property string icon: "restart_alt"
    property var override: null

    tint: Appearance.colors.colLayer1

    RowLayout {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 14
        }
        spacing: 12

        MaterialShapeWrappedMaterialSymbol {
            shape: MaterialShape.Shape.Cookie6Sided
            text: root.icon
            iconSize: 24
            fill: 1
            padding: 10
            color: Appearance.colors.colSecondary
            colSymbol: Appearance.colors.colOnSecondary
        }

        StyledText {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: Appearance.font.pixelSize.larger
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer1
            elide: Text.ElideRight
        }
    }

    RippleButton {
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 14
        }
        implicitHeight: 38
        implicitWidth: 120
        buttonRadius: 19
        colBackground: Appearance.colors.colSecondaryContainer
        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
        colRipple: Appearance.colors.colSecondaryContainerActive
        downAction: () => root.override?.run()

        contentItem: StyledText {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: Translation.tr("Reset")
            color: Appearance.colors.colOnSecondaryContainer
        }
    }
}
