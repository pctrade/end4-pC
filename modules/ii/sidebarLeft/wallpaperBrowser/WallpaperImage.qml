import qs.services  
import qs.modules.common  
import qs.modules.common.functions  
import qs.modules.common.utils  
import qs.modules.common.widgets  
import QtQml  
import QtQuick  
import QtQuick.Controls  
import QtQuick.Layouts  
import Qt5Compat.GraphicalEffects  
import Quickshell  
import Quickshell.Io  
import Quickshell.Hyprland  
  
Button {  
    id: root  
    property var imageData  
    property var rowHeight  
    property string downloadPath  
    property string nsfwPath  
    property string fileExt: {
        const url = imageData.file_url.toLowerCase();
        if (url.includes(".png")) return "png";
        if (url.includes(".gif")) return "gif";
        if (url.includes(".webp")) return "webp";
        return "jpg";
    }
    property string filePrefix: imageData.source?.includes("unsplash") ? "unsplash" : "wallhaven"
    property string fileName: filePrefix + "-" + imageData.id + "." + fileExt
    property int maxTagStringLineLength: 50  
    property real imageRadius: Appearance.rounding.small  
  
    property bool showActions: false  
      
    padding: 0  
    implicitWidth: root.rowHeight * modelData.aspect_ratio  
    implicitHeight: root.rowHeight  
  
    background: Rectangle {  
        implicitWidth: root.rowHeight * modelData.aspect_ratio  
        implicitHeight: root.rowHeight  
        radius: imageRadius  
        color: Appearance.colors.colLayer2  
    }  
    contentItem: Item {  
        anchors.fill: parent  
  
        StyledImage {  
            id: imageObject  
            anchors.fill: parent  
            width: root.rowHeight * modelData.aspect_ratio  
            height: root.rowHeight  
            fillMode: Image.PreserveAspectFit  
            source: modelData.preview_url  
            sourceSize.width: root.rowHeight * modelData.aspect_ratio  
            sourceSize.height: root.rowHeight  
  
            layer.enabled: true  
            layer.effect: OpacityMask {  
                maskSource: Rectangle {  
                    width: root.rowHeight * modelData.aspect_ratio  
                    height: root.rowHeight  
                    radius: imageRadius  
                }  
            }  
        }  
  
        RippleButton {  
            id: menuButton  
            anchors.top: parent.top  
            anchors.right: parent.right  
            property real buttonSize: 30  
            anchors.margins: Math.max(root.imageRadius - buttonSize / 2, 8)  
            implicitHeight: buttonSize  
            implicitWidth: buttonSize  
  
            buttonRadius: Appearance.rounding.full  
            colBackground: ColorUtils.transparentize(Appearance.m3colors.m3surface, 0.3)  
            colBackgroundHover: ColorUtils.transparentize(ColorUtils.mix(Appearance.m3colors.m3surface, Appearance.m3colors.m3onSurface, 0.8), 0.2)  
            colRipple: ColorUtils.transparentize(ColorUtils.mix(Appearance.m3colors.m3surface, Appearance.m3colors.m3onSurface, 0.6), 0.1)  
  
            contentItem: MaterialSymbol {  
                horizontalAlignment: Text.AlignHCenter  
                iconSize: Appearance.font.pixelSize.large  
                color: Appearance.m3colors.m3onSurface  
                text: "more_vert"  
            }  
  
            onClicked: {  
                root.showActions = !root.showActions  
            }  
        }  
  
        Loader {  
            id: contextMenuLoader  
            active: root.showActions  
            anchors.top: menuButton.bottom  
            anchors.right: parent.right  
            anchors.margins: 8  
  
            sourceComponent: Item {  
                width: contextMenu.width  
                height: contextMenu.height  
  
                StyledRectangularShadow {  
                    target: contextMenu  
                }  
                Rectangle {  
                    id: contextMenu  
                    anchors.centerIn: parent  
                    opacity: root.showActions ? 1 : 0  
                    visible: opacity > 0  
                    radius: Appearance.rounding.small  
                    color: Appearance.m3colors.m3surfaceContainer  
                    implicitWidth: 200 
                    implicitHeight: 125
                    clip: true
  
                    Behavior on opacity {  
                        NumberAnimation {  
                            duration: Appearance.animation.elementMoveFast.duration  
                            easing.type: Appearance.animation.elementMoveFast.type  
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve  
                        }  
                    }  

                    StyledFlickable {
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: contextMenuColumnLayout.implicitHeight

                        ColumnLayout {  
                            id: contextMenuColumnLayout  
                            anchors.fill: parent  
                            spacing: 0  
    
                            MenuButton {  
                                id: moreImageButton  
                                Layout.fillWidth: true  
                                buttonText: Translation.tr("More like this picture")  
                                onClicked: {  
                                    root.showActions = false  
                                    WallpaperBrowser.moreLikeThisPicture(root.imageData.id) 
                                }  
                            }
                            MenuButton {  
                                id: openFileLinkButton  
                                Layout.fillWidth: true  
                                buttonText: Translation.tr("Open file link")  
                                onClicked: {  
                                    root.showActions = false  
                                    Hyprland.dispatch("keyword cursor:no_warps true")  
                                    Qt.openUrlExternally(root.imageData.file_url)  
                                    Hyprland.dispatch("keyword cursor:no_warps false")  
                                }  
                            }
                            MenuButton {  
                                id: sourceButton  
                                visible: root.imageData.source && root.imageData.source.length > 0  
                                Layout.fillWidth: true  
                                buttonText: Translation.tr("Go to source (%1)").arg(StringUtils.getDomain(root.imageData.source))  
                                enabled: root.imageData.source && root.imageData.source.length > 0  
                                onClicked: {  
                                    root.showActions = false  
                                    Hyprland.dispatch("keyword cursor:no_warps true")  
                                    Qt.openUrlExternally(root.imageData.source)  
                                    Hyprland.dispatch("keyword cursor:no_warps false")  
                                }  
                            }  
                            MenuButton {  
                                id: downloadButton  
                                Layout.fillWidth: true  
                                buttonText: Translation.tr("Download")  
                                onClicked: {  
                                    root.showActions = false;  
                                    const targetPath = root.imageData.is_nsfw ? root.nsfwPath : root.downloadPath;  
                                    Quickshell.execDetached(["bash", "-c",   
                                        `mkdir -p '${targetPath}' && curl '${root.imageData.file_url}' -o '${targetPath}/${root.fileName}' && notify-send '${Translation.tr("Download complete")}' '${root.downloadPath}/${root.fileName}' -a 'Shell'`  
                                    ])  
                                }  
                            }  
                            MenuButton {  
                                id: setWallpaperButton  
                                Layout.fillWidth: true  
                                buttonText: Translation.tr("Set as wallpaper")  
                                onClicked: {  
                                    root.showActions = false;  
                                    Wallpapers.select(root.imageData.file_url);
                                    if (root.imageData.color != "") {
                                        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch", "--color", root.imageData.color]);  
                                    }
                                }  
                            }  
                        }  
                    }
                }  
            }  
        }  
    }  
}