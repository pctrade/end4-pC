

import qs.services  
import qs.modules.common  
import qs.modules.common.widgets  
import qs.modules.common.functions  
import QtQuick  
import QtQuick.Controls  
import QtQuick.Layouts  
import Quickshell  
  
Rectangle {  
    id: root  
    property int messageIndex  
    property var messageData  
    property var messageInputField  
  
    property real messagePadding: 7  
    property real contentSpacing: 3  
  
    anchors.left: parent?.left  
    anchors.right: parent?.right  
    implicitHeight: columnLayout.implicitHeight + root.messagePadding * 2  
  
    radius: Appearance.rounding.normal  
    color: Appearance.colors.colLayer1  
  
    ColumnLayout {  
        id: columnLayout  
        anchors.left: parent.left  
        anchors.right: parent.right  
        anchors.top: parent.top  
        anchors.margins: messagePadding  
        spacing: root.contentSpacing  
  
        Rectangle {  
            Layout.fillWidth: true  
            implicitWidth: headerRowLayout.implicitWidth + 4 * 2  
            implicitHeight: headerRowLayout.implicitHeight + 4 * 2  
            color: Appearance.colors.colSecondaryContainer  
            radius: Appearance.rounding.small  
  
            RowLayout {  
                id: headerRowLayout  
                anchors {  
                    fill: parent  
                    margins: 4  
                }  
                spacing: 18  
  
                Item {  
                    Layout.alignment: Qt.AlignVCenter  
                    Layout.fillHeight: true  
                    implicitWidth: roleIcon.implicitWidth  
                    implicitHeight: roleIcon.implicitHeight  
  
                    MaterialSymbol {  
                        id: roleIcon  
                        anchors.centerIn: parent  
                        iconSize: Appearance.font.pixelSize.larger  
                        color: Appearance.m3colors.m3onSecondaryContainer  
                        text: messageData?.role == 'user' ? 'person' :   
                            messageData?.role == 'interface' ? 'settings' :   
                            messageData?.role == 'assistant' ? 'neurology' :   
                            'computer'  
                    }  
                }  
  
                StyledText {  
                    Layout.alignment: Qt.AlignVCenter  
                    Layout.fillWidth: true  
                    elide: Text.ElideRight  
                    font.pixelSize: Appearance.font.pixelSize.normal  
                    color: Appearance.m3colors.m3onSecondaryContainer  
                    text: messageData?.role == 'user' ? SystemInfo.username :  
                        messageData?.role == 'interface' ? Translation.tr("Interface") :  
                        Translation.tr("Wallpaper Browser")  
                }  
            }  
        }  
  
        StyledText {  
            Layout.fillWidth: true  
            font.family: Appearance.font.family.reading  
            font.pixelSize: Appearance.font.pixelSize.small  
            color: Appearance.colors.colOnLayer1  
            textFormat: TextEdit.PlainText  
            text: messageData?.content ?? ""  
            wrapMode: Text.Wrap  
        }  
    }  
}