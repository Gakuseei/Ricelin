import QtQuick
import "Singletons"

Item {
    id: surface
    property real s: 1

    clip: true

    Image {
        id: bgImg
        anchors.fill: parent
        source: "file:///tmp/lock-dev-sharp.jpg"
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
        hideSource: true
        live: false
    }

    ShaderEffect {
        id: blurH
        anchors.fill: parent
        visible: false
        property var source: bgSrc
        property vector2d resolution: Qt.vector2d(width, height)
        property vector2d blurDir: Qt.vector2d(1, 0)
        fragmentShader: "shaders/blur.frag.qsb"
    }

    ShaderEffectSource {
        id: blurHSrc
        anchors.fill: parent
        sourceItem: blurH
        hideSource: true
        live: true
    }

    ShaderEffect {
        id: blurV
        anchors.fill: parent
        visible: false
        property var source: blurHSrc
        property vector2d resolution: Qt.vector2d(width, height)
        property vector2d blurDir: Qt.vector2d(0, 1)
        fragmentShader: "shaders/blur.frag.qsb"
    }

    ShaderEffectSource {
        id: blurVSrc
        anchors.fill: parent
        sourceItem: blurV
        hideSource: true
        live: true
    }

    ShaderEffect {
        anchors.fill: parent
        property var source: blurVSrc
        property color accent: Theme.accent
        property real intensity: Theme.gradeIntensity
        fragmentShader: "shaders/grade.frag.qsb"
    }

    Content {
        anchors.fill: parent
        s: surface.s
    }
}
