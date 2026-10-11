pragma Singleton

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string defaultDir: home + "/Pictures/Ricelin/Camera"
    readonly property string outDir: defaultDir

    property bool cameraActive: false
    property bool videoRecording: false
    property bool capturingPhoto: false
    property string currentFile: ""

    // -----------------------------------------------------------------
    // Camera format state
    // -----------------------------------------------------------------

    property var availableFormats: []
    property var availableResolutions: []
    property var availableFps: []

    property string selectedResolution: ""
    property int selectedFps: 30

    // -----------------------------------------------------------------
    // Camera presentation
    // -----------------------------------------------------------------

    property bool mirrored: true

    // -----------------------------------------------------------------
    // Video quality
    // -----------------------------------------------------------------

    property string selectedQuality: "high"

    // -----------------------------------------------------------------
    // Camera controls
    // -----------------------------------------------------------------

    property real zoomFactor: 1.0
    property string focusModeName: "auto"
    property real focusDistance: 1.0

    // Hardware exposure/gain controls (V4L2 units).
    // No control write occurs at startup; writes happen only after explicit user changes.
    readonly property int exposureMin: 10
    readonly property int exposureMax: 2500
    readonly property int exposureMaxForCurrentFps:
        Math.min(exposureMax, Math.max(exposureMin, Math.floor(10000 / Math.max(1, selectedFps))))
    readonly property int gainMin: 0
    readonly property int gainMax: 4

    property int manualExposureAbsolute: 400
    property int manualGain: 0

    // Compatibility state for the existing UI.
    property string exposureModeName: "auto"
    property real exposureCompensation: 0.0
    property int manualIso: -1

    property string whiteBalanceName: "auto"

    property bool audioEnabled: true

    property int selectedBitrate: 0
    property string selectedCodec: ""

    property var availableZoom: []
    property var availableFocusModes: []
    property var availableExposureModes: [
        { label: "Auto", value: "auto" },
        { label: "Manual", value: "manual" }
    ]

    property var availableWhiteBalances: []
    property var availableCodecs: []

    readonly property bool hasZoom:
        camera.maximumZoomFactor > camera.minimumZoomFactor

    readonly property bool canExposureCompensation: false

    readonly property bool canIso: true

    readonly property bool canFocusDistance:
        (camera.supportedFeatures & Camera.FocusDistance) !== 0

    readonly property bool microphoneAvailable:
        mediaDevices.audioInputs.length > 0

    readonly property bool recordingLocked:
        videoRecording || capturingPhoto

    readonly property bool hasFocusModes:
        availableFocusModes.length > 0

    readonly property bool hasExposureModes:
        availableExposureModes.length > 0

    readonly property bool hasWhiteBalances:
        availableWhiteBalances.length > 0

    readonly property bool hasZoomOptions:
        availableZoom.length > 1

    // -----------------------------------------------------------------
    // Existing camera availability block follows.
    // -----------------------------------------------------------------

    readonly property bool cameraAvailable:
        mediaDevices.videoInputs.length > 0

    Timer {
        id: formatRefreshTimer

        interval: 200
        repeat: true

        property int attempts: 0

        onTriggered: {
            root.refreshFormats()

            if (root.availableFormats.length > 0 || attempts >= 15) {
                stop()
                attempts = 0
                root.refreshAllCapabilities()
            } else {
                attempts += 1
            }
        }
    }

    function scheduleFormatRefresh() {
        formatRefreshTimer.stop()
        formatRefreshTimer.attempts = 0
        root.refreshFormats()

        if (root.availableFormats.length > 0) {
            root.refreshAllCapabilities()
            return
        }

        formatRefreshTimer.start()
    }

    readonly property bool photoReady:
        imageCapture.readyForCapture

    MediaDevices {
        id: mediaDevices

        onVideoInputsChanged: {
            Qt.callLater(root.scheduleFormatRefresh)
        }
    }

    AudioInput {
        id: audioInput

        muted: !root.audioEnabled

        Component.onCompleted: {
            if (mediaDevices.defaultAudioInput)
                device = mediaDevices.defaultAudioInput
        }
    }

    Camera {
        id: camera

        cameraDevice: mediaDevices.defaultVideoInput
        active: root.cameraActive
        whiteBalanceMode: Camera.WhiteBalanceAuto

        onCameraDeviceChanged: {
            Qt.callLater(root.scheduleFormatRefresh)
        }
    }

    ImageCapture {
        id: imageCapture

        fileFormat: ImageCapture.JPEG
        quality: ImageCapture.VeryHighQuality

        onImageSaved: function(requestId, path) {
            root.capturingPhoto = false
            root.currentFile = path
            console.log("Camera photo saved:", path)
        }

        onErrorOccurred: function(requestId, error, errorString) {
            root.capturingPhoto = false
            console.error("Camera photo error:", errorString)
        }
    }

    MediaRecorder {
        id: recorder

        mediaFormat {
            fileFormat: MediaFormat.MPEG4
        }

        videoFrameRate: root.selectedFps
        videoResolution: root.selectedCameraSize()
        videoBitRate: root.selectedBitrate
        quality: root.mediaRecorderQuality()

        onRecorderStateChanged: {
            root.videoRecording =
                recorder.recorderState === MediaRecorder.RecordingState
        }

        onActualLocationChanged: {
            if (recorder.actualLocation)
                root.currentFile = recorder.actualLocation.toString()
        }

        onErrorOccurred: function(error, errorString) {
            console.error("Camera video error:", errorString)
        }
    }

    CaptureSession {
        id: captureSession

        camera: camera
        imageCapture: imageCapture
        recorder: recorder
        audioInput: audioInput
    }

    readonly property var captureSession: captureSession

    // -----------------------------------------------------------------
    // Directory / capture process
    // -----------------------------------------------------------------

    Process {
        id: mkdirProc

        property string pendingAction: ""
        property string pendingFile: ""

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.capturingPhoto = false
                console.error("Could not create camera directory")
                return
            }

            if (pendingAction === "photo") {
                imageCapture.captureToFile(pendingFile)
            } else if (pendingAction === "video") {
                root.applyCodec()
                recorder.outputLocation = "file://" + pendingFile
                recorder.record()
            }
        }
    }

    function selectedCameraSize() {
        if (!selectedResolution)
            return Qt.size(0, 0)

        var parts = String(selectedResolution).split("x")
        if (parts.length !== 2)
            return Qt.size(0, 0)

        var w = Number(parts[0])
        var h = Number(parts[1])

        if (w <= 0 || h <= 0)
            return Qt.size(0, 0)

        return Qt.size(w, h)
    }

    function codecDisplayName(codec) {
        try {
            return String(recorder.mediaFormat.videoCodecName(codec))
        } catch (e) {
            return "Codec " + String(codec)
        }
    }

    function codecKey(name) {
        return String(name)
            .toUpperCase()
            .replace(/[^A-Z0-9]/g, "")
    }

    function refreshCodecs() {
        var result = []
        var seen = ({})

        try {
            var probe = recorder.mediaFormat

            if (probe.fileFormat === MediaFormat.UnspecifiedFormat)
                probe.fileFormat = MediaFormat.MPEG4

            var codecs = probe.supportedVideoCodecs(MediaFormat.Encode)

            for (var i = 0; i < codecs.length; ++i) {
                var codec = codecs[i]
                var name = codecDisplayName(codec)
                var key = codecKey(name)

                if (seen[key])
                    continue

                result.push({
                    label: name,
                    value: name,
                    codec: codec
                })
                seen[key] = true
            }
        } catch (e) {
            console.error("Could not enumerate camera video codecs:", e)
        }

        result.sort(function(a, b) {
            return Number(a.codec) - Number(b.codec)
        })

        availableCodecs = result

        if (availableCodecs.length === 0)
            return

        var wanted = null

        if (selectedCodec) {
            var selectedKey = codecKey(selectedCodec)

            for (var i = 0; i < availableCodecs.length; ++i) {
                if (codecKey(availableCodecs[i].value) === selectedKey) {
                    wanted = availableCodecs[i]
                    break
                }
            }
        }

        if (!wanted) {
            for (var j = 0; j < availableCodecs.length; ++j) {
                if (codecKey(availableCodecs[j].value) === "H264") {
                    wanted = availableCodecs[j]
                    break
                }
            }
        }

        if (!wanted)
            wanted = availableCodecs[0]

        selectedCodec = wanted.value
        applyCodec()
    }

    function applyCodec() {
        if (recordingLocked || !selectedCodec)
            return

        var wantedKey = codecKey(selectedCodec)
        var wantedCodec = null

        for (var i = 0; i < availableCodecs.length; ++i) {
            if (codecKey(availableCodecs[i].value) === wantedKey) {
                wantedCodec = availableCodecs[i].codec
                break
            }
        }

        if (wantedCodec === null || wantedCodec === undefined)
            return

        try {
            var fmt = recorder.mediaFormat
            fmt.fileFormat = MediaFormat.MPEG4
            fmt.videoCodec = wantedCodec

            if (!fmt.isSupported(MediaFormat.Encode)) {
                console.error(
                    "Selected camera codec is not supported for current MediaFormat:",
                    selectedCodec
                )
                return
            }

            recorder.mediaFormat = fmt

            console.log(
                "Camera codec:",
                fmt.videoCodecName(wantedCodec)
            )
        } catch (e) {
            console.error("Could not apply camera codec:", e)
        }
    }

    function setCodec(value) {

        if (recordingLocked)
            return

        var wanted = String(value)

        var supported = availableCodecs.some(function(c) {
            return c.value === wanted
        })

        if (!supported)
            return

        selectedCodec = wanted
        applyCodec()
    }

    function setBitrate(value) {
        if (recordingLocked)
            return

        var bitrate = Number(value)
        if (!isFinite(bitrate) || bitrate < 0)
            return

        selectedBitrate = Math.round(bitrate)
        recorder.videoBitRate = selectedBitrate
    }

    function setAudioEnabled(value) {
        if (recordingLocked)
            return

        // audioInput.muted is bound declaratively to
        // !root.audioEnabled (see the AudioInput block above), so
        // just flip the property here. Do NOT also assign
        // audioInput.muted imperatively -- that would permanently
        // remove the binding the first time this runs.
        audioEnabled = !!value
    }

    function rebuildZoom() {
        availableZoom = []

        if (!hasZoom)
            return

        var max = Number(camera.maximumZoomFactor)
        var candidates = [1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0]

        for (var i = 0; i < candidates.length; ++i) {
            var z = candidates[i]

            if (z >= camera.minimumZoomFactor && z <= max + 0.0001) {
                availableZoom.push({
                    label: z.toFixed(2).replace(/0+$/, "").replace(/\.$/, "") + "×",
                    value: z
                })
            }
        }
    }

    function rebuildFocusModes() {
        availableFocusModes = []

        var modes = [
            { label: "Auto", value: "auto", mode: Camera.FocusModeAuto },
            { label: "Near", value: "near", mode: Camera.FocusModeAutoNear },
            { label: "Far", value: "far", mode: Camera.FocusModeAutoFar },
            { label: "Hyperfocal", value: "hyperfocal", mode: Camera.FocusModeHyperfocal },
            { label: "Infinity", value: "infinity", mode: Camera.FocusModeInfinity },
            { label: "Manual", value: "manual", mode: Camera.FocusModeManual }
        ]

        for (var i = 0; i < modes.length; ++i) {
            var m = modes[i]

            try {
                if (camera.isFocusModeSupported(m.mode))
                    availableFocusModes.push(m)
            } catch (e) {
                console.error("Focus capability query failed:", e)
            }
        }
    }

    function rebuildWhiteBalances() {
        availableWhiteBalances = []

        var modes = [
            { label: "Auto", value: "auto", mode: Camera.WhiteBalanceAuto },
            { label: "Sunlight", value: "sunlight", mode: Camera.WhiteBalanceSunlight },
            { label: "Cloudy", value: "cloudy", mode: Camera.WhiteBalanceCloudy },
            { label: "Shade", value: "shade", mode: Camera.WhiteBalanceShade },
            { label: "Tungsten", value: "tungsten", mode: Camera.WhiteBalanceTungsten },
            { label: "Fluorescent", value: "fluorescent", mode: Camera.WhiteBalanceFluorescent },
            { label: "Flash", value: "flash", mode: Camera.WhiteBalanceFlash },
            { label: "Sunset", value: "sunset", mode: Camera.WhiteBalanceSunset }
        ]

        for (var i = 0; i < modes.length; ++i) {
            var m = modes[i]

            try {
                if (camera.isWhiteBalanceModeSupported(m.mode))
                    availableWhiteBalances.push(m)
            } catch (e) {
                console.error("White-balance capability query failed:", e)
            }
        }
    }

    function refreshCapabilities() {
        rebuildZoom()
        rebuildFocusModes()
        rebuildWhiteBalances()

        if (hasZoom) {
            zoomFactor = Math.min(
                Math.max(zoomFactor, camera.minimumZoomFactor),
                camera.maximumZoomFactor
            )
            camera.zoomFactor = zoomFactor
        }

        if (availableFocusModes.length > 0) {
            try {
                camera.focusMode = availableFocusModes[0].mode
                focusModeName = availableFocusModes[0].value
            } catch (e) {
                console.error("Could not initialize focus mode:", e)
            }
        }

        if (availableWhiteBalances.length > 0) {
            try {
                camera.whiteBalanceMode = availableWhiteBalances[0].mode
                whiteBalanceName = availableWhiteBalances[0].value
            } catch (e) {
                console.error("Could not initialize white balance:", e)
            }
        }
    }

    function setZoom(value) {
        if (recordingLocked || !hasZoom)
            return

        var z = Number(value)
        if (!isFinite(z))
            return

        z = Math.min(Math.max(z, camera.minimumZoomFactor), camera.maximumZoomFactor)
        zoomFactor = z
        camera.zoomFactor = z
    }

    function focusModeEnum(name) {
        switch (String(name)) {
        case "near": return Camera.FocusModeAutoNear
        case "far": return Camera.FocusModeAutoFar
        case "hyperfocal": return Camera.FocusModeHyperfocal
        case "infinity": return Camera.FocusModeInfinity
        case "manual": return Camera.FocusModeManual
        default: return Camera.FocusModeAuto
        }
    }

    function setFocusMode(value) {
        if (recordingLocked)
            return

        var name = String(value)
        var mode = focusModeEnum(name)

        try {
            if (!camera.isFocusModeSupported(mode))
                return

            camera.focusMode = mode
            focusModeName = name
        } catch (e) {
            console.error("Could not set focus mode:", e)
        }
    }

    function setFocusDistance(value) {
        if (recordingLocked || !canFocusDistance)
            return

        var d = Math.min(1.0, Math.max(0.0, Number(value)))

        try {
            focusDistance = d
            camera.focusDistance = d
        } catch (e) {
            console.error("Could not set focus distance:", e)
        }
    }

    function clampExposure(value) {
        var v = Math.round(Number(value))
        if (!isFinite(v))
            v = manualExposureAbsolute

        var frameMax = Math.max(
            exposureMin,
            Math.floor(10000 / Math.max(1, selectedFps))
        )

        return Math.min(
            Math.max(v, exposureMin),
            Math.min(exposureMax, frameMax)
        )
    }

    function clampGain(value) {
        var v = Math.round(Number(value))
        if (!isFinite(v))
            v = manualGain

        return Math.min(
            Math.max(v, gainMin),
            gainMax
        )
    }

    function queueManualV4l2() {
        if (!cameraActive || recordingLocked)
            return

        manualControlTimer.restart()
    }

    function setExposureTime(value) {
        if (recordingLocked || !cameraActive)
            return

        exposureModeName = "manual"
        manualExposureAbsolute = clampExposure(value)
        queueManualV4l2()
    }

    function setGain(value) {
        if (recordingLocked || !cameraActive)
            return

        exposureModeName = "manual"
        manualGain = clampGain(value)
        manualIso = manualGain
        queueManualV4l2()
    }

    function setExposureMode(value) {
        if (recordingLocked || !cameraActive)
            return

        var mode = String(value).toLowerCase() === "manual"
            ? "manual"
            : "auto"

        exposureModeName = mode

        if (mode === "auto")
            manualGain = 0

        manualControlTimer.restart()
    }

    function setExposureCompensation(value) {
        if (recordingLocked)
            return

        var ev = Number(value)
        if (isFinite(ev))
            exposureCompensation = ev
    }

    function setIso(value) {
        if (recordingLocked || !cameraActive)
            return

        var iso = Number(value)
        if (!isFinite(iso) || iso < 0)
            return

        setGain(iso)
    }

    function exposureLabel(value) {
        var v = Math.round(Number(value))
        if (!isFinite(v) || v <= 0)
            return ""

        var seconds = v * 0.0001

        if (seconds >= 1.0)
            return seconds.toFixed(1) + "s"

        return "1/" + Math.max(1, Math.round(1.0 / seconds))
    }

    function exposureOptions() {
        var candidates = [
            10, 20, 33, 50, 67, 100, 125,
            167, 200, 250, 333, 400, 500,
            667, 1000, 1250, 1667, 2000, 2500
        ]

        var result = []

        for (var i = 0; i < candidates.length; ++i) {
            var v = candidates[i]

            if (v >= exposureMin && v <= exposureMaxForCurrentFps) {
                result.push({
                    label: exposureLabel(v),
                    value: v
                })
            }
        }

        return result
    }

    function whiteBalanceEnum(name) {
        switch (String(name)) {
        case "sunlight": return Camera.WhiteBalanceSunlight
        case "cloudy": return Camera.WhiteBalanceCloudy
        case "shade": return Camera.WhiteBalanceShade
        case "tungsten": return Camera.WhiteBalanceTungsten
        case "fluorescent": return Camera.WhiteBalanceFluorescent
        case "flash": return Camera.WhiteBalanceFlash
        case "sunset": return Camera.WhiteBalanceSunset
        default: return Camera.WhiteBalanceAuto
        }
    }

    function setWhiteBalance(value) {
        if (recordingLocked)
            return

        var name = String(value)
        var mode = whiteBalanceEnum(name)

        try {
            if (!camera.isWhiteBalanceModeSupported(mode))
                return

            camera.whiteBalanceMode = mode
            whiteBalanceName = name
        } catch (e) {
            console.error("Could not set white balance:", e)
        }
    }

    function gainOptions() {
        return [
            { label: "0", value: 0 },
            { label: "1", value: 1 },
            { label: "2", value: 2 },
            { label: "3", value: 3 },
            { label: "4", value: 4 }
        ]
    }

    function isoOptions() {
        return gainOptions()
    }

    function exposureCompOptions() {
        if (!canExposureCompensation)
            return []

        return [
            { label: "−2", value: -2.0 },
            { label: "−1", value: -1.0 },
            { label: "0", value: 0.0 },
            { label: "+1", value: 1.0 },
            { label: "+2", value: 2.0 }
        ]
    }

    // Select the current explicit camera format and keep the recorder aligned.
    function syncRecorderFormat() {
        var size = selectedCameraSize()

        if (size.width <= 0 || size.height <= 0)
            return

        recorder.videoResolution = size
        recorder.videoFrameRate = selectedFps
        recorder.videoBitRate = selectedBitrate
        if (selectedCodec)
            applyCodec()
        recorder.quality = mediaRecorderQuality()
    }

    function setMirror(value) {
        if (recordingLocked)
            return

        mirrored = !!value
    }

    function refreshAllCapabilities() {
        refreshCapabilities()
        refreshCodecs()
        syncRecorderFormat()
    }

    function mediaRecorderQuality() {
        switch (selectedQuality) {
        case "medium":
            return MediaRecorder.NormalQuality
        case "high":
            return MediaRecorder.HighQuality
        case "veryHigh":
            return MediaRecorder.VeryHighQuality
        case "ultra":
            return MediaRecorder.VeryHighQuality
        default:
            return MediaRecorder.HighQuality
        }
    }

    function setQuality(value) {
        if (videoRecording || capturingPhoto)
            return

        selectedQuality = String(value)
        recorder.quality = mediaRecorderQuality()

        console.log(
            "Camera quality:",
            selectedQuality
        )
    }

    // -----------------------------------------------------------------
    // Format discovery
    // -----------------------------------------------------------------

    function formatKey(width, height) {
        return width + "x" + height
    }

    function refreshFormats() {
        availableFormats = []
        availableResolutions = []
        availableFps = []

        if (!cameraAvailable)
            return

        var formats = []

        try {
            var devices = mediaDevices.videoInputs || []

            var currentDevice = camera.cameraDevice
            var currentDeviceId = ""

            if (currentDevice && currentDevice.id)
                currentDeviceId = String(currentDevice.id)

            // Prefer the live QMediaDevices entry matching the QCamera's
            // current device. This avoids accidentally taking formats from
            // a different physical camera when multiple inputs exist.
            if (currentDeviceId.length > 0) {
                for (var d = 0; d < devices.length; ++d) {
                    var matchingDevice = devices[d]

                    if (!matchingDevice || !matchingDevice.videoFormats)
                        continue

                    if (matchingDevice.id &&
                        String(matchingDevice.id) === currentDeviceId) {
                        var matchingFormats = matchingDevice.videoFormats

                        if (matchingFormats && matchingFormats.length > 0) {
                            formats = matchingFormats
                            break
                        }
                    }
                }
            }

            // Next prefer the live default device description from
            // MediaDevices. QCameraDevice owns the documented videoFormats
            // property.
            if (!formats || formats.length === 0) {
                var defaultDevice = mediaDevices.defaultVideoInput

                if (defaultDevice && defaultDevice.videoFormats)
                    formats = defaultDevice.videoFormats
            }

            // Fall back to the first live input only if the current/default
            // device still has no reported formats.
            if (!formats || formats.length === 0) {
                for (var f = 0; f < devices.length; ++f) {
                    var candidate = devices[f]

                    if (!candidate || !candidate.videoFormats)
                        continue

                    var candidateFormats = candidate.videoFormats

                    if (candidateFormats && candidateFormats.length > 0) {
                        formats = candidateFormats
                        break
                    }
                }
            }
        } catch (e) {
            console.error("Could not query camera video formats:", e)
            return
        }

        if (!formats || formats.length === 0)
            return

        var seenResolution = ({})
        var seenFormat = ({})

        for (var i = 0; i < formats.length; ++i) {
            var f = formats[i]

            var w = f.resolution.width
            var h = f.resolution.height

            if (w <= 0 || h <= 0)
                continue

            var key = formatKey(w, h)

            var minFps = Number(f.minFrameRate)
            var maxFps = Number(f.maxFrameRate)

            var entry = {
                format: f,
                resolution: Qt.size(w, h),
                width: w,
                height: h,
                minFps: minFps,
                maxFps: maxFps
            }

            var formatId =
                key + "@" +
                minFps.toFixed(3) + "-" +
                maxFps.toFixed(3)

            if (!seenFormat[formatId]) {
                availableFormats.push(entry)
                seenFormat[formatId] = true
            }

            if (!seenResolution[key]) {
                availableResolutions.push({
                    value: key,
                    label: w >= 1900 ? "1080p"
                        : h >= 900 ? String(h) + "p"
                        : w === h ? String(w) + "²"
                        : String(h) + "p",
                    width: w,
                    height: h
                })

                seenResolution[key] = true
            }
        }

        availableResolutions.sort(function(a, b) {
            var pa = a.width * a.height
            var pb = b.width * b.height

            if (pa !== pb)
                return pb - pa

            return b.width - a.width
        })

        // The arrays above are populated with push()/sort(), which mutate
        // the existing JS array without emitting a QML property change.
        // Publish fresh array objects so bindings such as Recorder's
        // Resolution MiniSeg are reevaluated with the discovered values.
        availableFormats = availableFormats.slice()
        availableResolutions = availableResolutions.slice()

        // Prefer the webcam's native 1080p30 when available.
        var preferred = findFormat("1920x1080", 30)

        if (!preferred && availableResolutions.length > 0) {
            preferred = findFormat(
                availableResolutions[0].value,
                30
            )
        }

        if (preferred)
            applyFormat(preferred)

        rebuildFps()
    }

    function findFormat(resolution, fps) {
        var candidates = []

        for (var i = 0; i < availableFormats.length; ++i) {
            var f = availableFormats[i]

            if (formatKey(f.width, f.height) !== resolution)
                continue

            candidates.push(f)
        }

        if (candidates.length === 0)
            return null

        for (var j = 0; j < candidates.length; ++j) {
            var candidate = candidates[j]

            if (fps >= candidate.minFps &&
                fps <= candidate.maxFps)
                return candidate
        }

        candidates.sort(function(a, b) {
            return b.maxFps - a.maxFps
        })

        return candidates[0]
    }

    function rebuildFps() {
        var rates = []
        var seen = ({})

        if (!selectedResolution) {
            availableFps = []
            return
        }

        for (var i = 0; i < availableFormats.length; ++i) {
            var f = availableFormats[i]

            if (formatKey(f.width, f.height) !== selectedResolution)
                continue

            var min = Math.max(0, Math.round(Number(f.minFps)))
            var max = Math.max(0, Math.round(Number(f.maxFps)))

            if (min > 0 && !seen[min]) {
                rates.push(min)
                seen[min] = true
            }

            if (max > 0 && !seen[max]) {
                rates.push(max)
                seen[max] = true
            }
        }

        rates.sort(function(a, b) {
            return b - a
        })

        availableFps = rates

        if (availableFps.length > 0 &&
            availableFps.indexOf(selectedFps) === -1) {
            selectedFps =
                availableFps.indexOf(30) !== -1
                    ? 30
                    : availableFps[0]
        }
    }

    function applyFormat(entry) {
        if (!entry)
            return false

        try {
            camera.cameraFormat = entry.format


            selectedResolution =
                entry.width + "x" + entry.height

            selectedFps = Math.round(entry.maxFps)

            recorder.videoResolution =
                Qt.size(entry.width, entry.height)
            recorder.videoFrameRate = selectedFps

            rebuildFps()

            console.log(
                "Camera format:",
                selectedResolution,
                "@",
                selectedFps,
                "fps"
            )

            return true
        } catch (e) {
            console.error(
                "Could not apply camera format:",
                e
            )

            return false
        }
    }

    function setResolution(resolution) {
        if (videoRecording || capturingPhoto)
            return

        var f = findFormat(
            String(resolution),
            selectedFps
        )

        if (!f)
            f = findFormat(
                String(resolution),
                30
            )

        if (!f)
            return

        applyFormat(f)
    }

    function setFps(fps) {
        if (videoRecording || capturingPhoto)
            return

        var numericFps = Number(fps)

        var f = findFormat(
            selectedResolution,
            numericFps
        )

        if (!f)
            return

        camera.cameraFormat = f.format


        selectedFps = numericFps

        recorder.videoResolution =
            Qt.size(f.width, f.height)
        recorder.videoFrameRate = selectedFps

        console.log(
            "Camera FPS:",
            selectedResolution,
            "@",
            selectedFps
        )
    }

    // -----------------------------------------------------------------
    // Capture
    // -----------------------------------------------------------------

    function ensureDir(action, file) {
        mkdirProc.pendingAction = action
        mkdirProc.pendingFile = file
        mkdirProc.command = ["mkdir", "-p", outDir]
        mkdirProc.running = true
    }

    function timestamp() {
        return Qt.formatDateTime(
            new Date(),
            "yyyy-MM-dd_HH-mm-ss"
        )
    }

    function startCamera() {
        if (!cameraAvailable)
            return

        if (cameraActive)
            return

        cameraActive = true
        exposureModeName = "auto"
        manualGain = 0
        manualControlTimer.restart()
    }

    function stopCamera() {
        if (videoRecording)
            stopVideo()

        cameraActive = false
    }

    function takePhoto() {
        if (!cameraActive ||
            capturingPhoto ||
            videoRecording)
            return

        if (!imageCapture.readyForCapture)
            return

        var file =
            outDir +
            "/photo_" +
            timestamp() +
            ".jpg"

        capturingPhoto = true
        ensureDir("photo", file)
    }

    function startVideo() {
        if (!cameraActive || videoRecording)
            return

        var file =
            outDir +
            "/video_" +
            timestamp() +
            ".mp4"

        currentFile = file
        ensureDir("video", file)
    }

    function stopVideo() {
        if (!videoRecording)
            return

        recorder.stop()
    }

    Component.onCompleted: {
        Qt.callLater(root.scheduleFormatRefresh)
    }

    onCameraActiveChanged: {
        if (cameraActive) {
            exposureModeName = "auto"
            manualGain = 0
            manualControlTimer.restart()
            Qt.callLater(root.scheduleFormatRefresh)
        }
    }

    onSelectedResolutionChanged: {
        if (selectedResolution.length > 0)
            syncRecorderFormat()
    }

    onSelectedFpsChanged: {
        if (selectedFps > 0)
            syncRecorderFormat()
    }

    onSelectedQualityChanged: {
        if (!recordingLocked)
            recorder.quality = mediaRecorderQuality()
    }

    onSelectedCodecChanged: {
        if (!recordingLocked)
            applyCodec()
    }

    onSelectedBitrateChanged: {
        if (!recordingLocked)
            recorder.videoBitRate = selectedBitrate
    }
    Timer {
        id: manualControlTimer
        interval: 80
        repeat: false

        onTriggered: {
            if (!root.cameraActive || root.recordingLocked)
                return

            if (manualControlProc.running) {
                manualControlTimer.restart()
                return
            }

            if (root.exposureModeName === "auto") {
                manualControlProc.command = [
                    "v4l2-ctl",
                    "-d", "/dev/video0",
                    "--set-ctrl=auto_exposure=3,gain=0"
                ]
            } else {
                manualControlProc.command = [
                    "v4l2-ctl",
                    "-d", "/dev/video0",
                    "--set-ctrl=auto_exposure=1,exposure_dynamic_framerate=0,exposure_time_absolute="
                        + root.manualExposureAbsolute
                        + ",gain=" + root.manualGain
                ]
            }

            manualControlProc.running = true
        }
    }

    Process {
        id: manualControlProc

        stderr: StdioCollector {
            id: manualControlErr
        }

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                var err = manualControlErr.text.trim()
                console.error(
                    "Manual camera controls failed:",
                    err.length > 0 ? err : ("exit " + exitCode)
                )
            }
        }
    }

}
