import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    required property var preset
    required property Item pager
    property int staggerMs: 45

    property bool confirmDelete: false
    property bool confirmUnshare: false
    property bool overwritten: false
    property bool exported: false
    property bool installed: false
    property bool renaming: false
    readonly property bool online: preset.source === "online"
    readonly property bool busy: online && PresetsOnline.downloadingName === preset.name

    signal back()
    signal pageExitRequested()

    property bool closing: false

    function requestExit() {
        closing = true;
        pageExitRequested();
    }
    signal applyRequested()
    signal overwriteRequested()
    signal exportRequested()
    signal uploadRequested()
    signal unshareRequested()
    signal installRequested()
    signal deleteRequested()
    signal renameRequested(string newName)

    function commitRename() {
        const next = titleInput.text.trim();
        renaming = false;
        if (next !== "" && next.replace(/\s/g, "_") !== preset.name) renameRequested(next);
    }

    readonly property var info: preset.summary ?? ({})
    readonly property var barIcons: ({
        left: info.leftLayout ?? [],
        middle: info.middleLayout ?? [],
        right: info.rightLayout ?? []
    })

    DashboardBarWidgets {
        id: widgetCatalog
    }

    Timer {
        id: overwrittenTimer
        interval: 2200
        onTriggered: root.overwritten = false
    }

    Timer {
        id: installedTimer
        interval: 2200
        onTriggered: root.installed = false
    }

    Timer {
        id: exportedTimer
        interval: 2200
        onTriggered: root.exported = false
    }

    Binding {
        target: root.pager
        property: "editingText"
        value: root.renaming
    }

    Timer {
        id: renameFocusTimer
        interval: 80
        onTriggered: {
            titleInput.forceActiveFocus();
            titleInput.selectAll();
        }
    }

    Timer {
        id: confirmTimer
        interval: 2500
        onTriggered: root.confirmDelete = false
    }

    Timer {
        id: confirmUnshareTimer
        interval: 2500
        onTriggered: root.confirmUnshare = false
    }

    Component.onCompleted: {
        if (preset.source === "mine" && !(info.origin ?? "")) Presets.checkOwnership(preset.name);
    }

    readonly property var facts: online ? [] : [
        { icon: "toast", label: Translation.tr("Bar position"), value: info.barPosition ?? "" },
        { icon: "style", label: Translation.tr("Bar style"), value: info.barStyle ?? "" },
        { icon: "palette", label: Translation.tr("Colors"), value: info.palette ?? "" },
        { icon: "schedule", label: Translation.tr("Clock"), value: info.clock ?? "" },
        { icon: "dock_to_bottom", label: Translation.tr("Dock"), value: info.dock ? Translation.tr("Enabled") : Translation.tr("Hidden") },
        { icon: "blur_on", label: Translation.tr("Wallpaper blur"), value: info.blur ? Translation.tr("On") : Translation.tr("Off") }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            DashboardCard {
                id: previewCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.horizontalStretchFactor: 6
                tint: Appearance.colors.colLayer1
                pager: root
                staggerMs: root.staggerMs
                animIndex: 0
                travelX: -240
                travelY: 0

                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: previewCard.width
                            height: previewCard.height
                            radius: previewCard.cardRadius
                        }
                    }

                    Image {
                        anchors.fill: parent
                        visible: root.online && (root.preset.thumb ?? "") !== ""
                        source: root.preset.thumb ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize: Qt.size(720, 460)
                    }

                    Image {
                        anchors.fill: parent
                        source: root.preset.wallpaper ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize: Qt.size(1100, 700)
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: !(root.preset.wallpaper ?? "")
                        text: "wallpaper"
                        iconSize: 96
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.4
                    }

                    Rectangle {
                        id: mockBar
                        visible: !root.online
                        readonly property real thickness: 34
                        readonly property real gap: (root.info.cornerStyle ?? 0) === 0 ? 0 : 12
                        readonly property bool vertical: root.info.vertical ?? false
                        readonly property bool far: root.info.bottom ?? false

                        x: vertical ? (far ? parent.width - width - gap : gap) : gap
                        y: vertical ? gap : (far ? parent.height - height - gap : gap)
                        width: vertical ? thickness : parent.width - gap * 2
                        height: vertical ? parent.height - gap * 2 : thickness
                        radius: gap === 0 ? 0 : thickness / 2
                        color: Qt.rgba(0, 0, 0, 0.6)

                        Loader {
                            anchors.fill: parent
                            anchors.margins: 6
                            sourceComponent: mockBar.vertical ? columnBar : rowBar
                        }
                    }

                    Rectangle {
                        visible: !root.online && (root.info.dock ?? false)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: (!mockBar.vertical && mockBar.far) ? mockBar.thickness + mockBar.gap + 14 : 14
                        width: 168
                        height: 34
                        radius: 17
                        color: Qt.rgba(0, 0, 0, 0.5)

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Repeater {
                                model: 6
                                Rectangle { width: 18; height: 18; radius: 9; color: Qt.rgba(1, 1, 1, 0.7) }
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * 0.4
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) }
                        }
                        visible: false
                    }
                }
            }

            DashboardCard {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.horizontalStretchFactor: 4
                Layout.fillWidth: true
                tint: Appearance.colors.colSecondaryContainer
                pager: root
                staggerMs: root.staggerMs
                animIndex: 1
                travelX: 240
                travelY: 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: titleText.implicitHeight

                        StyledText {
                            id: titleText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            visible: !root.renaming
                            text: PresetsOnline.displayName(root.preset.name).replace(/_/g, " ")
                            font.pixelSize: 28
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnSecondaryContainer
                            elide: Text.ElideRight
                        }

                        TextInput {
                            id: titleInput
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 44
                            visible: root.renaming
                            clip: true
                            font.pixelSize: 28
                            font.weight: Font.DemiBold
                            font.family: Appearance.font.family.main
                            color: Appearance.colors.colOnSecondaryContainer
                            selectionColor: Appearance.colors.colPrimary
                            onAccepted: root.commitRename()
                            onActiveFocusChanged: if (!activeFocus && root.renaming) Qt.callLater(() => forceActiveFocus())
                            Keys.onEscapePressed: root.renaming = false
                        }

                        RippleButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.renaming
                            implicitWidth: 36
                            implicitHeight: 36
                            buttonRadius: 18
                            colBackground: Appearance.colors.colPrimary
                            colBackgroundHover: Appearance.colors.colPrimaryHover
                            colRipple: Appearance.colors.colPrimaryActive
                            downAction: () => Qt.callLater(() => root.commitRename())
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: "check"
                                iconSize: 22
                                fill: 1
                                color: Appearance.colors.colOnPrimary
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.info.description || Translation.tr("No description")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSecondaryContainer
                        opacity: 0.8
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        implicitHeight: 1
                        color: Appearance.colors.colOnSecondaryContainer
                        opacity: 0.15
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.online
                        text: PresetsOnline.error !== "" ? PresetsOnline.error : Translation.tr("Download this preset to see its bar, colors and widgets, and to apply it.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: PresetsOnline.error !== "" ? Appearance.colors.colError : Appearance.colors.colOnSecondaryContainer
                        opacity: 0.85
                        wrapMode: Text.WordWrap
                    }

                    PresetAuthorChip {
                        Layout.fillWidth: true
                        visible: root.online && author !== ""
                        author: root.preset.entry?.author ?? ""
                        textColor: Appearance.colors.colOnSecondaryContainer
                        avatarSize: 28
                    }

                    Repeater {
                        model: root.facts

                        delegate: RowLayout {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                implicitWidth: 36
                                implicitHeight: 36
                                radius: 12
                                color: Appearance.colors.colSecondary

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    iconSize: 20
                                    fill: 1
                                    color: Appearance.colors.colOnSecondary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSecondaryContainer
                                    opacity: 0.7
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnSecondaryContainer
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            opacity: root.closing ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            RippleButton {
                implicitHeight: 48
                horizontalPadding: 20
                buttonRadius: 24
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer1Hover
                downAction: () => Qt.callLater(() => root.back())
                contentItem: RowLayout {
                    spacing: 8
                    MaterialSymbol {
                        text: "arrow_back"
                        iconSize: 20
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: Translation.tr("Back")
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Repeater {
                model: [
                    { id: "overwrite", icon: "save_as", label: Translation.tr("Overwrite"), scope: ["mine"] },
                    { id: "rename", icon: "edit", label: Translation.tr("Rename"), scope: ["mine"] },
                    { id: "export", icon: "ios_share", label: Translation.tr("Export ZIP"), scope: ["mine"], own: true },
                    { id: "upload", icon: "cloud_upload", label: Translation.tr("Upload"), scope: ["mine"], own: true },
                    { id: "unshare", icon: "cloud_off", label: Translation.tr("Remove from gallery"), scope: ["mine"], published: true },
                    { id: "install", icon: "download_done", label: Translation.tr("Install"), scope: ["downloaded", "imported"] },
                    { id: "delete", icon: "delete", label: Translation.tr("Delete"), scope: ["mine", "downloaded", "imported"] }
                ]

                delegate: RippleButton {
                    id: secondary
                    required property var modelData

                    readonly property bool isDelete: modelData.id === "delete"
                    readonly property bool isUnshare: modelData.id === "unshare"
                    readonly property bool armed: isDelete && root.confirmDelete
                    readonly property bool unshareArmed: isUnshare && root.confirmUnshare
                    readonly property bool done: (modelData.id === "overwrite" && root.overwritten) || (modelData.id === "export" && root.exported) || (modelData.id === "install" && root.installed)

                    visible: !root.online && modelData.scope.includes(root.preset.source) && (!modelData.own || !(root.info.origin ?? "")) && (modelData.id === "upload" ? !Presets.isPublished(root.preset.name) : (!modelData.published || Presets.isPublished(root.preset.name)))
                    implicitHeight: 48
                    horizontalPadding: 18
                    buttonRadius: 24
                    colBackground: unshareArmed ? Appearance.colors.colPrimary : armed ? Appearance.colors.colError : done ? Appearance.m3colors.m3success : Appearance.colors.colLayer1
                    colBackgroundHover: unshareArmed ? Appearance.colors.colPrimaryHover : armed ? Appearance.colors.colError : done ? Appearance.m3colors.m3success : Appearance.colors.colLayer1Hover
                    downAction: () => {
                        const id = modelData.id;
                        Qt.callLater(() => {
                            if (id === "overwrite") {
                                root.overwriteRequested();
                                root.overwritten = true;
                                overwrittenTimer.restart();
                            }
                            else if (id === "export") {
                                root.exportRequested();
                                root.exported = true;
                                exportedTimer.restart();
                            }
                            else if (id === "rename") {
                                titleInput.text = PresetsOnline.displayName(root.preset.name).replace(/_/g, " ");
                                root.renaming = true;
                                renameFocusTimer.restart();
                            }
                            else if (id === "upload") root.uploadRequested();
                            else if (id === "unshare") {
                                if (root.confirmUnshare) {
                                    root.confirmUnshare = false;
                                    root.unshareRequested();
                                } else {
                                    root.confirmUnshare = true;
                                    confirmUnshareTimer.restart();
                                }
                            }
                            else if (id === "install") {
                                root.installRequested();
                                root.installed = true;
                                installedTimer.restart();
                            }
                            else if (root.confirmDelete) root.deleteRequested();
                            else {
                                root.confirmDelete = true;
                                confirmTimer.restart();
                            }
                        });
                    }
                    contentItem: RowLayout {
                        spacing: 8
                        MaterialSymbol {
                            text: secondary.done ? "check_circle" : secondary.modelData.icon
                            iconSize: 20
                            fill: secondary.done ? 1 : 0
                            color: secondary.unshareArmed ? Appearance.colors.colOnPrimary : secondary.armed ? Appearance.colors.colOnError : secondary.done ? Appearance.m3colors.m3onSuccess : Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: secondary.unshareArmed ? Translation.tr("Tap again to remove") : secondary.armed ? Translation.tr("Tap again to delete") : secondary.done ? (secondary.modelData.id === "export" ? Translation.tr("Exported") : secondary.modelData.id === "install" ? Translation.tr("Installed") : Translation.tr("Overwritten")) : secondary.modelData.label
                            color: secondary.unshareArmed ? Appearance.colors.colOnPrimary : secondary.armed ? Appearance.colors.colOnError : secondary.done ? Appearance.m3colors.m3onSuccess : Appearance.colors.colOnLayer1
                        }
                    }
                }
            }

            RippleButton {
                implicitHeight: 48
                horizontalPadding: 26
                buttonRadius: 24
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                colRipple: Appearance.colors.colPrimaryActive
                enabled: !root.busy
                downAction: () => Qt.callLater(() => root.applyRequested())
                contentItem: RowLayout {
                    spacing: 8
                    MaterialSymbol {
                        text: root.busy ? "hourglass_top" : root.online ? "download" : "check"
                        iconSize: 22
                        fill: 1
                        color: Appearance.colors.colOnPrimary
                    }
                    StyledText {
                        text: root.busy ? Translation.tr("Downloading…") : root.online ? Translation.tr("Download preset") : Translation.tr("Apply preset")
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }
        }
    }

    Component {
        id: rowBar

        RowLayout {
            spacing: 6

            Repeater {
                model: root.barIcons.left
                delegate: MaterialSymbol {
                    required property string modelData
                    text: widgetCatalog.byId(modelData).icon
                    iconSize: 16
                    color: Qt.rgba(1, 1, 1, 0.9)
                }
            }

            Item { Layout.fillWidth: true }

            Repeater {
                model: root.barIcons.middle
                delegate: MaterialSymbol {
                    required property string modelData
                    text: widgetCatalog.byId(modelData).icon
                    iconSize: 16
                    color: Qt.rgba(1, 1, 1, 0.9)
                }
            }

            Item { Layout.fillWidth: true }

            Repeater {
                model: root.barIcons.right
                delegate: MaterialSymbol {
                    required property string modelData
                    text: widgetCatalog.byId(modelData).icon
                    iconSize: 16
                    color: Qt.rgba(1, 1, 1, 0.9)
                }
            }
        }
    }

    Component {
        id: columnBar

        ColumnLayout {
            spacing: 6

            Repeater {
                model: root.barIcons.left
                delegate: MaterialSymbol {
                    required property string modelData
                    Layout.alignment: Qt.AlignHCenter
                    text: widgetCatalog.byId(modelData).icon
                    iconSize: 16
                    color: Qt.rgba(1, 1, 1, 0.9)
                }
            }

            Item { Layout.fillHeight: true }

            Repeater {
                model: root.barIcons.middle
                delegate: MaterialSymbol {
                    required property string modelData
                    Layout.alignment: Qt.AlignHCenter
                    text: widgetCatalog.byId(modelData).icon
                    iconSize: 16
                    color: Qt.rgba(1, 1, 1, 0.9)
                }
            }

            Item { Layout.fillHeight: true }

            Repeater {
                model: root.barIcons.right
                delegate: MaterialSymbol {
                    required property string modelData
                    Layout.alignment: Qt.AlignHCenter
                    text: widgetCatalog.byId(modelData).icon
                    iconSize: 16
                    color: Qt.rgba(1, 1, 1, 0.9)
                }
            }
        }
    }
}
