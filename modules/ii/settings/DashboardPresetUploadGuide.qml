import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string presetName: ""

    signal proceed()
    signal cancel()

    readonly property var steps: [
        {
            icon: "image",
            title: Translation.tr("Choose a preview image"),
            body: Translation.tr("A file manager opens right after you continue. The picture you pick there becomes the preview everyone sees in the gallery. Choose a screenshot of your desktop with the bar visible, in 16:9, without private windows or notifications."),
            emphasized: true
        },
        {
            icon: "terminal",
            title: Translation.tr("Sign in to GitHub, only once"),
            body: Translation.tr("If the GitHub CLI (gh) is missing, a terminal opens to install it and sign you in through your browser. Nothing is typed in the shell and your password is never stored. If you already use gh, this step is skipped."),
            emphasized: false
        },
        {
            icon: "cloud_upload",
            title: Translation.tr("The shell sends it for you"),
            body: Translation.tr("A pull request is opened on the community gallery with your preset and the image. When it is done you get a notification and the link."),
            emphasized: false
        },
        {
            icon: "verified",
            title: Translation.tr("Checked before it appears"),
            body: Translation.tr("Every preset is checked automatically and new authors are reviewed by hand. Once it is merged it shows up for everyone, and you can take it back any time with Remove from gallery."),
            emphasized: false
        },
        {
            icon: "lock",
            title: Translation.tr("Only the look is shared"),
            body: Translation.tr("Fonts, accounts, keys, commands and your clipboard stay on your computer. Everything you upload is public, so only use images you own or are free to share."),
            emphasized: false
        }
    ]

    opacity: 0
    Component.onCompleted: opacity = 1

    Behavior on opacity {
        NumberAnimation { duration: 220 }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 760
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

            StyledText {
                text: Translation.tr("Share your preset")
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Here is what happens when you upload \"%1\".").arg(PresetsOnline.displayName(root.presetName).replace(/_/g, " "))
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                opacity: 0.75
                elide: Text.ElideRight
            }
        }

        StyledFlickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: stepsColumn.implicitHeight

            ColumnLayout {
                id: stepsColumn
                width: Math.min(flick.width, 760)
                x: (flick.width - width) / 2
                spacing: 8

                Repeater {
                    model: root.steps

                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: cardRow.implicitHeight + 28
                        radius: Appearance.rounding.small
                        color: modelData.emphasized ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer1

                        RowLayout {
                            id: cardRow
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 14

                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                implicitWidth: 44
                                implicitHeight: 44
                                radius: 12
                                color: card.modelData.emphasized ? Appearance.colors.colSecondary : Appearance.colors.colSecondaryContainer

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: card.modelData.icon
                                    iconSize: 24
                                    fill: 1
                                    color: card.modelData.emphasized ? Appearance.colors.colOnSecondary : Appearance.colors.colOnSecondaryContainer
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                StyledText {
                                    Layout.fillWidth: true
                                    text: `${card.index + 1}. ${card.modelData.title}`
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.Medium
                                    color: card.modelData.emphasized ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: card.modelData.body
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    wrapMode: Text.WordWrap
                                    color: card.modelData.emphasized ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                    opacity: 0.85
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 760
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Item { Layout.fillWidth: true }

            RippleButton {
                implicitHeight: 48
                horizontalPadding: 22
                buttonRadius: 24
                border: true
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colLayer1Active
                downAction: () => Qt.callLater(() => root.cancel())
                contentItem: RowLayout {
                    spacing: 8
                    MaterialSymbol {
                        text: "close"
                        iconSize: 20
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: Translation.tr("Cancel")
                        color: Appearance.colors.colOnLayer1
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
                downAction: () => Qt.callLater(() => root.proceed())
                contentItem: RowLayout {
                    spacing: 8
                    MaterialSymbol {
                        text: "arrow_forward"
                        iconSize: 22
                        fill: 1
                        color: Appearance.colors.colOnPrimary
                    }
                    StyledText {
                        text: Translation.tr("Continue")
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }
        }
    }
}
