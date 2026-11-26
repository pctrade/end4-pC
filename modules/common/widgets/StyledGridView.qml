import QtQuick

/** A GridView with the same touchpad sensitivity as lists and pages. */
GridView {
    id: root
    TouchpadScrollArea { flickable: root }
}
