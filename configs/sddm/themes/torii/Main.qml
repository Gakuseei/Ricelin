import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtMultimedia

Item {
    id: root
    width: 1920
    height: 1080

    readonly property bool hasSddm: typeof sddm !== "undefined"
    readonly property bool hasConfig: typeof config !== "undefined"

    function cfg(key, fallback) {
        if (!hasConfig)
            return fallback
        var v = config[key]
        return (v === undefined || v === null || ("" + v).length === 0) ? fallback : v
    }

    readonly property real userScale: parseFloat(cfg("scale", "1.0")) || 1.0
    readonly property real s: (Screen.height > 0 ? Screen.height / 1080 : 1) * userScale

    readonly property color verm: cfg("accent", "#c0442b")
    readonly property color vermDeep: "#a3371f"
    readonly property color vermGlow: Qt.rgba(192 / 255, 68 / 255, 43 / 255, 0.9)
    readonly property color cream: "#e6d6cb"
    readonly property color brightWhite: "#fff6f0"
    readonly property color dim: "#aeb3bd"
    readonly property color dim2: "#9298a3"
    readonly property color hair: Qt.rgba(150 / 255, 172 / 255, 212 / 255, 0.2)
    readonly property color hairStrong: Qt.rgba(150 / 255, 172 / 255, 212 / 255, 0.32)
    readonly property color emberBase: "#1D120E"

    property int currentUserIndex: hasSddm ? Math.max(0, userProbe.lastIndex) : 0
    property int currentSessionIndex: hasSddm ? Math.max(0, sessionProbe.lastIndex) : 0

    readonly property string currentUserName: {
        if (!hasSddm)
            return "erik"
        var n = userProbe.fieldAt(currentUserIndex, "name")
        return n.length > 0 ? n : "user"
    }
    readonly property string currentUserReal: {
        if (!hasSddm)
            return "erik"
        var r = userProbe.fieldAt(currentUserIndex, "realName")
        return r.length > 0 ? r : currentUserName
    }
    readonly property url currentUserIcon: hasSddm ? userProbe.iconAt(currentUserIndex) : ""

    readonly property string currentSessionName: {
        if (!hasSddm)
            return "Hyprland"
        var n = sessionProbe.fieldAt(currentSessionIndex, "name")
        return n.length > 0 ? n : "Session"
    }

    function submit() {
        errorRow.shown = false
        if (hasSddm)
            sddm.login(currentUserName, passwordField.text, currentSessionIndex)
    }

    function clearPassword() {
        passwordField.text = ""
        passwordField.forceActiveFocus()
    }

    ModelProbe {
        id: userProbe
        sourceModel: hasSddm ? userModel : null
        lastIndex: hasSddm ? userModel.lastIndex : 0
    }

    ModelProbe {
        id: sessionProbe
        sourceModel: hasSddm ? sessionModel : null
        lastIndex: hasSddm ? sessionModel.lastIndex : 0
    }

    component ModelProbe: Item {
        id: probe
        property var sourceModel: null
        property int lastIndex: 0
        readonly property int count: rep.count
        property int version: 0
        property var rows: ({})

        function record(row, field, value) {
            probe.rows[row + ":" + field] = (value === undefined || value === null) ? "" : value
            probe.version++
        }
        function fieldAt(row, field) {
            void probe.version
            var v = probe.rows[row + ":" + field]
            return (v === undefined || v === null) ? "" : "" + v
        }
        function iconAt(row) {
            void probe.version
            var v = probe.rows[row + ":icon"]
            return (v === undefined || v === null) ? "" : v
        }

        Repeater {
            id: rep
            model: probe.sourceModel
            delegate: Item {
                required property int index
                required property var model
                Component.onCompleted: {
                    probe.record(index, "name", model.name)
                    probe.record(index, "realName", model.realName)
                    probe.record(index, "comment", model.comment)
                    probe.record(index, "icon", model.icon)
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.emberBase
        z: -2000
    }

    MediaPlayer {
        id: bgPlayer
        source: Qt.resolvedUrl(root.cfg("background", "assets/bg.mp4"))
        videoOutput: bgVideo
        loops: MediaPlayer.Infinite
        Component.onCompleted: bgPlayer.play()
    }

    VideoOutput {
        id: bgVideo
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        z: -1000
    }

    Rectangle {
        anchors.fill: parent
        z: -900
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(14 / 255, 8 / 255, 5 / 255, 0.28) }
            GradientStop { position: 0.26; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(14 / 255, 8 / 255, 5 / 255, 0.74) }
        }
    }

    Item {
        id: embers
        anchors.fill: parent
        z: 5
        Repeater {
            model: 18
            delegate: Rectangle {
                id: ember
                required property int index
                readonly property real sz: (2 + (index * 37 % 25) / 10) * root.s
                readonly property bool vermilion: index % 7 === 5 || index % 7 === 2
                readonly property real travel: (300 + (index * 53 % 90)) * root.s
                readonly property real drift: ((index * 29 % 36) - 18) * root.s
                readonly property int dur: 6000 + (index * 411 % 7000)
                readonly property int startDelay: -(index * 523 % dur)

                width: sz
                height: sz
                radius: sz / 2
                color: vermilion ? root.verm : "#ffcf7a"
                opacity: 0
                x: (index * 61 % 100) / 100 * embers.width
                y: embers.height + 10

                SequentialAnimation {
                    running: true
                    loops: Animation.Infinite
                    ParallelAnimation {
                        NumberAnimation {
                            target: ember
                            property: "y"
                            from: embers.height + 10
                            to: embers.height + 10 - ember.travel
                            duration: ember.dur
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: ember
                            property: "x"
                            from: (ember.index * 61 % 100) / 100 * embers.width
                            to: (ember.index * 61 % 100) / 100 * embers.width + ember.drift
                            duration: ember.dur
                            easing.type: Easing.InOutSine
                        }
                        SequentialAnimation {
                            NumberAnimation { target: ember; property: "opacity"; from: 0; to: 0.9; duration: ember.dur * 0.1 }
                            NumberAnimation { target: ember; property: "opacity"; to: 0.5; duration: ember.dur * 0.7 }
                            NumberAnimation { target: ember; property: "opacity"; to: 0; duration: ember.dur * 0.2 }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: petals
        anchors.fill: parent
        z: 4
        Repeater {
            model: 14
            delegate: Rectangle {
                id: petal
                required property int index
                readonly property real sz: (7 + (index * 43 % 50) / 10) * root.s
                readonly property real travel: (480 + (index * 67 % 120)) * root.s
                readonly property real drift: ((index * 71 % 100) - 20) * root.s
                readonly property int dur: 7000 + (index * 389 % 6000)

                width: sz
                height: sz
                radius: sz * 0.45
                color: index % 2 === 0 ? "#e0879b" : "#d76f86"
                opacity: 0
                x: (index * 73 % 100) / 100 * petals.width
                y: -14
                transformOrigin: Item.Center

                SequentialAnimation {
                    running: true
                    loops: Animation.Infinite
                    ParallelAnimation {
                        NumberAnimation {
                            target: petal
                            property: "y"
                            from: -14
                            to: petal.travel
                            duration: petal.dur
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: petal
                            property: "x"
                            from: (petal.index * 73 % 100) / 100 * petals.width
                            to: (petal.index * 73 % 100) / 100 * petals.width + petal.drift
                            duration: petal.dur
                            easing.type: Easing.InOutSine
                        }
                        RotationAnimation {
                            target: petal
                            from: 0
                            to: 420
                            duration: petal.dur
                            easing.type: Easing.Linear
                        }
                        SequentialAnimation {
                            NumberAnimation { target: petal; property: "opacity"; from: 0; to: 0.75; duration: petal.dur * 0.1 }
                            NumberAnimation { target: petal; property: "opacity"; to: 0.55; duration: petal.dur * 0.8 }
                            NumberAnimation { target: petal; property: "opacity"; to: 0; duration: petal.dur * 0.1 }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: topLeft
        z: 10
        x: parent.width * 0.055
        y: parent.height * 0.065

        Rectangle {
            id: pulseDot
            width: 7 * root.s
            height: 7 * root.s
            radius: width / 2
            color: root.verm
            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 1200; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 2.6
                height: width
                radius: width / 2
                color: "transparent"
                border.width: parent.width * 0.9
                border.color: root.vermGlow
                opacity: 0.35 * parent.opacity
            }
        }

        Text {
            id: clock
            anchors.left: parent.left
            anchors.top: pulseDot.bottom
            anchors.topMargin: 13 * root.s
            color: root.brightWhite
            font.family: "Inter"
            font.weight: 340
            font.pixelSize: 52 * root.s
            font.letterSpacing: 1 * root.s
            text: clockTimer.timeText
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.92)
        }

        Text {
            anchors.left: parent.left
            anchors.top: clock.bottom
            anchors.topMargin: 8 * root.s
            color: root.cream
            font.family: "Inter"
            font.weight: 600
            font.pixelSize: 11 * root.s
            font.letterSpacing: 3.5 * root.s
            font.capitalization: Font.AllUppercase
            text: clockTimer.dateText
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.92)
        }
    }

    Timer {
        id: clockTimer
        property string timeText: ""
        property string dateText: ""
        readonly property var weekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        readonly property var months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            var hh = ("0" + d.getHours()).slice(-2)
            var mm = ("0" + d.getMinutes()).slice(-2)
            timeText = hh + ":" + mm
            dateText = weekdays[d.getDay()] + " · " + months[d.getMonth()] + " " + d.getDate()
        }
    }

    Column {
        id: shrineColumn
        z: 10
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.86 - height
        spacing: 15 * root.s

        Row {
            id: userChip
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 11 * root.s
            padding: 2 * root.s

            Rectangle {
                id: avatar
                anchors.verticalCenter: parent.verticalCenter
                width: 30 * root.s
                height: 30 * root.s
                radius: width / 2
                border.width: 1.5 * root.s
                border.color: root.verm
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#3a2a22" }
                    GradientStop { position: 1.0; color: "#1d120e" }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 1.5
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 2 * root.s
                    border.color: Qt.rgba(192 / 255, 68 / 255, 43 / 255, 0.45)
                    opacity: 0.7
                }

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    anchors.margins: 1.5 * root.s
                    fillMode: Image.PreserveAspectCrop
                    source: root.currentUserIcon
                    visible: false
                    smooth: true
                }

                Item {
                    id: avatarMask
                    anchors.fill: avatarImg
                    layer.enabled: true
                    layer.smooth: true
                    visible: false
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "black"
                    }
                }

                MultiEffect {
                    anchors.fill: avatarImg
                    source: avatarImg
                    maskEnabled: true
                    maskSource: avatarMask
                    visible: avatarImg.status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: avatarImg.status !== Image.Ready
                    text: root.currentUserName.length > 0 ? root.currentUserName.charAt(0).toUpperCase() : "?"
                    color: root.cream
                    font.family: "Inter"
                    font.weight: 600
                    font.pixelSize: 13 * root.s
                }
            }

            Text {
                id: userNameText
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentUserName
                opacity: userHover.hovered ? 0.85 : 1.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                color: root.brightWhite
                font.family: "Inter"
                font.weight: 600
                font.pixelSize: 16 * root.s
                font.letterSpacing: 0.3 * root.s
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.9)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.hasSddm || userProbe.count > 1
                text: "⌄"
                color: root.cream
                font.family: "Inter"
                font.pixelSize: 12 * root.s
                rotation: userPopup.opened ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            HoverHandler {
                id: userHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                enabled: !root.hasSddm || userProbe.count > 1
                onTapped: userPopup.toggle()
            }
        }

        Row {
            id: ornament
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14 * root.s
            opacity: 0.95

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 52 * root.s
                height: 1
                color: root.hairStrong
            }

            Item {
                id: torii
                anchors.verticalCenter: parent.verticalCenter
                width: 26 * root.s
                height: 20 * root.s

                Rectangle {
                    id: kasagi
                    x: -2 * root.s
                    y: 0
                    width: parent.width + 4 * root.s
                    height: 3.5 * root.s
                    radius: 2 * root.s
                    color: root.verm
                }
                Rectangle {
                    x: 3 * root.s
                    y: 7 * root.s
                    width: parent.width - 6 * root.s
                    height: 2.5 * root.s
                    color: root.verm
                }
                Rectangle {
                    x: 4 * root.s
                    y: 3 * root.s
                    width: 3 * root.s
                    height: 17 * root.s
                    color: root.verm
                }
                Rectangle {
                    x: parent.width - 7 * root.s
                    y: 3 * root.s
                    width: 3 * root.s
                    height: 17 * root.s
                    color: root.verm
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 52 * root.s
                height: 1
                color: root.hairStrong
            }
        }

        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(320 * root.s, pillRow.implicitWidth + 30 * root.s)
            height: 55 * root.s
            radius: height / 2
            color: Qt.rgba(18 / 255, 11 / 255, 8 / 255, 0.5)
            border.width: 1
            border.color: root.hairStrong

            property real shakeOffset: 0
            transform: Translate { x: pill.shakeOffset }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: pill; property: "shakeOffset"; to: 9 * root.s; duration: 50 }
                NumberAnimation { target: pill; property: "shakeOffset"; to: -9 * root.s; duration: 50 }
                NumberAnimation { target: pill; property: "shakeOffset"; to: 6 * root.s; duration: 50 }
                NumberAnimation { target: pill; property: "shakeOffset"; to: -6 * root.s; duration: 50 }
                NumberAnimation { target: pill; property: "shakeOffset"; to: 0; duration: 50 }
            }

            Row {
                id: pillRow
                anchors.fill: parent
                anchors.leftMargin: 18 * root.s
                anchors.rightMargin: 12 * root.s
                spacing: 11 * root.s

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 9 * root.s
                    height: 9 * root.s
                    radius: width / 2
                    color: root.verm
                }

                TextInput {
                    id: passwordField
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 9 * root.s - 31 * root.s - parent.spacing * 2
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: root.cream
                    font.family: "Inter"
                    font.pixelSize: 14 * root.s
                    selectByMouse: true
                    clip: true
                    cursorVisible: false

                    cursorDelegate: Rectangle {
                        width: 2 * root.s
                        height: 14 * root.s
                        color: root.verm
                        SequentialAnimation on opacity {
                            running: passwordField.activeFocus
                            loops: Animation.Infinite
                            NumberAnimation { to: 0; duration: 0; }
                            PauseAnimation { duration: 550 }
                            NumberAnimation { to: 1; duration: 0 }
                            PauseAnimation { duration: 550 }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        text: "Password"
                        color: root.dim
                        font: passwordField.font
                        visible: passwordField.text.length === 0 && !passwordField.activeFocus
                    }

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.submit()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            root.clearPassword()
                            event.accepted = true
                        }
                    }
                }

                Rectangle {
                    id: submitBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 31 * root.s
                    height: 31 * root.s
                    radius: width / 2
                    scale: submitArea.pressed ? 0.92 : (submitArea.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.verm }
                        GradientStop { position: 1.0; color: root.vermDeep }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: root.brightWhite
                        font.family: "Inter"
                        font.pixelSize: 15 * root.s
                    }

                    MouseArea {
                        id: submitArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submit()
                    }
                }
            }
        }

        Text {
            id: errorRow
            property bool shown: false
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Login failed"
            color: root.verm
            font.family: "Inter"
            font.pixelSize: 12 * root.s
            font.letterSpacing: 0.5 * root.s
            opacity: shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    component ActionLabel: Item {
        id: actionRoot
        property string label: ""
        property string glyph: ""
        signal activated
        implicitWidth: actionContent.implicitWidth
        implicitHeight: 26 * root.s

        Row {
            id: actionContent
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * root.s

            Text {
                id: actionText
                anchors.verticalCenter: parent.verticalCenter
                text: actionRoot.label
                color: root.cream
                opacity: actionArea.containsMouse ? 1.0 : 0.88
                font.family: "Inter"
                font.pixelSize: 11 * root.s
                font.letterSpacing: 1.4 * root.s
                font.capitalization: Font.AllUppercase
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: actionRoot.glyph.length > 0
                text: actionRoot.glyph
                color: root.cream
                opacity: 0.7
                font.family: "Inter"
                font.pixelSize: 10 * root.s
            }
        }

        Rectangle {
            anchors.top: actionContent.bottom
            anchors.topMargin: 3 * root.s
            anchors.left: actionContent.left
            height: 1.5 * root.s
            radius: height / 2
            color: root.verm
            width: actionArea.containsMouse ? actionText.implicitWidth : 0
            Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutExpo } }
        }

        MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionRoot.activated()
        }
    }

    Item {
        z: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: parent.width * 0.06
        anchors.rightMargin: parent.width * 0.06
        anchors.bottomMargin: 22 * root.s
        height: 26 * root.s

        ActionLabel {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            label: root.currentSessionName
            glyph: "⌄"
            onActivated: sessionPopup.toggle()
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 24 * root.s

            ActionLabel {
                anchors.verticalCenter: parent.verticalCenter
                label: "Restart"
                onActivated: if (root.hasSddm) sddm.reboot()
            }
            ActionLabel {
                anchors.verticalCenter: parent.verticalCenter
                label: "Shut Down"
                onActivated: if (root.hasSddm) sddm.powerOff()
            }
        }
    }

    component SelectPanel: Rectangle {
        id: panel
        property var entries: []
        property int activeIndex: 0
        signal picked(int index)
        property bool opened: false

        function toggle() {
            opened = !opened
        }
        function open() {
            opened = true
        }
        function close() {
            opened = false
        }

        z: 50
        width: 220 * root.s
        radius: 14 * root.s
        color: Qt.rgba(18 / 255, 11 / 255, 8 / 255, 0.92)
        border.width: 1
        border.color: root.hairStrong
        height: opened ? Math.min(entries.length, 6) * (38 * root.s) + 12 * root.s : 0
        clip: true
        visible: height > 1
        opacity: opened ? 1 : 0

        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Column {
            width: parent.width
            y: 6 * root.s
            Repeater {
                model: panel.entries
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    width: panel.width
                    height: 38 * root.s
                    color: rowArea.containsMouse ? Qt.rgba(192 / 255, 68 / 255, 43 / 255, 0.16) : "transparent"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3 * root.s
                        height: parent.height * 0.5
                        radius: width / 2
                        color: root.verm
                        visible: index === panel.activeIndex
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 32 * root.s
                        elide: Text.ElideRight
                        text: modelData
                        color: index === panel.activeIndex ? root.brightWhite : root.cream
                        font.family: "Inter"
                        font.weight: index === panel.activeIndex ? 600 : 400
                        font.pixelSize: 13 * root.s
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            panel.picked(index)
                            panel.close()
                        }
                    }
                }
            }
        }
    }

    SelectPanel {
        id: userPopup
        x: shrineColumn.x + shrineColumn.width / 2 - width / 2
        y: shrineColumn.y - height - 8 * root.s
        activeIndex: root.currentUserIndex
        entries: {
            var list = []
            if (!root.hasSddm)
                return ["erik"]
            for (var i = 0; i < userProbe.count; i++) {
                var rn = userProbe.fieldAt(i, "realName")
                var nm = userProbe.fieldAt(i, "name")
                list.push(rn.length > 0 ? rn : nm)
            }
            return list
        }
        onPicked: function (index) {
            root.currentUserIndex = index
            root.clearPassword()
        }
    }

    SelectPanel {
        id: sessionPopup
        x: parent.width * 0.06
        y: parent.height - height - 54 * root.s
        activeIndex: root.currentSessionIndex
        entries: {
            var list = []
            if (!root.hasSddm)
                return ["Hyprland"]
            for (var i = 0; i < sessionProbe.count; i++) {
                var nm = sessionProbe.fieldAt(i, "name")
                list.push(nm.length > 0 ? nm : "Session " + i)
            }
            return list
        }
        onPicked: function (index) {
            root.currentSessionIndex = index
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 40
        visible: userPopup.opened || sessionPopup.opened
        onClicked: {
            userPopup.close()
            sessionPopup.close()
        }
    }

    Connections {
        target: root.hasSddm ? sddm : null
        ignoreUnknownSignals: true
        function onLoginFailed() {
            errorRow.shown = true
            shakeAnim.restart()
            root.clearPassword()
        }
        function onLoginSucceeded() {
            errorRow.shown = false
        }
    }

    Timer {
        interval: 300
        running: true
        repeat: false
        onTriggered: passwordField.forceActiveFocus()
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) {
            userPopup.close()
            sessionPopup.close()
            root.clearPassword()
            event.accepted = true
        }
    }
}
