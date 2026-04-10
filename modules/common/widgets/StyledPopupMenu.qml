import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.common.widgets // Para las sombras y estilos

Item {
    id: root
    
    // Propiedades que recibe desde BarConfig.qml
    property alias model: repeater.model
    property var onItemSelected: (item) => {} 
    
    // Control de visibilidad
    property bool visible: false

    LazyLoader {
        id: loader
        active: root.visible // Solo carga la ventana cuando visible es true

        component: PanelWindow {
            id: popupWindow
            
            // Configuración de Wayland
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:popup"
            
            color: "transparent"
            mask: true
            
            // Dimensiones basadas en el contenido
            implicitWidth: container.implicitWidth + 40
            implicitHeight: container.implicitHeight + 40

            // Si el usuario hace clic fuera o la ventana pierde foco, cerramos
            onActiveChanged: {
                if (!active) root.visible = false
            }

            // Sombras usando tus widgets existentes
            StyledRectangularShadow {
                target: container
            }

            Rectangle {
                id: container
                anchors.centerIn: parent
                implicitWidth: 200 
                implicitHeight: layout.implicitHeight + 16
                
                radius: Appearance.rounding.normal
                color: Appearance.m3colors.m3surfaceContainer
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                ColumnLayout {
                    id: layout
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2

                    Repeater {
                        id: repeater
                        delegate: MouseArea {
                            Layout.fillWidth: true
                            implicitHeight: 40 
                            hoverEnabled: true
                            id: itemArea

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                color: itemArea.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.text || ""
                                font.family: Appearance.font.family.main
                                color: Appearance.m3colors.m3onSurface
                            }

                            onClicked: {
                                root.visible = false
                                root.onItemSelected(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}