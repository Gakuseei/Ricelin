pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import "Singletons"

Item {
    id: surface
    property real s: 1
    property var auth: null
    property string screenName: ""

    /**
     * Drives the lock-open morph. A pill-shaped hole grows from the pill's resting
     * spot out to the full screen, wiping the lock open over the grabbed desktop.
     * The grow waits for the grab so it reveals onto the real desktop, the collapse
     * just runs on unlock.
     */
    property bool active: false
    property real maskP: 0

    readonly property bool overlayReady: deskOverlay.status === Image.Ready
    readonly property bool shouldOpen: active && overlayReady
    onShouldOpenChanged: if (shouldOpen)
        openAnim.restart()
    onActiveChanged: if (!active)
        closeAnim.restart()

    /**
     * The lock UI's primary screen is just the first one Quickshell reports, so
     * the auth panel lands on one deterministic monitor without pinning a display
     * name that only exists on Erik's machine.
     */
    readonly property bool isMain: {
        var scr = Quickshell.screens;
        if (scr.length === 0)
            return true;
        return surface.screenName === scr[0].name;
    }

    readonly property real spread: 2.4
    readonly property size half: Qt.size(Math.max(2, Math.round(width / 2)), Math.max(2, Math.round(height / 2)))
    readonly property size quarter: Qt.size(Math.max(2, Math.round(width / 4)), Math.max(2, Math.round(height / 4)))
    readonly property size eighth: Qt.size(Math.max(2, Math.round(width / 8)), Math.max(2, Math.round(height / 8)))
    readonly property vector2d eighthVec: Qt.vector2d(eighth.width, eighth.height)

    readonly property string shotSource: {
        if (surface.screenName.length === 0)
            return "";
        var dir = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp";
        return "file://" + dir + "/ricelin-lock-" + surface.screenName + ".png";
    }

    clip: true

    /**
     * The blurred desktop backdrop. It is the whole build cost, so it loads a beat
     * after the surface mounts; the cheap sharp overlay and clock are up first,
     * which keeps the compositor from showing a black gap while this instantiates.
     * The hole reveals this once the pill grows.
     */
    Loader {
        id: blurLayer
        anchors.fill: parent
        active: true
        asynchronous: true

        sourceComponent: Component {
          Item {
            anchors.fill: parent

            Image {
                id: bgImg
                anchors.fill: parent
                source: surface.shotSource
                fillMode: Image.PreserveAspectCrop
                smooth: true
                cache: false
                asynchronous: true
                visible: false
            }

            ShaderEffectSource {
                id: downHalf
                anchors.fill: parent
                sourceItem: bgImg
                textureSize: surface.half
                smooth: true
                hideSource: true
                visible: false
            }

            ShaderEffect {
                id: copyHalf
                anchors.fill: parent
                visible: false
                property var source: downHalf
            }

            ShaderEffectSource {
                id: downQuarter
                anchors.fill: parent
                sourceItem: copyHalf
                textureSize: surface.quarter
                smooth: true
                hideSource: true
                visible: false
            }

            ShaderEffect {
                id: copyQuarter
                anchors.fill: parent
                visible: false
                property var source: downQuarter
            }

            ShaderEffectSource {
                id: downEighth
                anchors.fill: parent
                sourceItem: copyQuarter
                textureSize: surface.eighth
                smooth: true
                hideSource: true
                visible: false
            }

            ShaderEffect {
                id: blurH1
                anchors.fill: parent
                visible: false
                property var source: downEighth
                property vector2d resolution: surface.eighthVec
                property vector2d blurDir: Qt.vector2d(1, 0)
                property real spread: surface.spread
                fragmentShader: "shaders/blur.frag.qsb"
            }

            ShaderEffectSource {
                id: blurH1Src
                anchors.fill: parent
                sourceItem: blurH1
                textureSize: surface.eighth
                smooth: true
                hideSource: true
                visible: false
            }

            ShaderEffect {
                id: blurV1
                anchors.fill: parent
                visible: false
                property var source: blurH1Src
                property vector2d resolution: surface.eighthVec
                property vector2d blurDir: Qt.vector2d(0, 1)
                property real spread: surface.spread
                fragmentShader: "shaders/blur.frag.qsb"
            }

            ShaderEffectSource {
                id: blurV1Src
                anchors.fill: parent
                sourceItem: blurV1
                textureSize: surface.eighth
                smooth: true
                hideSource: true
                visible: false
            }

            ShaderEffect {
                id: blurH2
                anchors.fill: parent
                visible: false
                property var source: blurV1Src
                property vector2d resolution: surface.eighthVec
                property vector2d blurDir: Qt.vector2d(1, 0)
                property real spread: surface.spread
                fragmentShader: "shaders/blur.frag.qsb"
            }

            ShaderEffectSource {
                id: blurH2Src
                anchors.fill: parent
                sourceItem: blurH2
                textureSize: surface.eighth
                smooth: true
                hideSource: true
                visible: false
            }

            ShaderEffect {
                id: blurV2
                anchors.fill: parent
                visible: false
                property var source: blurH2Src
                property vector2d resolution: surface.eighthVec
                property vector2d blurDir: Qt.vector2d(0, 1)
                property real spread: surface.spread
                fragmentShader: "shaders/blur.frag.qsb"
            }

            ShaderEffectSource {
                id: blurV2Src
                anchors.fill: parent
                sourceItem: blurV2
                textureSize: surface.eighth
                smooth: true
                hideSource: true
                visible: false
            }

            ShaderEffect {
                id: blurH3
                anchors.fill: parent
                visible: false
                property var source: blurV2Src
                property vector2d resolution: surface.eighthVec
                property vector2d blurDir: Qt.vector2d(1, 0)
                property real spread: surface.spread
                fragmentShader: "shaders/blur.frag.qsb"
            }

            ShaderEffectSource {
                id: blurH3Src
                anchors.fill: parent
                sourceItem: blurH3
                textureSize: surface.eighth
                smooth: true
                hideSource: true
                visible: false
            }

            ShaderEffect {
                id: blurV3
                anchors.fill: parent
                visible: false
                property var source: blurH3Src
                property vector2d resolution: surface.eighthVec
                property vector2d blurDir: Qt.vector2d(0, 1)
                property real spread: surface.spread
                fragmentShader: "shaders/blur.frag.qsb"
            }

            ShaderEffectSource {
                id: blurV3Src
                anchors.fill: parent
                sourceItem: blurV3
                textureSize: surface.eighth
                smooth: true
                hideSource: true
                visible: false
            }

            ShaderEffect {
                anchors.fill: parent
                property var source: blurV3Src
                property vector2d srcSize: surface.eighthVec
                property real darken: 0.62
                fragmentShader: "shaders/grade.frag.qsb"
            }
          }
        }
    }

    GlowField {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.55
    }

    Content {
        anchors.fill: parent
        s: surface.s
        auth: surface.auth
        isMain: surface.isMain
    }

    /**
     * The frozen desktop grab, sharp and opaque, punched with a pill-shaped hole.
     * As the hole grows the lock wipes open; outside the hole you keep seeing your
     * own desktop, never black. Loaded synchronously so it is ready the frame the
     * lock mounts and the reveal never opens onto a blank.
     */
    Image {
        id: deskOverlay
        anchors.fill: parent
        source: surface.shotSource
        fillMode: Image.PreserveAspectCrop
        smooth: true
        cache: false
        asynchronous: false
        visible: false
        layer.enabled: true
    }

    Item {
        id: maskItem
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            color: "white"
            antialiasing: true

            readonly property real pillW: 160 * surface.s
            readonly property real pillH: 38 * surface.s
            readonly property real pillY: 8 * Flags.topGap * surface.s

            width: pillW + (surface.width - pillW) * surface.maskP
            height: pillH + (surface.height - pillH) * surface.maskP
            x: (surface.width - width) / 2
            y: pillY * (1 - surface.maskP)
            /** Corner follows the current height so the hole stays a rounded stadium the whole way, then eases to square edges only as it fills the screen. */
            radius: (height / 2) * (1 - surface.maskP)
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: deskOverlay
        maskEnabled: true
        maskInverted: true
        maskSource: maskItem
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    /**
     * The open eases in and out so it grows on smoothly instead of popping, the
     * close keeps the liquid pillMorph curve that already feels right.
     */
    NumberAnimation {
        id: openAnim
        target: surface
        property: "maskP"
        to: 1
        duration: 620
        easing.type: Easing.InOutCubic
    }

    NumberAnimation {
        id: closeAnim
        target: surface
        property: "maskP"
        to: 0
        duration: 620
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
    }
}
