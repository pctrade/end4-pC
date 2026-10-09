pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitHeight: col.implicitHeight + 16

    readonly property var widgetList: DesktopWidgets.menuItems

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.verylarge
        color: Appearance.colors.colUiBackground
    }

    ColumnLayout {
        id: col
        anchors { fill: parent; margins: 8 }
        spacing: 2

        ConfigSwitch {
            Layout.fillWidth: true
            buttonIcon: "lock"
            text: Translation.tr("Lock widget positions")
            checked: Config.options.background.widgetsLocked
            onCheckedChanged: Config.options.background.widgetsLocked = checked
        }
        ConfigSwitch {
            Layout.fillWidth: true
            buttonIcon: "shadow"
            text: Translation.tr("Shadow")
            checked: Config.options.background.widgets.shadow 
            onCheckedChanged: Config.options.background.widgets.shadow = checked
        }
        ConfigSwitch {
            Layout.fillWidth: true
            buttonIcon: "blur_on"
            text: Translation.tr("Blur widgets")
            checked: Config.options.background.widgets.blurWidgets 
            onCheckedChanged: Config.options.background.widgets.blurWidgets = checked
        }

        ConfigSlider {
            Layout.fillWidth: true
            showLabel: false
            visible: Config.options.background.widgets.blurWidgets
            value: Config.options.background.widgets.blurRadius ?? 32
            usePercentTooltip: false
            buttonIcon: "aspect_ratio"
            from: 1
            to: 64
            stopIndicatorValues: [32]
            onValueChanged: Config.options.background.widgets.blurRadius = value
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            implicitHeight: 1
            color: Appearance.colors.colOutlineVariant
            opacity: 0.4
        }

        Repeater {
            model: root.widgetList
            delegate: ConfigSwitch {
                required property var modelData
                Layout.fillWidth: true
                buttonIcon: modelData.icon
                text: modelData.name
                checked: Config.options.background.widgets[modelData.key].enable
                onCheckedChanged: Config.options.background.widgets[modelData.key].enable = checked
            }
        }
    }
}
