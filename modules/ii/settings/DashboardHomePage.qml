import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    required property Item pager
    property int staggerMs: 45

    property date viewMonth: new Date(DateTime.clock.date.getFullYear(), DateTime.clock.date.getMonth(), 1)
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
    readonly property string displayName: Config.options.profile.displayName || SystemInfo.username
    readonly property string avatarPath: Config.options.profile.avatarPath !== "" && Config.options.profile.avatarPicture !== ""
        ? Config.options.profile.avatarPicture
        : `${FileUtils.trimFileProtocol(Directories.home)}/.face`
    readonly property bool typing: flip.showBack || tasksCard.adding
    readonly property int pendingTasks: Todo.list.filter(t => !t.done).length

    readonly property string greeting: {
        const h = DateTime.clock.date.getHours();
        if (h < 6) return Translation.tr("Good night");
        if (h < 12) return Translation.tr("Good morning");
        if (h < 19) return Translation.tr("Good afternoon");
        return Translation.tr("Good evening");
    }

    property date now: new Date()
    property date selectedDate: new Date()
    readonly property int daysInViewMonth: new Date(viewMonth.getFullYear(), viewMonth.getMonth() + 1, 0).getDate()
    readonly property int viewOffset: (viewMonth.getDay() - firstDay + 7) % 7
    readonly property int calendarRows: Math.ceil((viewOffset + daysInViewMonth) / 7)
    readonly property bool viewingCurrentMonth: viewMonth.getFullYear() === now.getFullYear() && viewMonth.getMonth() === now.getMonth()

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    function expandPath(raw) {
        const path = String(raw ?? "").trim();
        const home = FileUtils.trimFileProtocol(Directories.home).replace(/\/$/, "");
        if (path === "") return "";
        if (path === "~") return home;
        if (path.startsWith("~/")) return home + path.slice(1);
        if (path.startsWith("/")) return path;
        if (path.startsWith("home/")) return "/" + path;
        return home + "/" + path;
    }

    readonly property string avatarFolder: expandPath(Config.options.profile.avatarPath)

    FolderListModel {
        id: avatarFolderModel
        folder: root.avatarFolder !== "" ? Qt.resolvedUrl(root.avatarFolder) : ""
        showDirs: false
        nameFilters: ["*.png", "*.svg", "*.jpg", "*.jpeg", "*.webp", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
    }

    function shiftMonth(delta) {
        viewMonth = new Date(viewMonth.getFullYear(), viewMonth.getMonth() + delta, 1);
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    Component.onCompleted: {
        ResourceUsage.consumers++;
        if (SystemInfo.cpu === "") SystemInfo.refresh();
    }
    Component.onDestruction: ResourceUsage.consumers--

    component InfoTile: RowLayout {
        id: tile
        property string icon: ""
        property string label: ""
        property string value: ""
        property color accent: Appearance.colors.colPrimaryContainer
        property color onAccent: Appearance.colors.colOnPrimaryContainer
        spacing: 8

        Rectangle {
            implicitWidth: 30
            implicitHeight: 30
            radius: 10
            color: tile.accent

            MaterialSymbol {
                anchors.centerIn: parent
                text: tile.icon
                iconSize: 18
                fill: 1
                color: tile.onAccent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                text: tile.label
                font.pixelSize: 10
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                text: tile.value || "–"
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
                elide: Text.ElideRight
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 24

            ColumnLayout {
                spacing: 0

                StyledText {
                    text: root.greeting
                    font.pixelSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    text: Translation.tr("Up since") + " • " + DateTime.uptime
                    font.pixelSize: 30
                    font.weight: Font.Light
                    color: Appearance.colors.colOnLayer0
                }
            }

            Item { Layout.fillWidth: true }

            Repeater {
                model: [
                    { ratio: ResourceUsage.cpuUsage, icon: "memory", accent: Appearance.colors.colPrimary, label: ResourceUsage.cpuTemp > 0 ? `CPU · ${Math.round(ResourceUsage.cpuTemp)}°C` : "CPU", show: true },
                    { ratio: ResourceUsage.memoryUsedPercentage, icon: "developer_board", accent: Appearance.colors.colTertiary, label: `RAM · ${ResourceUsage.kbToGbString(ResourceUsage.memoryUsed)}`, show: true },
                    { ratio: ResourceUsage.diskUsedPercentage, icon: "hard_drive", accent: Appearance.colors.colSecondary, label: `${Translation.tr("Disk")} · ${ResourceUsage.kbToGbString(ResourceUsage.diskUsed)}`, show: true },
                    { ratio: Battery.percentage, icon: Battery.isCharging ? "battery_charging_full" : "battery_full", accent: Battery.isLow && !Battery.isCharging ? Appearance.colors.colError : Appearance.colors.colPrimary, label: Battery.isCharging ? Translation.tr("Charging") : Translation.tr("Battery"), show: Battery.available }
                ]

                delegate: RowLayout {
                    required property var modelData
                    visible: modelData.show
                    spacing: 8

                    Item {
                        implicitWidth: 48
                        implicitHeight: 48

                        CircularProgress {
                            anchors.fill: parent
                            implicitSize: 48
                            lineWidth: 5
                            value: modelData.ratio
                            colPrimary: modelData.accent
                            colSecondary: Appearance.colors.colSecondaryContainer
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: modelData.icon
                            iconSize: 20
                            fill: 1
                            color: modelData.accent
                        }
                    }

                    ColumnLayout {
                        spacing: 0

                        StyledText {
                            text: Math.round(modelData.ratio * 100) + "%"
                            font.pixelSize: 30
                            font.weight: Font.Light
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            text: modelData.label
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }

        RowLayout {
            id: homeGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: (homeGrid.width - 24) / 3
                spacing: 12

                DashboardCard {
                    id: userCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 100
                    tint: Appearance.colors.colPrimaryContainer
                    pager: root.pager
                    staggerMs: root.staggerMs
                    animIndex: 0
                    travelX: -300
                    travelY: 0

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: userCard.width
                                height: userCard.height
                                radius: userCard.cardRadius
                            }
                        }

                        FlipCard {
                            id: flip
                            anchors.fill: parent
                            property bool showBack: false
                            onFlipped: showBack = !showBack

                            Item {
                                id: front
                                anchors.fill: parent
                                visible: !flip.showBack

                        Image {
                            id: avatarImage
                            anchors.fill: parent
                            source: `file://${root.avatarPath}`
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize: Qt.size(userCard.width * 2, userCard.height * 2)
                            visible: status === Image.Ready
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: avatarImage.status !== Image.Ready
                            text: "account_circle"
                            fill: 1
                            iconSize: 120
                            color: Appearance.colors.colOnPrimaryContainer
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: parent.height * 0.5
                            gradient: Gradient {
                                GradientStop { position: 0; color: "transparent" }
                                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.75) }
                            }
                        }

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 16
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: root.displayName
                                font.pixelSize: Appearance.font.pixelSize.huge
                                font.weight: Font.DemiBold
                                color: "white"
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: `${SystemInfo.username}@${SystemInfo.hostname}`
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Qt.rgba(1, 1, 1, 0.75)
                                elide: Text.ElideRight
                            }
                        }

                        RippleButton {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            implicitWidth: 38
                            implicitHeight: 38
                            buttonRadius: 19
                            colBackground: Qt.rgba(0, 0, 0, 0.45)
                            colBackgroundHover: Qt.rgba(0, 0, 0, 0.65)
                            colRipple: Qt.rgba(1, 1, 1, 0.3)
                            downAction: () => Qt.callLater(() => flip.flip())
                            contentItem: Item {
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "edit"
                                    iconSize: 20
                                    color: "white"
                                }
                            }
                        }
                            }

                            Item {
                                id: back
                                anchors.fill: parent
                                visible: flip.showBack

                                Rectangle {
                                    anchors.fill: parent
                                    color: Appearance.colors.colSecondaryContainer
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: Translation.tr("Profile")
                                            font.pixelSize: Appearance.font.pixelSize.larger
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colOnSecondaryContainer
                                        }

                                        RippleButton {
                                            implicitWidth: 36
                                            implicitHeight: 36
                                            buttonRadius: 18
                                            colBackground: Appearance.colors.colPrimary
                                            colBackgroundHover: Appearance.colors.colPrimaryHover
                                            downAction: () => Qt.callLater(() => flip.flip())
                                            contentItem: Item {
                                                MaterialSymbol {
                                                    anchors.centerIn: parent
                                                    text: "check"
                                                    iconSize: 20
                                                    color: Appearance.colors.colOnPrimary
                                                }
                                            }
                                        }
                                    }

                                    Repeater {
                                        model: [
                                            { id: "name", icon: "badge", placeholder: SystemInfo.username },
                                            { id: "folder", icon: "folder_open", placeholder: Translation.tr("Avatar folder, e.g. ~/Pictures/avatars") }
                                        ]

                                        delegate: Rectangle {
                                            id: fieldBox
                                            required property var modelData

                                            Layout.fillWidth: true
                                            implicitHeight: 38
                                            radius: 19
                                            color: Qt.rgba(1, 1, 1, 0.1)
                                            border.width: fieldInput.activeFocus ? 2 : 0
                                            border.color: Appearance.colors.colPrimary

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                spacing: 8

                                                MaterialSymbol {
                                                    text: fieldBox.modelData.icon
                                                    iconSize: 18
                                                    color: Appearance.colors.colOnSecondaryContainer
                                                }

                                                TextInput {
                                                    id: fieldInput
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    clip: true
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                    font.family: Appearance.font.family.main
                                                    color: Appearance.colors.colOnSecondaryContainer
                                                    selectionColor: Appearance.colors.colPrimary
                                                    text: fieldBox.modelData.id === "name" ? Config.options.profile.displayName : Config.options.profile.avatarPath
                                                    onTextEdited: saveTimer.restart()
                                                    Keys.onEscapePressed: {
                                                        focus = false;
                                                        root.pager.forceActiveFocus();
                                                    }

                                                    Timer {
                                                        id: saveTimer
                                                        interval: 800
                                                        onTriggered: {
                                                            if (fieldBox.modelData.id === "name") {
                                                                Config.options.profile.displayName = fieldInput.text;
                                                            } else {
                                                                const expanded = root.expandPath(fieldInput.text);
                                                                Config.options.profile.avatarPath = expanded;
                                                            }
                                                        }
                                                    }

                                                    StyledText {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        visible: fieldInput.text === "" && !fieldInput.activeFocus
                                                        text: fieldBox.modelData.placeholder
                                                        font.pixelSize: Appearance.font.pixelSize.small
                                                        color: Appearance.colors.colOnSecondaryContainer
                                                        opacity: 0.5
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                    Flickable {
                                        anchors.fill: parent
                                        clip: true
                                        contentWidth: width
                                        contentHeight: avatarFlow.implicitHeight
                                        boundsBehavior: Flickable.StopAtBounds

                                        Flow {
                                            id: avatarFlow
                                            width: parent.width
                                            spacing: 8

                                            Repeater {
                                                model: avatarFolderModel

                                                delegate: Item {
                                                    id: avatarCell
                                                    required property string fileName
                                                    required property url filePath

                                                    readonly property string cleanPath: FileUtils.trimFileProtocol(filePath.toString())
                                                    readonly property bool selected: cleanPath === Config.options.profile.avatarPicture

                                                    width: 58
                                                    height: 58

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: avatarCell.selected ? Appearance.rounding.normal : width / 2
                                                        color: "transparent"
                                                        border.width: avatarCell.selected ? 3 : 0
                                                        border.color: Appearance.colors.colPrimary

                                                        Behavior on radius {
                                                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                                        }
                                                    }

                                                    Image {
                                                        id: cellImage
                                                        anchors.centerIn: parent
                                                        width: 48
                                                        height: 48
                                                        source: avatarCell.filePath
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        cache: true
                                                        sourceSize: Qt.size(96, 96)
                                                        layer.enabled: true
                                                        layer.effect: OpacityMask {
                                                            maskSource: Rectangle {
                                                                width: cellImage.width
                                                                height: cellImage.height
                                                                radius: avatarCell.selected ? Appearance.rounding.normal - 3 : width / 2
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            const path = avatarCell.cleanPath;
                                                            Qt.callLater(() => { Config.options.profile.avatarPicture = path; });
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                    }
                                        StyledText {
                                            anchors.centerIn: parent
                                            visible: avatarFolderModel.count === 0
                                            width: parent.width - 20
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.WordWrap
                                            text: Translation.tr("Set a folder with images to pick your avatar")
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnSecondaryContainer
                                            opacity: 0.6
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                DashboardCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: infoGrid.implicitHeight + 24
                    Layout.maximumHeight: infoGrid.implicitHeight + 24
                    tint: Appearance.colors.colLayer1
                    pager: root.pager
                    staggerMs: root.staggerMs
                    animIndex: 1
                    travelX: -300
                    travelY: 200

                    GridLayout {
                        id: infoGrid
                        anchors.fill: parent
                        anchors.margins: 12
                        columns: 2
                        rowSpacing: 6
                        columnSpacing: 10

                        InfoTile {
                            Layout.fillWidth: true
                            Layout.columnSpan: 2
                            icon: "memory"
                            label: "CPU"
                            value: SystemInfo.cpu
                            accent: Appearance.colors.colTertiaryContainer
                            onAccent: Appearance.colors.colOnTertiaryContainer
                        }
                        InfoTile {
                            Layout.fillWidth: true
                            Layout.columnSpan: 2
                            icon: "videocam"
                            label: "GPU"
                            value: SystemInfo.gpu
                            accent: Appearance.colors.colTertiaryContainer
                            onAccent: Appearance.colors.colOnTertiaryContainer
                        }
                        InfoTile {
                            Layout.fillWidth: true
                            icon: "deployed_code"
                            label: Translation.tr("Kernel")
                            value: SystemInfo.kernelVersion
                            accent: Appearance.colors.colSecondaryContainer
                            onAccent: Appearance.colors.colOnSecondaryContainer
                        }
                        InfoTile {
                            Layout.fillWidth: true
                            icon: "terminal"
                            label: Translation.tr("Shell")
                            value: SystemInfo.shell
                            accent: Appearance.colors.colSecondaryContainer
                            onAccent: Appearance.colors.colOnSecondaryContainer
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: (homeGrid.width - 24) / 3
                spacing: 12

                DashboardCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(90, (homeGrid.height - 12) * 0.3)
                    tint: Appearance.colors.colTertiaryContainer
                    pager: root.pager
                    staggerMs: root.staggerMs
                    animIndex: 2
                    travelX: 0
                    travelY: -260

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                implicitWidth: 52
                                implicitHeight: 52
                                radius: 18
                                color: Appearance.colors.colTertiary

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: Updates.count > 0 ? "system_update_alt" : "check_circle"
                                    iconSize: 28
                                    fill: 1
                                    color: Appearance.colors.colOnTertiary
                                }
                            }

                            ColumnLayout {
                                spacing: 0

                                StyledText {
                                    text: !Updates.available ? Translation.tr("Updates") : Updates.count > 0 ? Updates.count + " " + Translation.tr("updates available") : Translation.tr("System up to date")
                                    font.pixelSize: Appearance.font.pixelSize.larger
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnTertiaryContainer
                                }
                                StyledText {
                                    text: !Updates.available ? Translation.tr("Update check unavailable") : Updates.checking ? Translation.tr("Checking...") : Translation.tr("Pacman + AUR")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnTertiaryContainer
                                    opacity: 0.75
                                }
                            }

                            Item { Layout.fillWidth: true }

                            RippleButton {
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                visible: Updates.available
                                implicitWidth: 40
                                implicitHeight: 40
                                buttonRadius: 20
                                colBackground: Qt.rgba(1, 1, 1, 0.1)
                                colBackgroundHover: Qt.rgba(1, 1, 1, 0.2)
                                downAction: () => Updates.refresh()
                                contentItem: Item {
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "refresh"
                                        iconSize: 22
                                        color: Appearance.colors.colOnTertiaryContainer
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 38
                                buttonRadius: 19
                                colBackground: Appearance.colors.colTertiary
                                colBackgroundHover: Appearance.colors.colTertiary
                                colRipple: Qt.rgba(1, 1, 1, 0.3)
                                downAction: () => DotsUpdater.runSystemUpdate()
                                contentItem: RowLayout {
                                    spacing: 6
                                    Item { Layout.fillWidth: true }
                                    MaterialSymbol {
                                        text: "system_update_alt"
                                        iconSize: 18
                                        color: Appearance.colors.colOnTertiary
                                    }
                                    StyledText {
                                        text: Translation.tr("Update system")
                                        font.weight: Font.Medium
                                        color: Appearance.colors.colOnTertiary
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                            }

                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 38
                                buttonRadius: 19
                                colBackground: Qt.rgba(1, 1, 1, 0.12)
                                colBackgroundHover: Qt.rgba(1, 1, 1, 0.22)
                                downAction: () => DotsUpdater.runUpdateDots()
                                contentItem: RowLayout {
                                    spacing: 6
                                    Item { Layout.fillWidth: true }
                                    MaterialSymbol {
                                        text: "deployed_code_update"
                                        iconSize: 18
                                        color: Appearance.colors.colOnTertiaryContainer
                                    }
                                    StyledText {
                                        text: Translation.tr("Update Dots")
                                        font.weight: Font.Medium
                                        color: Appearance.colors.colOnTertiaryContainer
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                            }
                        }
                    }
                }

                DashboardCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    tint: Appearance.colors.colLayer1
                    pager: root.pager
                    staggerMs: root.staggerMs
                    animIndex: 4
                    travelX: 0
                    travelY: 260

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ColumnLayout {
                                spacing: 0

                                StyledText {
                                    text: Translation.tr("Selected date")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                                StyledText {
                                    text: Qt.locale().toString(root.selectedDate, "ddd, d MMM")
                                    font.pixelSize: 28
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnLayer1
                                }
                            }

                            Item { Layout.fillWidth: true }

                            RippleButton {
                                visible: !root.viewingCurrentMonth || !root.sameDay(root.selectedDate, root.now)
                                implicitHeight: 34
                                horizontalPadding: 16
                                buttonRadius: 17
                                colBackground: Appearance.colors.colPrimaryContainer
                                colBackgroundHover: Appearance.colors.colPrimaryContainer
                                downAction: () => {
                                    root.viewMonth = new Date(root.now.getFullYear(), root.now.getMonth(), 1);
                                    root.selectedDate = new Date();
                                }
                                contentItem: RowLayout {
                                    spacing: 6
                                    MaterialSymbol {
                                        text: "today"
                                        iconSize: 18
                                        color: Appearance.colors.colOnPrimaryContainer
                                    }
                                    StyledText {
                                        text: Translation.tr("Today")
                                        color: Appearance.colors.colOnPrimaryContainer
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Appearance.colors.colOutlineVariant
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            StyledText {
                                Layout.fillWidth: true
                                text: Qt.locale().toString(root.viewMonth, "MMMM yyyy")
                                font.pixelSize: Appearance.font.pixelSize.larger
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnLayer1
                            }

                            Repeater {
                                model: [{ icon: "chevron_left", delta: -1 }, { icon: "chevron_right", delta: 1 }]

                                delegate: RippleButton {
                                    required property var modelData

                                    implicitWidth: 36
                                    implicitHeight: 36
                                    buttonRadius: 18
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    colRipple: Appearance.colors.colLayer1Active
                                    downAction: () => root.shiftMonth(modelData.delta)
                                    contentItem: Item {
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            iconSize: 22
                                            color: Appearance.colors.colOnLayer1
                                        }
                                    }
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                            columns: 7
                            rowSpacing: 4
                            columnSpacing: 2

                            Repeater {
                                model: 7

                                delegate: StyledText {
                                    required property int index
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.ShortFormat).charAt(0).toUpperCase()
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colSubtext
                                }
                            }

                            Repeater {
                                model: root.calendarRows * 7

                                delegate: Item {
                                    id: dayCell
                                    required property int index

                                    readonly property date cellDate: new Date(root.viewMonth.getFullYear(), root.viewMonth.getMonth(), 1 - root.viewOffset + index)
                                    readonly property bool inMonth: cellDate.getMonth() === root.viewMonth.getMonth()
                                    readonly property bool isToday: root.sameDay(cellDate, root.now)
                                    readonly property bool isSelected: root.sameDay(cellDate, root.selectedDate)
                                    readonly property bool isWeekend: cellDate.getDay() === 0 || cellDate.getDay() === 6

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredHeight: 1

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height, 38)
                                        height: width
                                        radius: width / 2
                                        visible: dayCell.inMonth
                                        color: dayCell.isSelected ? Appearance.colors.colPrimary
                                            : dayMouse.containsMouse ? Appearance.colors.colLayer1Hover
                                            : "transparent"
                                        border.width: dayCell.isToday && !dayCell.isSelected ? 1.5 : 0
                                        border.color: Appearance.colors.colPrimary

                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: dayCell.cellDate.getDate()
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            font.weight: dayCell.isSelected || dayCell.isToday ? Font.Bold : Font.Normal
                                            color: dayCell.isSelected ? Appearance.colors.colOnPrimary
                                                : dayCell.isToday ? Appearance.colors.colPrimary
                                                : dayCell.isWeekend ? Appearance.colors.colTertiary
                                                : Appearance.colors.colOnLayer1
                                        }
                                    }

                                    MouseArea {
                                        id: dayMouse
                                        anchors.fill: parent
                                        enabled: dayCell.inMonth
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectedDate = dayCell.cellDate
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: (homeGrid.width - 24) / 3
                spacing: 12

                DashboardCard {
                    id: clockCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 180
                    tint: Appearance.colors.colPrimaryContainer
                    pager: root.pager
                    staggerMs: root.staggerMs
                    animIndex: 3
                    travelX: 300
                    travelY: -120

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: clockCard.width
                                height: clockCard.height
                                radius: clockCard.cardRadius
                            }
                        }

                        MaterialShape {
                            id: sunShape
                            shape: MaterialShape.Shape.Sunny
                            implicitSize: Math.min(clockCard.height * 0.95, 210)
                            color: Appearance.colors.colPrimary
                            anchors.right: parent.right
                            anchors.rightMargin: -sunShape.implicitSize * 0.35
                            anchors.top: parent.top
                            anchors.topMargin: -sunShape.implicitSize * 0.15
                        }

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 16
                            spacing: 0

                            StyledText {
                                text: Qt.locale().toString(DateTime.clock.date, "dddd MMMM d")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                text: DateTime.use12HourFormat ? DateTime.time.replace(/\s*[ap]\.?\s?m\.?\s*$/i, "") : DateTime.time
                                color: Appearance.colors.colOnPrimaryContainer
                                font {
                                    pixelSize: 56
                                    weight: Config.options.background.widgets.clock.digital.font.weight
                                    family: Config.options.background.widgets.clock.digital.font.family
                                    variableAxes: ({
                                        "wdth": Config.options.background.widgets.clock.digital.font.width,
                                        "ROND": Config.options.background.widgets.clock.digital.font.roundness
                                    })
                                }
                            }

                            StyledText {
                                Layout.topMargin: -10
                                visible: DateTime.use12HourFormat
                                text: Qt.locale().toString(DateTime.clock.date, "AP")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: Appearance.colors.colPrimary
                            }
                        }

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 16
                            spacing: 0

                            StyledText {
                                text: Weather.data.city
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            StyledText {
                                text: Weather.data.description
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.75
                            }

                            RowLayout {
                                Layout.topMargin: 2
                                spacing: 8

                                MaterialSymbol {
                                    text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                                    iconSize: 30
                                    fill: 1
                                    color: Appearance.colors.colPrimary
                                }
                                StyledText {
                                    text: Weather.data.temp || "--"
                                    font.pixelSize: 28
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colPrimary
                                }
                            }
                        }
                    }
                }

                DashboardCard {
                    Layout.fillWidth: true
                    id: tasksCard
                    property bool adding: false
                    Layout.preferredHeight: tasksContent.implicitHeight + 28
                    tint: Appearance.colors.colSecondaryContainer
                    pager: root.pager
                    staggerMs: root.staggerMs
                    animIndex: 4
                    travelX: 300
                    travelY: 200

                    ColumnLayout {
                        id: tasksContent
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            MaterialShapeWrappedMaterialSymbol {
                                shape: MaterialShape.Shape.Clover4Leaf
                                text: root.pendingTasks === 0 && Todo.list.length > 0 ? "celebration" : "checklist"
                                iconSize: 26
                                fill: 1
                                padding: 11
                                color: Appearance.colors.colSecondary
                                colSymbol: Appearance.colors.colOnSecondary
                            }

                            ColumnLayout {
                                spacing: 0

                                StyledText {
                                    text: Translation.tr("Tasks")
                                    font.pixelSize: Appearance.font.pixelSize.larger
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnSecondaryContainer
                                }
                                StyledText {
                                    text: Todo.list.length === 0 ? Translation.tr("Nothing to do")
                                        : root.pendingTasks === 0 ? Translation.tr("All done")
                                        : root.pendingTasks + " " + Translation.tr("left")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSecondaryContainer
                                    opacity: 0.75
                                }
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: `${Todo.list.length - root.pendingTasks}/${Todo.list.length}`
                                font.pixelSize: Appearance.font.pixelSize.larger
                                font.weight: Font.Light
                                color: Appearance.colors.colOnSecondaryContainer
                            }

                            RippleButton {
                                implicitWidth: 32
                                implicitHeight: 32
                                buttonRadius: 16
                                colBackground: Appearance.colors.colPrimary
                                colBackgroundHover: Appearance.colors.colPrimaryHover
                                colRipple: Appearance.colors.colPrimaryActive
                                downAction: () => Qt.callLater(() => tasksCard.adding = true)
                                contentItem: Item {
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "add"
                                        iconSize: 20
                                        color: Appearance.colors.colOnPrimary
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 8
                            radius: 4
                            color: Qt.rgba(1, 1, 1, 0.12)

                            Rectangle {
                                height: parent.height
                                radius: 4
                                color: Appearance.colors.colSecondary
                                width: Todo.list.length === 0 ? 0 : parent.width * (Todo.list.length - root.pendingTasks) / Todo.list.length

                                Behavior on width {
                                    NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 3 * 40 + 2 * 6
                            clip: true
                            spacing: 6
                            model: Todo.list.map((t, i) => ({ content: t.content, done: t.done, origIndex: i }))

                            delegate: RippleButton {
                                required property var modelData

                                width: ListView.view.width
                                implicitHeight: 40
                                buttonRadius: 20
                                colBackground: Qt.rgba(1, 1, 1, modelData.done ? 0.05 : 0.1)
                                colBackgroundHover: Qt.rgba(1, 1, 1, 0.18)
                                colRipple: Qt.rgba(1, 1, 1, 0.3)
                                downAction: () => {
                                    const index = modelData.origIndex;
                                    const done = modelData.done;
                                    Qt.callLater(() => {
                                        if (done) Todo.markUnfinished(index);
                                        else Todo.markDone(index);
                                    });
                                }
                                altAction: () => {
                                    const index = modelData.origIndex;
                                    Qt.callLater(() => Todo.deleteItem(index));
                                }
                                contentItem: RowLayout {
                                    spacing: 10

                                    Rectangle {
                                        Layout.leftMargin: 4
                                        implicitWidth: 24
                                        implicitHeight: 24
                                        radius: 12
                                        color: modelData.done ? Appearance.colors.colSecondary : "transparent"
                                        border.width: modelData.done ? 0 : 2
                                        border.color: Appearance.colors.colOnSecondaryContainer

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            visible: modelData.done
                                            text: "check"
                                            iconSize: 16
                                            color: Appearance.colors.colOnSecondary
                                        }
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.content
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.strikeout: modelData.done
                                        color: Appearance.colors.colOnSecondaryContainer
                                        opacity: modelData.done ? 0.5 : 1
                                        elide: Text.ElideRight
                                    }
                                    RippleButton {
                                        implicitWidth: 28
                                        implicitHeight: 28
                                        buttonRadius: 14
                                        Layout.rightMargin: 6
                                        colBackground: "transparent"
                                        colBackgroundHover: Qt.rgba(1, 1, 1, 0.2)
                                        colRipple: Qt.rgba(1, 1, 1, 0.3)
                                        downAction: () => {
                                            const index = modelData.origIndex;
                                            Qt.callLater(() => Todo.deleteItem(index));
                                        }
                                        contentItem: Item {
                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "close"
                                                iconSize: 18
                                                color: Appearance.colors.colOnSecondaryContainer
                                                opacity: 0.6
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: addOverlay
                        anchors.fill: parent
                        visible: opacity > 0
                        opacity: tasksCard.adding ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }

                        onVisibleChanged: {
                            if (visible) todoInput.forceActiveFocus();
                            else todoInput.text = "";
                        }

                        function submit() {
                            if (todoInput.text.length === 0) return;
                            const text = todoInput.text;
                            tasksCard.adding = false;
                            Qt.callLater(() => Todo.addTask(text));
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: tasksCard.cardRadius
                            color: Appearance.colors.colScrim
                            MouseArea {
                                anchors.fill: parent
                                onClicked: tasksCard.adding = false
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 14
                            implicitHeight: addColumn.implicitHeight
                            height: implicitHeight
                            radius: Appearance.rounding.normal
                            color: Appearance.m3colors.m3surfaceContainerHigh

                            ColumnLayout {
                                id: addColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 14

                                StyledText {
                                    Layout.topMargin: 16
                                    Layout.leftMargin: 16
                                    text: Translation.tr("Add task")
                                    font.pixelSize: Appearance.font.pixelSize.larger
                                    color: Appearance.m3colors.m3onSurface
                                }

                                TextField {
                                    id: todoInput
                                    ContextMenu.menu: StyledTextEditMenu { editor: todoInput }
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 16
                                    Layout.rightMargin: 16
                                    padding: 10
                                    color: Appearance.m3colors.m3onSurface
                                    renderType: Text.NativeRendering
                                    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                                    selectionColor: Appearance.colors.colSecondaryContainer
                                    placeholderText: Translation.tr("Task description")
                                    placeholderTextColor: Appearance.m3colors.m3outline
                                    onAccepted: addOverlay.submit()
                                    Keys.onEscapePressed: event => {
                                        tasksCard.adding = false;
                                        event.accepted = true;
                                    }

                                    background: Rectangle {
                                        radius: Appearance.rounding.verysmall
                                        border.width: 2
                                        border.color: todoInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                                        color: "transparent"
                                    }

                                    cursorDelegate: Rectangle {
                                        width: 1
                                        color: Appearance.colors.colPrimary
                                        radius: 1
                                    }
                                }

                                RowLayout {
                                    Layout.bottomMargin: 16
                                    Layout.leftMargin: 16
                                    Layout.rightMargin: 16
                                    Layout.alignment: Qt.AlignRight
                                    spacing: 5

                                    DialogButton {
                                        buttonText: Translation.tr("Cancel")
                                        onClicked: tasksCard.adding = false
                                    }
                                    DialogButton {
                                        buttonText: Translation.tr("Add")
                                        enabled: todoInput.text.length > 0
                                        onClicked: addOverlay.submit()
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
