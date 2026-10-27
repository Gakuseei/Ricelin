pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import "Singletons"

/**
 * Calendar: weather glance, month grid, and an event editor that opens to the right when a day is picked.
 */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

    readonly property var loc: Clock.locale
    /** Weekday (0 = Sunday) of the first grid column. */
    readonly property int weekStart: Flags.weekStart === "sun" ? 0 : 1

    readonly property date today: sysClock.date
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    readonly property int offset: firstWeekdayOffset(viewYear, viewMonth)
    readonly property int monthLen: daysInMonth(viewYear, viewMonth)
    readonly property int rows: Math.ceil((offset + monthLen) / 7)

    readonly property real cellH: 24 * s
    readonly property real rowGap: 2 * s

    readonly property real gridW: 282 * s
    readonly property real weatherW: 152 * s
    readonly property real editorW: 196 * s
    readonly property real gutter: 16 * s

    readonly property bool weatherShown: Weather.ready
    readonly property bool editorShown: selectedDate.length > 0

    /** Picked day (a span's start) and span end as zero-padded "YYYY-MM-DD", so string compares work across months. */
    property string selectedDate: ""
    property string selEndDate: ""
    property bool pickingEnd: false
    property int hoverDay: 0

    /** Span end the grid paints: the live hover while arming, else the set end. */
    readonly property string rangeEndKey: pickingEnd && hoverDay > 0 ? dateKey(hoverDay) : selEndDate
    readonly property string rangeLo: {
        if (selectedDate.length === 0) return "";
        var b = rangeEndKey;
        if (b.length === 0) return selectedDate;
        return selectedDate < b ? selectedDate : b;
    }
    readonly property string rangeHi: {
        if (selectedDate.length === 0) return "";
        var b = rangeEndKey;
        if (b.length === 0) return selectedDate;
        return selectedDate < b ? b : selectedDate;
    }
    function inRange(key) {
        return key.length > 0 && rangeLo.length > 0 && key >= rangeLo && key <= rangeHi;
    }

    function keyDate(key) {
        var p = key.split("-");
        return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
    }

    /** "Mon 9 Jun" for a single day, "9 Jun" without the weekday, in the chosen date language. */
    function fmtDay(key, dow) {
        return Clock.dateFor(dow ? "ddd d MMM" : "d MMM", Flags.dateLang, keyDate(key));
    }

    /** "22–25 Jun" within a month, "29 Jun – 2 Jul" across one. */
    function fmtSpan(loKey, hiKey) {
        var lp = loKey.split("-");
        var hp = hiKey.split("-");
        if (lp[0] === hp[0] && lp[1] === hp[1])
            return Number(lp[2]) + (Flags.dateLang === "de" ? ".–" : "–") + fmtDay(hiKey, false);
        return fmtDay(loKey, false) + " – " + fmtDay(hiKey, false);
    }

    readonly property real gridHeight: grid.y + rows * cellH + (rows - 1) * rowGap

    /** The weather panel and the editor each add their column plus a divider gutter only when visible. */
    implicitWidth: gridW
        + (weatherShown ? weatherW + gutter : 0)
        + (editorShown ? editorW + gutter : 0)

    implicitHeight: editorShown ? Math.max(gridHeight, edCol.implicitHeight) : gridHeight

    readonly property bool todayVisible: viewMonth === today.getMonth()
        && viewYear === today.getFullYear()

    /** Ame rings the picked day or today; with neither in view it parks as an ember on the 暦 header glyph. */
    readonly property bool selectedInView: selectedDate.length > 0
        && Number(selectedDate.split("-")[1]) === viewMonth + 1
        && Number(selectedDate.split("-")[0]) === viewYear
    readonly property int focusDay: selectedInView
        ? Number(selectedDate.split("-")[2])
        : (todayVisible ? today.getDate() : 0)
    readonly property bool focused: focusDay > 0
    readonly property int focusIndex: offset + focusDay - 1
    readonly property real cellW: grid.width / 7
    readonly property real focusX: gridPane.x + grid.x + (focusIndex % 7 + 0.5) * cellW
    readonly property real focusY: gridPane.y + grid.y + (Math.floor(focusIndex / 7) + 0.5) * (cellH + rowGap) - rowGap / 2

    readonly property point soulPoint: {
        void width;
        void height;
        if (Flags.showGlyphs)
            return header.mapToItem(root, 8 * s, header.height / 2 - 11 * s);
        return header.mapToItem(root, -8 * s, header.height / 2);
    }

    ameForm: focused ? "ring" : "soul"
    amePoint: focused ? Qt.point(focusX, focusY) : soulPoint

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    function firstWeekdayOffset(year, month) {
        var d = new Date(year, month, 1).getDay();
        return (d - weekStart + 7) % 7;
    }

    function isWeekend(column) {
        var dow = (weekStart + column) % 7;
        return dow === 0 || dow === 6;
    }

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function isToday(day) {
        return day === today.getDate()
            && viewMonth === today.getMonth()
            && viewYear === today.getFullYear();
    }

    /** "YYYY-MM-DD" for a day number in the viewed month, zero-padded for keys. */
    function dateKey(day) {
        var m = viewMonth + 1;
        var mm = m < 10 ? "0" + m : "" + m;
        var dd = day < 10 ? "0" + day : "" + day;
        return viewYear + "-" + mm + "-" + dd;
    }

    /**
     * The new month slides in from the side it came from.
     */
    property real monthDir: 1
    property real monthShift: 0
    property real monthFade: 1
    ParallelAnimation {
        id: monthIn
        NumberAnimation { target: root; property: "monthShift"; from: 14 * root.s * root.monthDir; to: 0; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "monthFade"; from: 0.3; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }

    function shiftMonth(delta) {
        var m = viewMonth + delta;
        var y = viewYear;
        while (m < 0) { m += 12; y -= 1; }
        while (m > 11) { m -= 12; y += 1; }
        viewMonth = m;
        viewYear = y;
        hoverDay = 0;
        monthDir = delta > 0 ? 1 : -1;
        if (!Motion.calm)
            monthIn.restart();
        if (!pickingEnd) {
            selectedDate = "";
            selEndDate = "";
        }
    }

    function resetToday() {
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
        selectedDate = "";
        selEndDate = "";
        pickingEnd = false;
        hoverDay = 0;
    }

    /**
     * While picking an end the click closes the span, swapping if earlier and dropping it on the start day, otherwise it toggles a single day.
     */
    function selectDay(day) {
        var key = dateKey(day);
        if (pickingEnd) {
            pickingEnd = false;
            hoverDay = 0;
            if (key === selectedDate)
                selEndDate = "";
            else if (key < selectedDate) {
                selEndDate = selectedDate;
                selectedDate = key;
            } else {
                selEndDate = key;
            }
            return;
        }
        if (selectedDate === key && selEndDate.length === 0) {
            selectedDate = "";
            return;
        }
        selectedDate = key;
        selEndDate = "";
    }

    onActiveChanged: if (active) resetToday()

    function back() {
        if (pickingEnd) {
            pickingEnd = false;
            hoverDay = 0;
            return true;
        }
        if (selectedDate.length === 0)
            return false;
        selectedDate = "";
        selEndDate = "";
        return true;
    }

    component Caption: Text {
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.fs.meta * root.s
        font.weight: Font.DemiBold
    }

    /** Underlined inline input used by the editor's title and time fields. */
    component LineField: Item {
        id: lf

        property alias field: lfInput
        property alias placeholder: lfInput.placeholderText
        property bool numeric: false

        signal edited(string text)
        signal submitted()

        height: 26 * root.s

        QQC.TextField {
            id: lfInput
            anchors.fill: parent
            background: null
            padding: 0
            leftPadding: Theme.sp.xxs * root.s
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: Theme.fs.body * root.s
            font.features: lf.numeric ? { "tnum": 1 } : {}
            placeholderTextColor: Theme.textFaint
            inputMethodHints: lf.numeric ? Qt.ImhPreferNumbers : Qt.ImhNone
            selectByMouse: true
            selectionColor: Theme.verm
            onTextChanged: lf.edited(text)
            Keys.onReturnPressed: lf.submitted()
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.faint
            opacity: lfInput.activeFocus ? 0.7 : 0.2
            Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
        }
    }

    Item {
        id: weather
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.weatherShown ? root.weatherW : 0
        clip: true
        visible: width > 1
        opacity: root.weatherShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        Column {
            id: wxCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 6 * root.s
            spacing: 9 * root.s

            Row {
                spacing: 9 * root.s

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32 * root.s
                    height: 32 * root.s
                    name: Weather.glyphFor(Weather.codeNow, Weather.isDay)
                    color: Theme.todayWarm
                    stroke: 1.9
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Text {
                        text: Weather.tempNow + "°"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 26 * root.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        text: Weather.labelFor(Weather.codeNow)
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * root.s
                        font.weight: Font.Medium
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 8 * root.s

                /** IP lookup only finds the ISP city, so a click edits the town in place; blank falls back to auto. */
                Item {
                    id: cityBox
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - humidityRow.width - 8 * root.s
                    height: 14 * root.s

                    property bool editing: false

                    Caption {
                        id: cityText
                        visible: !cityBox.editing
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.city.length > 0 ? Weather.city : "Set town"
                        color: cityArea.containsMouse ? Theme.subtle : Theme.textFaint
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: cityArea
                        visible: !cityBox.editing
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            cityField.text = Flags.weatherCity;
                            cityBox.editing = true;
                            cityField.forceActiveFocus();
                            cityField.selectAll();
                        }
                    }
                    QQC.TextField {
                        id: cityField
                        visible: cityBox.editing
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        background: null
                        padding: 0
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * root.s
                        font.weight: Font.DemiBold
                        placeholderText: "Town"
                        placeholderTextColor: Theme.textFaint
                        selectByMouse: true
                        selectionColor: Theme.verm
                        onAccepted: {
                            Flags.weatherCity = text.trim();
                            cityBox.editing = false;
                        }
                        Keys.onEscapePressed: cityBox.editing = false
                        onActiveFocusChanged: if (!activeFocus) cityBox.editing = false
                    }
                }
                Row {
                    id: humidityRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3 * root.s

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 11 * root.s
                        height: 11 * root.s
                        name: "droplet"
                        color: Theme.faint
                        stroke: 1.6
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.humidity + "%"
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * root.s
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                }
            }

            Rectangle {
                width: wxCol.width
                height: 1
                color: Theme.hairSoft
            }

            Row {
                width: wxCol.width

                Repeater {
                    model: Weather.daily.slice(0, 4)

                    Column {
                        id: dayCol
                        required property var modelData
                        width: wxCol.width / 4
                        spacing: 5 * root.s

                        Caption {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dayCol.modelData.day
                        }
                        GlyphIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 15 * root.s
                            height: 15 * root.s
                            name: Weather.glyphFor(dayCol.modelData.code, true)
                            color: Theme.subtle
                            stroke: 1.7
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dayCol.modelData.temp + "°"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.meta * root.s
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2 * root.s

                            GlyphIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 9 * root.s
                                height: 9 * root.s
                                name: "droplet"
                                color: Theme.faint
                                stroke: 1.6
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: dayCol.modelData.rh + "%"
                                color: Theme.textFaint
                                font.family: Theme.font
                                font.pixelSize: Theme.fs.label * root.s
                                font.weight: Font.Medium
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: weatherSeam
        anchors.left: weather.right
        anchors.leftMargin: root.gutter / 2
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Theme.hair
        visible: root.weatherShown
        opacity: weather.opacity
    }

    Item {
        id: gridPane
        anchors.left: root.weatherShown ? weather.right : parent.left
        anchors.leftMargin: root.weatherShown ? root.gutter : 0
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.gridW

        SurfaceHeader {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            s: root.s
            glyph: "暦"
            title: root.loc.standaloneMonthName(root.viewMonth, Locale.LongFormat) + " " + root.viewYear

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp.xxs * root.s

                Repeater {
                    model: [-1, 1]

                    Rectangle {
                        id: nav
                        required property int modelData
                        width: 22 * root.s
                        height: width
                        radius: Theme.r.s * root.s
                        scale: navArea.pressed && !Motion.calm ? 0.94 : 1
                        color: navArea.pressed ? Theme.hair : (navArea.containsMouse ? Theme.frameBg : "transparent")
                        border.width: navArea.containsMouse ? 1 : 0
                        border.color: Theme.frameBorder
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                        GlyphIcon {
                            anchors.centerIn: parent
                            width: 16 * root.s
                            height: 16 * root.s
                            name: nav.modelData < 0 ? "chevron-left" : "chevron-right"
                            color: navArea.containsMouse ? Theme.cream : Theme.iconDim
                            stroke: 1.8
                        }

                        MouseArea {
                            id: navArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(nav.modelData)
                        }
                    }
                }
            }
        }

        Rectangle {
            id: divider
            anchors.top: header.bottom
            anchors.topMargin: 9 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hair
        }

        Row {
            id: weekdays
            anchors.top: divider.bottom
            anchors.topMargin: 8 * root.s
            anchors.left: parent.left
            anchors.right: parent.right

            Repeater {
                model: 7

                Item {
                    id: wd
                    required property int index
                    readonly property bool weekend: root.isWeekend(index)
                    width: weekdays.width / 7
                    height: 16 * root.s

                    Caption {
                        anchors.centerIn: parent
                        text: root.loc.standaloneDayName((root.weekStart + wd.index) % 7, Locale.NarrowFormat)
                        color: wd.weekend ? Theme.textFaint : Theme.subtle
                    }
                }
            }
        }

        Grid {
            id: grid
            opacity: root.monthFade
            transform: Translate { x: root.monthShift }
            y: weekdays.y + weekdays.height + 4 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            columns: 7
            rowSpacing: root.rowGap
            columnSpacing: 0

            Repeater {
                model: root.rows * 7

                Item {
                    id: cell
                    required property int index
                    readonly property bool weekend: root.isWeekend(index % 7)
                    width: grid.width / 7
                    height: root.cellH

                    readonly property int dayNum: index - root.offset + 1
                    readonly property bool inMonth: dayNum >= 1 && dayNum <= root.monthLen
                    readonly property bool current: inMonth && root.isToday(dayNum)
                    readonly property string dayKey: inMonth ? root.dateKey(dayNum) : ""
                    readonly property bool hasEvent: inMonth && Events.hasEvents(cell.dayKey)
                    readonly property bool sel: inMonth && root.inRange(cell.dayKey)
                    readonly property bool selEdge: cell.sel
                        && (cell.dayKey === root.rangeLo || cell.dayKey === root.rangeHi)
                    readonly property int ghostNum: dayNum < 1
                        ? root.daysInMonth(root.viewYear, root.viewMonth - 1) + dayNum
                        : dayNum - root.monthLen

                    Rectangle {
                        anchors.centerIn: parent
                        width: 22 * root.s
                        height: width
                        radius: Theme.r.s * root.s
                        color: !cell.inMonth || cell.current ? "transparent"
                            : (cellArea.pressed ? Theme.hair : (cellArea.containsMouse ? Qt.alpha(Theme.cream, 0.04) : "transparent"))
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 24 * root.s
                        height: width
                        radius: Theme.r.s * root.s
                        visible: cell.current || cell.sel
                        color: cell.sel && !cell.current ? Qt.alpha(Theme.vermLit, 0.12) : Theme.frameBg
                        border.width: 1
                        border.color: cell.selEdge ? Qt.alpha(Theme.vermLit, 0.55)
                            : (cell.sel ? Qt.alpha(Theme.vermLit, 0.22) : Theme.frameBorder)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.inMonth ? cell.dayNum : cell.ghostNum
                        color: cell.inMonth
                            ? (cell.current ? Theme.todayWarm
                                : (cell.hasEvent ? Theme.flameGlow
                                    : (cell.weekend ? Theme.subtle : Theme.cream)))
                            : Theme.ghost
                        opacity: cell.inMonth && !cell.current && !cell.weekend && !cell.hasEvent ? 0.85 : 1.0
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * root.s
                        font.weight: cell.current ? Font.Bold : cell.hasEvent ? Font.DemiBold : Font.Normal
                        font.features: { "tnum": 1 }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.verticalCenter
                        anchors.topMargin: 9 * root.s
                        visible: cell.hasEvent && !cell.current
                        width: 3 * root.s
                        height: width
                        radius: width / 2
                        color: Theme.flameGlow
                    }

                    MouseArea {
                        id: cellArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: cell.inMonth
                        cursorShape: cell.inMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (cell.inMonth) root.selectDay(cell.dayNum)
                        onContainsMouseChanged: if (root.pickingEnd && cell.inMonth && containsMouse)
                            root.hoverDay = cell.dayNum
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: grid.horizontalCenter
            anchors.top: grid.bottom
            anchors.topMargin: 6 * root.s
            visible: root.pickingEnd
            text: "Click the last day"
            color: Theme.flameGlow
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            font.weight: Font.DemiBold
        }

        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: grid.bottom
            anchors.bottom: parent.bottom
            enabled: root.editorShown && !root.pickingEnd
            onClicked: {
                root.selectedDate = "";
                root.selEndDate = "";
                root.pickingEnd = false;
            }
        }
    }

    Rectangle {
        id: editorSeam
        anchors.left: gridPane.right
        anchors.leftMargin: root.gutter / 2
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Theme.hair
        visible: root.editorShown
        opacity: editor.opacity
    }

    Item {
        id: editor
        anchors.left: gridPane.right
        anchors.leftMargin: root.gutter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.editorShown ? root.editorW : 0
        clip: true
        visible: width > 1
        opacity: root.editorShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        /** Events covering the picked day (a span's start), empty until a day is picked. */
        readonly property var dayEvents: root.selectedDate.length > 0
            ? Events.forDate(root.selectedDate) : []

        /** Single day reads "Mon 9 Jun"; a span reads its range. */
        readonly property string heading: {
            if (root.selectedDate.length === 0)
                return "";
            if (root.selEndDate.length === 0)
                return root.fmtDay(root.selectedDate, true);
            return root.fmtSpan(root.rangeLo, root.rangeHi);
        }

        readonly property string spanLabel: root.selEndDate.length === 0
            ? root.fmtDay(root.selectedDate, false)
            : root.fmtSpan(root.rangeLo, root.rangeHi)

        /** "allday" (default) hides the time fields; "timed" reveals start/end. */
        property string mode: "allday"
        property string startVal: ""
        property string endVal: ""
        property string titleVal: ""

        /** "" / "month" / "year"; a birthday-like title suggests yearly until the user picks by hand. */
        property string recur: ""
        property bool recurManual: false

        /** Suggest yearly for a birthday title, unless the user already chose. */
        function autoRecur() {
            if (!recurManual)
                recur = Events.isBirthday(titleVal) ? "year" : "";
        }

        function clearForm() {
            startVal = "";
            endVal = "";
            titleVal = "";
            recur = "";
            recurManual = false;
            startField.field.text = "";
            endField.field.text = "";
            titleField.field.text = "";
        }

        /** A time is kept only when it reads as HH:MM, otherwise it drops to an all-day blank. */
        function cleanTime(t) {
            var v = t.trim();
            return /^\d{1,2}:\d{2}$/.test(v) ? v : "";
        }

        /** Add the form's event when a title is set, then reset the inputs. */
        function commit() {
            if (titleVal.trim().length === 0)
                return;
            var t = editor.mode === "timed" ? editor.cleanTime(startVal) : "";
            var e = editor.mode === "timed" ? editor.cleanTime(endVal) : "";
            Events.add(root.selectedDate, editor.recur !== "" ? "" : root.selEndDate,
                       t, e, titleVal.trim(), editor.recur);
            clearForm();
            titleField.field.forceActiveFocus();
        }

        onWidthChanged: if (width < 1) { clearForm(); mode = "allday"; }

        Column {
            id: edCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 8 * root.s

            Caption {
                width: parent.width
                height: 22 * root.s
                verticalAlignment: Text.AlignVCenter
                text: editor.heading
                color: Theme.subtle
                elide: Text.ElideRight
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.hair
            }

            /** Capped so a day stacked with events scrolls instead of growing the surface. */
            Item {
                width: parent.width
                height: edFlick.height

                Flickable {
                    id: edFlick
                    width: parent.width
                    height: Math.min(edList.implicitHeight, 230 * root.s)
                    contentHeight: edList.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    onContentHeightChanged: returnToBounds()

                    Column {
                        id: edList
                        width: edFlick.width
                        spacing: 4 * root.s

                        EmptyState {
                            width: parent.width
                            visible: editor.dayEvents.length === 0
                            s: root.s
                            topPadding: Theme.sp.s * root.s
                            bottomPadding: Theme.sp.s * root.s
                            text: "Nothing planned"
                        }

                        Repeater {
                            model: editor.dayEvents

                            Rectangle {
                                id: evRow
                                required property var modelData
                                width: edList.width
                                height: evBody.implicitHeight + 12 * root.s
                                radius: Theme.r.s * root.s
                                color: evArea.hovered ? Theme.frameBg : "transparent"

                                /** "all day" or "09:00–10:00", a date span when multi-day, "every year" when recurring. */
                                readonly property string meta: {
                                    var datePart = "";
                                    if (evRow.modelData.endDate && evRow.modelData.endDate.length > 0)
                                        datePart = root.fmtSpan(evRow.modelData.date, evRow.modelData.endDate);
                                    var t = evRow.modelData.time || "";
                                    var e = evRow.modelData.endTime || "";
                                    var timePart = t.length === 0 ? "all day"
                                        : (e.length > 0 ? t + "–" + e : t);
                                    var base = datePart.length > 0 ? datePart + " · " + timePart : timePart;
                                    var r = evRow.modelData.recur;
                                    if (r === "year") return "every year · " + base;
                                    if (r === "month") return "every month · " + base;
                                    return base;
                                }

                                HoverHandler { id: evArea }

                                Column {
                                    id: evBody
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.sp.s * root.s
                                    anchors.right: evDel.left
                                    anchors.rightMargin: 6 * root.s
                                    anchors.top: parent.top
                                    anchors.topMargin: 6 * root.s
                                    spacing: Theme.sp.xxs * root.s

                                    Text {
                                        text: evRow.modelData.text
                                        width: parent.width
                                        color: Theme.cream
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fs.meta * root.s
                                        font.weight: Font.Medium
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 4
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: evRow.meta
                                        width: parent.width
                                        color: Theme.flameGlow
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fs.label * root.s
                                        font.weight: Font.DemiBold
                                        font.features: { "tnum": 1 }
                                        wrapMode: Text.Wrap
                                        elide: Text.ElideRight
                                    }
                                }

                                Item {
                                    id: evDel
                                    anchors.right: parent.right
                                    anchors.rightMargin: 7 * root.s
                                    anchors.top: parent.top
                                    anchors.topMargin: 7 * root.s
                                    width: 16 * root.s
                                    height: 16 * root.s
                                    opacity: evArea.hovered ? 1 : 0.32
                                    scale: delArea.pressed && !Motion.calm ? 0.9 : 1
                                    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                    GlyphIcon {
                                        anchors.fill: parent
                                        name: "close"
                                        color: delArea.containsMouse ? Theme.vermLit : Theme.iconDim
                                        stroke: 1.6
                                    }

                                    MouseArea {
                                        id: delArea
                                        anchors.fill: parent
                                        anchors.margins: -5 * root.s
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Events.remove(evRow.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }

                WheelScroller {
                    anchors.fill: parent
                    s: root.s
                    flick: edFlick
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.hair
            }

            Row {
                width: parent.width
                spacing: 8 * root.s

                LineField {
                    id: titleField
                    width: parent.width - addBtn.width - 8 * root.s
                    height: 28 * root.s
                    placeholder: "What's on?"
                    onEdited: (t) => { editor.titleVal = t; editor.autoRecur(); }
                    onSubmitted: editor.commit()
                }

                Rectangle {
                    id: addBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28 * root.s
                    height: 28 * root.s
                    radius: Theme.r.s * root.s
                    readonly property bool armed: editor.titleVal.trim().length > 0
                    scale: addArea.pressed && armed && !Motion.calm ? 0.94 : 1
                    color: addArea.containsMouse && armed ? Qt.alpha(Theme.vermLit, addArea.pressed ? 0.3 : 0.22)
                        : (armed ? Qt.alpha(Theme.vermLit, 0.12) : Theme.frameBg)
                    border.width: 1
                    border.color: armed ? Qt.alpha(Theme.vermLit, 0.5) : Theme.frameBorder
                    Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: addBtn.armed ? Theme.vermLit : Theme.iconDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.title * root.s
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editor.commit()
                    }
                }
            }

            SettingsSeg {
                s: root.s
                options: [
                    { label: "All day", value: "allday" },
                    { label: "Timed", value: "timed" }
                ]
                value: editor.mode
                onPicked: (v) => editor.mode = v
            }

            Row {
                width: parent.width
                spacing: 8 * root.s
                visible: editor.mode === "timed"

                LineField {
                    id: startField
                    width: (parent.width - 8 * root.s) / 2
                    numeric: true
                    placeholder: "09:00"
                    onEdited: (t) => editor.startVal = t
                    onSubmitted: editor.commit()
                }

                LineField {
                    id: endField
                    width: (parent.width - 8 * root.s) / 2
                    numeric: true
                    placeholder: "Until"
                    onEdited: (t) => editor.endVal = t
                    onSubmitted: editor.commit()
                }
            }

            SettingsSeg {
                s: root.s
                options: [
                    { label: "Once", value: "" },
                    { label: "Monthly", value: "month" },
                    { label: "Yearly", value: "year" }
                ]
                value: editor.recur
                onPicked: (v) => {
                    editor.recurManual = true;
                    editor.recur = v;
                    if (v !== "") {
                        root.selEndDate = "";
                        root.pickingEnd = false;
                    }
                }
            }

            /** Day or range chip, a button that arms the grid for the span's end, and ✕ back to one day; hidden when recurring. */
            Row {
                width: parent.width
                spacing: 8 * root.s
                visible: editor.recur === ""

                Rectangle {
                    id: spanChip
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - extendBtn.width - clearSpan.width - 16 * root.s
                    height: 28 * root.s
                    radius: Theme.r.m * root.s
                    color: Theme.frameBg
                    border.width: 1
                    border.color: Theme.frameBorder

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.sp.s * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.sp.s * root.s

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9 * root.s
                            height: 9 * root.s
                            radius: Theme.r.xs * root.s
                            color: Theme.flameGlow
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: editor.spanLabel
                            color: root.selEndDate.length > 0 ? Theme.cream : Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.meta * root.s
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }
                    }
                }

                Button {
                    id: extendBtn
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.s
                    lit: root.pickingEnd
                    text: root.pickingEnd ? "Cancel" : (root.selEndDate.length > 0 ? "Change" : "Add days")
                    onClicked: {
                        if (root.pickingEnd) {
                            root.pickingEnd = false;
                            root.hoverDay = 0;
                        } else {
                            root.selEndDate = "";
                            root.pickingEnd = true;
                        }
                    }
                }

                Item {
                    id: clearSpan
                    anchors.verticalCenter: parent.verticalCenter
                    width: visible ? 16 * root.s : 0
                    height: 16 * root.s
                    visible: root.selEndDate.length > 0 && !root.pickingEnd

                    GlyphIcon {
                        anchors.fill: parent
                        name: "close"
                        color: clearArea.containsMouse ? Theme.vermLit : Theme.iconDim
                        stroke: 1.6
                    }
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -5 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selEndDate = ""
                    }
                }
            }
        }
    }
}
