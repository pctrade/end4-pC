import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import Quickshell.Hyprland

ContentPage {
    id: page
    property string descriptionMode: {
        if (Config.options.profile.descriptionText === "::uptime::") return "uptime"
        return "distro"
    }
    property string presetNameInput: ""

    FolderListModel {
        id: avatarFolderModel
        folder: Config.options.profile.avatarPath !== "" ? Qt.resolvedUrl(Config.options.profile.avatarPath) : ""
        showDirs: false
        nameFilters: ["*.png", "*.svg", "*.jpg", "*.jpeg", "*.webp"]
    }

    FolderListModel {
        id: presetsFolderModel
        folder: Qt.resolvedUrl(Directories.userPresetsPath)
        showDirs: false
        nameFilters: ["*.json"]
    }

    Process {
        id: saveProc
        onExited: refreshPresetsFolder()
    }

    Process {
        id: deleteProc
        onExited: refreshPresetsFolder()
    }

    function refreshPresetsFolder() {
        const current = presetsFolderModel.folder
        presetsFolderModel.folder = ""
        presetsFolderModel.folder = current
    }

    function savePreset() {
        const raw = page.presetNameInput.trim()
        if (raw.length === 0) return

        const commaIndex = raw.indexOf(",")
        let name = raw
        let description = ""

        if (commaIndex !== -1) {
            name = raw.substring(0, commaIndex).trim()
            description = raw.substring(commaIndex + 1).trim()
        }

        name = name.replace(/\s/g, "_")
        if (name.length === 0) return

        saveProc.command = ["bash", Directories.presetsScriptPath, "--save", name, description]
        saveProc.running = true
        page.presetNameInput = ""
    }

    function applyPreset(name) {
        GlobalStates.settingsOpen = false // sorry I can't stay open while changing the preset =(
        Quickshell.execDetached(["bash", Directories.presetsScriptPath, "--apply", name])
    }

    function deletePreset(name) {
        deleteProc.command = ["bash", Directories.presetsScriptPath, "--remove", name]
        deleteProc.running = true
    }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        ContentSection {
            icon: "person"
            shape: MaterialShape.Shape.Circle
            title: Translation.tr("Avatar")

            ConfigRow {
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Avatar path (leave empty to use ~/.face) eg /home/youruser/Pictures/avatar")
                    text: Config.options.profile.avatarPath
                    wrapMode: TextEdit.Wrap

                    Timer {
                        id: avatarDebounceTimer
                        interval: 1000
                        running: false
                        onTriggered: {
                            Config.options.profile.avatarPath = parent.text
                        }
                    }

                    onTextChanged: {
                        avatarDebounceTimer.restart()
                    }
                }
                ToolbarPairedFab {
                    visible: Config.options.profile.avatarPath !== ""
                    iconText: "add"
                    onClicked: {
                        GlobalStates.settingsOpen = false
                        if (Config.options.profile.avatarPath !== "") {
                            Quickshell.execDetached(["dolphin", Config.options.profile.avatarPath])
                        }
                    }
                }
            }

            Flow {
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                Layout.fillWidth: true
                spacing: 12
                visible: Config.options.profile.avatarPath !== ""

                Repeater {
                    model: avatarFolderModel
                    delegate: Rectangle {
                        required property string fileName
                        required property string filePath
                        width: 64
                        height: 64
                        radius: width / 2
                        color: Appearance.colors.colLayer2

                        property bool isSelected: FileUtils.trimFileProtocol(filePath.toString()) === Config.options.profile.avatarPicture

                        Image {
                            id: avatarImage
                            anchors.fill: parent
                            source: filePath
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: avatarImage.width * 2
                            sourceSize.height: avatarImage.height * 2
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: 64; height: width; radius: width / 2 
                                }
                            }
                        }

                        Rectangle {
                            visible: parent.isSelected
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: 2
                            anchors.bottomMargin: 2
                            width: 20
                            height: width
                            radius: width / 2
                            color: Appearance.colors.colPrimary

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "check"
                                iconSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnPrimary
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.options.profile.avatarPicture = FileUtils.trimFileProtocol(filePath.toString())
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Description Text")

                ConfigSelectionArray {
                    currentValue: Config.options.profile.descriptionText === "::uptime::" ? "uptime" : "distro"
                    onSelected: newValue => {
                        page.descriptionMode = newValue
                        if (newValue === "distro") Config.options.profile.descriptionText = "::distro::"
                        if (newValue === "uptime") Config.options.profile.descriptionText = "::uptime::"
                    }
                    options: [
                        { displayName: Translation.tr("Distro"), icon: "deployed_code", value: "distro" },
                        { displayName: Translation.tr("Uptime"), icon: "timelapse",     value: "uptime" },
                    ]
                }
            }
        }

        ContentSection {
            icon: "wall_art"
            shape: MaterialShape.Shape.Pentagon
            title: Translation.tr("Presets")

            ConfigRow {
                MaterialTextArea {
                    id: presetNameField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Name, description (optional)")
                    wrapMode: TextEdit.NoWrap
                    Timer {
                        id: presetNameDebounceTimer
                        interval: 1000
                        running: false
                        onTriggered: {
                            page.presetNameInput = parent.text
                        }
                    }
                    onTextChanged: {
                        presetNameDebounceTimer.restart()
                    }
                }

                ToolbarPairedFab {
                    visible: page.presetNameInput.trim() !== ""
                    iconText: "save"
                    onClicked: {
                        page.savePreset()
                        presetNameField.text = ""
                        page.presetNameInput = ""
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 40
                visible: presetsFolderModel.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("No presets yet")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.normal
            }

            Flow {
                Layout.topMargin: 10
                Layout.fillWidth: true
                width: parent.width
                spacing: 12
                visible: presetsFolderModel.count > 0

                Repeater {
                    model: presetsFolderModel
                    delegate: PresetsCard {
                        id: presetDelegate
                        required property string fileName
                        required property string filePath

                        property string presetName: fileName.replace(".json", "")
                        property string presetWallpaper: ""
                        property string presetDescription: ""

                        FileView {
                            path: presetDelegate.filePath
                            onLoaded: {
                                try {
                                    const data = JSON.parse(text())
                                    presetDelegate.presetWallpaper = data?.background?.wallpaperPath ?? ""
                                    presetDelegate.presetDescription = data?._presetMeta?.description ?? ""
                                } catch (e) {
                                    console.log("Failed to parse preset:", e)
                                }
                            }
                        }

                        imageSource: presetDelegate.presetWallpaper
                        title: presetDelegate.presetName
                        description: presetDelegate.presetDescription !== "" ? presetDelegate.presetDescription : Translation.tr("Saved preset")
                        onApply: () => page.applyPreset(presetDelegate.presetName)
                        onRemove: () => page.deletePreset(presetDelegate.presetName)
                    }
                }
            }
        }
    }
}