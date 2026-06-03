import QtQuick
import "Singletons"

Item {
    id: surface
    property real s: 1
    property var auth: null
    property string screenName: ""

    readonly property int blurDiv: 14
    readonly property size blurRes: Qt.size(Math.max(2, Math.round(width / blurDiv)), Math.max(2, Math.round(height / blurDiv)))
    readonly property vector2d blurResVec: Qt.vector2d(blurRes.width, blurRes.height)

    clip: true

    Image {
        id: bgImg
        anchors.fill: parent
        source: surface.screenName.length > 0 ? "file:///tmp/ricelin-lock-" + surface.screenName + ".png" : "file:///tmp/lock-dev-sharp.jpg"
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        cache: false
        visible: false
    }

    ShaderEffectSource {
        id: bgSrc
        anchors.fill: parent
        sourceItem: bgImg
        textureSize: surface.blurRes
        hideSource: true
        live: false
    }

    ShaderEffect {
        id: blurH
        anchors.fill: parent
        visible: false
        property var source: bgSrc
        property vector2d resolution: surface.blurResVec
        property vector2d blurDir: Qt.vector2d(1, 0)
        fragmentShader: "shaders/blur.frag.qsb"
    }

    ShaderEffectSource {
        id: blurHSrc
        anchors.fill: parent
        sourceItem: blurH
        textureSize: surface.blurRes
        hideSource: true
        live: true
    }

    ShaderEffect {
        id: blurV
        anchors.fill: parent
        visible: false
        property var source: blurHSrc
        property vector2d resolution: surface.blurResVec
        property vector2d blurDir: Qt.vector2d(0, 1)
        fragmentShader: "shaders/blur.frag.qsb"
    }

    ShaderEffectSource {
        id: blurVSrc
        anchors.fill: parent
        sourceItem: blurV
        textureSize: surface.blurRes
        hideSource: true
        live: true
    }

    AlbumPalette {
        id: palette
        artUrl: content.artUrl
    }

    ShaderEffect {
        anchors.fill: parent
        property var source: blurVSrc
        property color accent: palette.accent
        property real intensity: Theme.gradeIntensity
        fragmentShader: "shaders/grade.frag.qsb"
    }

    Content {
        id: content
        anchors.fill: parent
        s: surface.s
        accent: palette.accent
        auth: surface.auth
    }
}
