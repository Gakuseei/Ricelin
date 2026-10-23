import QtQuick
import QtQuick.Effects
import "Singletons"
import "lib/tips.js" as Tips

/**
 * Hint bubble above or below its control, drawn on the window's top layer so nothing covers or clips it; it never takes pointer events.
 */
Item {
    id: root

    property real s: 1
    property string title: ""
    property string desc: ""
    property bool show: false
    property string placement: "above"

    readonly property bool below: placement === "below"
    readonly property real pointerH: 5 * s
    readonly property real gap: 5 * s
    readonly property real edge: 8 * s

    property bool armed: false
    property Item host: null
    property real pointerX: tip.width / 2

    width: 0
    height: 0

    /**
     * Finds the window's top item and places the bubble there, kept inside the window with the pointer still on the control.
     */
    function place() {
        const a = root.parent;
        if (!a)
            return;
        let top = a;
        while (top.parent)
            top = top.parent;
        root.host = top;
        const p = a.mapToItem(top, a.width / 2, root.below ? a.height + root.gap : -root.gap);
        const x = Math.max(root.edge, Math.min(top.width - tip.width - root.edge, p.x - tip.width / 2));
        tip.x = Math.round(x);
        tip.y = Math.round(root.below ? p.y : p.y - tip.height);
        root.pointerX = Math.max(bubble.radius + 6 * root.s, Math.min(tip.width - bubble.radius - 6 * root.s, p.x - x));
    }

    function arm() {
        place();
        armed = true;
    }

    Timer {
        id: delay
        interval: 470
        onTriggered: root.arm()
    }
    onShowChanged: {
        if (show) {
            if (Date.now() - Tips.lastHide < 600)
                arm();
            else
                delay.restart();
        } else {
            delay.stop();
            if (armed)
                Tips.lastHide = Date.now();
            armed = false;
        }
    }

    Item {
        id: tip
        parent: root.host
        z: 1000
        width: bubble.width
        height: bubble.height + root.pointerH
        visible: root.armed || opacity > 0.01
        opacity: root.armed ? 1 : 0
        scale: root.armed || Motion.calm ? 1 : 0.96
        transformOrigin: root.below ? Item.Top : Item.Bottom
        Behavior on opacity { NumberAnimation { duration: root.armed ? Motion.fast : 100; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

        Rectangle {
            id: bubble
            anchors.top: root.below ? undefined : parent.top
            anchors.bottom: root.below ? parent.bottom : undefined
            width: Math.max(titleText.implicitWidth, descText.implicitWidth) + 2 * Theme.sp.m * root.s
            height: column.implicitHeight + 2 * Theme.sp.s * root.s
            radius: Theme.r.m * root.s
            border.width: 1
            border.color: Theme.frameBorder
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.cardTop }
                GradientStop { position: 1.0; color: Theme.cardBot }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.shadow
                shadowBlur: 0.6
                shadowVerticalOffset: 4 * root.s
            }
        }

        Column {
            id: column
            anchors.centerIn: bubble
            spacing: Theme.sp.xxs * root.s

            Text {
                id: titleText
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.title
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                font.weight: Font.Bold
            }
            Text {
                id: descText
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.desc.length > 0
                text: root.desc
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
            }
        }

        Canvas {
            width: 11 * root.s
            height: root.pointerH
            x: root.pointerX - width / 2
            anchors.top: root.below ? parent.top : undefined
            anchors.bottom: root.below ? undefined : parent.bottom
            property color fill: Theme.cardBot
            onFillChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = fill;
                ctx.beginPath();
                if (root.below) {
                    ctx.moveTo(0, height);
                    ctx.lineTo(width, height);
                    ctx.lineTo(width / 2, 0);
                } else {
                    ctx.moveTo(0, 0);
                    ctx.lineTo(width, 0);
                    ctx.lineTo(width / 2, height);
                }
                ctx.closePath();
                ctx.fill();
            }
        }
    }
}
