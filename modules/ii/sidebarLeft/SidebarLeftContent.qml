import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root
    required property var scopeRoot
    property int sidebarPadding: 10
    anchors.fill: parent
    property bool aiChatEnabled: Config.options.policies.ai !== 0
    property bool translatorEnabled: Config.options.sidebar.translator.enable
    property bool animeEnabled: Config.options.policies.weeb !== 0
    property bool animeCloset: Config.options.policies.weeb === 2
    property bool mediaEnabled: Config.options.sidebar.media.enable
    property bool footballEnabled: Config.options.sidebar.football.enable
    property bool appsEnabled: Config.options.sidebar.apps.enable

    readonly property var featurePages: [
        ...(root.aiChatEnabled ? [{"key": "ai", "icon": "neurology", "name": Translation.tr("Intelligence")}] : []),
        ...(root.appsEnabled ? [{"key": "apps", "icon": "apps", "name": Translation.tr("Applications")}] : []),
        ...(root.translatorEnabled ? [{"key": "translator", "icon": "translate", "name": Translation.tr("Translator")}] : []),
        ...(root.mediaEnabled ? [{"key": "media", "icon": "music_note", "name": Translation.tr("Media")}] : []),
        ...(root.footballEnabled ? [{"key": "sports", "icon": "sports", "name": Translation.tr("Sports")}] : []),
        ...((root.animeEnabled && !root.animeCloset) ? [{"key": "anime", "icon": "bookmark_heart", "name": Translation.tr("Anime")}] : [])
    ]
    readonly property var pageKeys: ["home", ...root.featurePages.map(page => page.key)]
    property string currentKey: "home"
    readonly property int currentIndex: Math.max(0, root.pageKeys.indexOf(root.currentKey))
    readonly property var currentPage: root.featurePages.find(page => page.key === root.currentKey) ?? null
    property bool restored: false

    function goTo(key) {
        if (root.pageKeys.indexOf(key) < 0) key = "home"
        root.currentKey = key
        if (Config.options.sidebar.leftRememberPage) Config.options.sidebar.leftLastPage = key
    }

    function step(delta) {
        const next = (root.currentIndex + delta + root.pageKeys.length) % root.pageKeys.length
        root.goTo(root.pageKeys[next])
    }

    function focusActiveItem() {
        const slot = pageStack.children.find(child => child.current === true)
        slot?.item?.forceActiveFocus()
    }

    Component.onCompleted: {
        const saved = Config.options.sidebar.leftLastPage
        if (Config.options.sidebar.leftRememberPage && root.pageKeys.indexOf(saved) >= 0) root.currentKey = saved
        root.restored = true
    }

    onPageKeysChanged: {
        if (root.restored && root.pageKeys.indexOf(root.currentKey) < 0) root.currentKey = "home"
    }

    Keys.onPressed: (event) => {
        if (event.modifiers === Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown) {
                root.step(1)
                event.accepted = true;
            }
            else if (event.key === Qt.Key_PageUp) {
                root.step(-1)
                event.accepted = true;
            }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: sidebarPadding
        }
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            visible: root.currentKey !== "home"
            spacing: 8

            RippleButton {
                implicitWidth: 40
                implicitHeight: 40
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: root.goTo("home")
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            MaterialSymbol {
                text: root.currentPage?.icon ?? ""
                fill: 1
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colPrimary
            }

            StyledText {
                Layout.fillWidth: true
                text: root.currentPage?.name ?? ""
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }

            Repeater {
                model: root.featurePages.filter(page => page.key !== root.currentKey)
                delegate: RippleButton {
                    required property var modelData
                    implicitWidth: 36
                    implicitHeight: 36
                    buttonRadius: Appearance.rounding.full
                    onClicked: root.goTo(modelData.key)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.icon
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colSubtext
                    }
                    StyledToolTip { text: modelData.name }
                }
            }
        }

        ClippingRectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            Item { // Content pages
                id: pageStack
                anchors.fill: parent

                component PageSlot: SidebarPop {
                    id: slot
                    required property string pageKey
                    property bool enabledPage: true
                    property Component page: null
                    property bool lingering: false
                    property bool visited: false
                    readonly property bool current: root.currentKey === pageKey
                    readonly property bool isHome: pageKey === "home"
                    readonly property alias item: loader.item

                    anchors.fill: parent
                    active: current
                    visible: current || lingering
                    minScale: isHome ? 1 : 0.97
                    travelX: 0
                    travelY: isHome ? 0 : 20
                    fade: !isHome
                    animIndex: 0
                    smooth: !isHome

                    Component.onCompleted: if (current) visited = true

                    onCurrentChanged: {
                        if (current) visited = true
                        if (!current) {
                            lingering = true
                            lingerTimer.restart()
                        }
                    }

                    Timer {
                        id: lingerTimer
                        interval: 760
                        onTriggered: slot.lingering = false
                    }

                    Loader {
                        id: loader
                        anchors.fill: parent
                        asynchronous: !slot.isHome
                        active: slot.enabledPage && (slot.isHome || slot.visited)
                        sourceComponent: slot.page
                        onLoaded: if (slot.isHome) item.active = Qt.binding(() => slot.current)
                    }
                }

                PageSlot { pageKey: "home"; page: home }
                PageSlot { pageKey: "ai"; enabledPage: root.aiChatEnabled; page: aiChat }
                PageSlot { pageKey: "apps"; enabledPage: root.appsEnabled; page: apps }
                PageSlot { pageKey: "translator"; enabledPage: root.translatorEnabled; page: translator }
                PageSlot { pageKey: "media"; enabledPage: root.mediaEnabled; page: media }
                PageSlot { pageKey: "sports"; enabledPage: root.footballEnabled; page: football }
                PageSlot { pageKey: "anime"; enabledPage: root.animeEnabled && !root.animeCloset; page: anime }
            }
        }

        Component {
            id: home
            SidebarHomePage {
                pages: root.featurePages
                onPageRequested: key => root.goTo(key)
            }
        }
        Component {
            id: aiChat
            AiChat {}
        }
        Component {
            id: apps
            AppsPage {}
        }
        Component {
            id: translator
            Translator {}
        }
        Component {
            id: media
            SidebarPlayerControl {}
        }
        Component {
            id: football
            FootballPage {}
        }
        Component {
            id: anime
            Anime {}
        }
    }
}
