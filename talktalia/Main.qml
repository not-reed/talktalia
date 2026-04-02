import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    // State: idle, loading, ready, listening, processing
    property string state: "idle"
    property string partialText: ""
    property string lastError: ""

    // Settings shortcuts
    readonly property string model: pluginApi?.pluginSettings?.model ?? "base"
    readonly property string language: pluginApi?.pluginSettings?.language ?? "en"
    readonly property string daemonPath: pluginApi?.pluginSettings?.daemonPath ?? "dictation-daemon"
    readonly property real silenceDuration: pluginApi?.pluginSettings?.silenceDuration ?? 1.5
    readonly property bool autoStart: pluginApi?.pluginSettings?.autoStart ?? false

    Component.onCompleted: {
        if (autoStart) {
            startDaemon();
        }
    }

    Component.onDestruction: {
        if (daemon.running) {
            sendCommand("shutdown");
        }
    }

    // ─── IPC ─────────────────────────────────────────────────────

    IpcHandler {
        target: "plugin:" + (pluginApi?.pluginId ?? "talktalia")

        function toggle() {
            root.toggle();
        }

        function start() {
            root.startListening();
        }

        function stop() {
            root.stopListening();
        }

        function cancel() {
            root.cancelListening();
        }
    }

    // ─── Public API ──────────────────────────────────────────────

    function toggle() {
        if (state === "idle") {
            startDaemon();
        } else if (state === "ready") {
            startListening();
        } else if (state === "listening") {
            stopListening();
        }
    }

    function startDaemon() {
        if (daemon.running) return;
        state = "loading";
        partialText = "";
        daemon.running = true;
    }

    function startListening() {
        if (state !== "ready") {
            if (state === "idle") {
                startDaemon();
            }
            return;
        }
        sendCommand("configure", {
            "model": root.model,
            "language": root.language,
            "silenceDuration": root.silenceDuration
        });
        sendCommand("start");
    }

    function stopListening() {
        if (state !== "listening") return;
        sendCommand("stop");
    }

    function cancelListening() {
        if (state !== "listening" && state !== "processing") return;
        sendCommand("cancel");
        state = "ready";
        partialText = "";
    }

    function sendCommand(cmd, extra) {
        var obj = {"cmd": cmd};
        if (extra) {
            Object.keys(extra).forEach(k => obj[k] = extra[k]);
        }
        daemon.write(JSON.stringify(obj) + "\n");
    }

    // ─── Daemon Process ──────────────────────────────────────────

    Process {
        id: daemon
        command: [root.daemonPath]
        running: false
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => root.handleEvent(line)
        }

        stderr: SplitParser {
            onRead: line => {
                Logger.w("Dictation", "stderr: " + line);
            }
        }

        onExited: (exitCode, exitStatus) => {
            var wasListening = root.state === "listening" || root.state === "processing";
            root.state = "idle";
            root.partialText = "";

            if (exitCode !== 0 && wasListening) {
                ToastService.showError("Dictation daemon exited unexpectedly (code " + exitCode + ")");
            }
        }
    }

    // ─── Text Injection ────────────────────────────────────────────

    property string pendingText: ""

    // Delay wtype slightly so overlay is fully destroyed by compositor
    Timer {
        id: injectTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (root.pendingText) {
                Quickshell.execDetached(["wtype", "--", root.pendingText]);
                root.pendingText = "";
            }
        }
    }

    function injectText(text) {
        pendingText = text;
        injectTimer.running = true;
    }

    // ─── Siri-style Overlay ──────────────────────────────────────

    Variants {
        model: (root.state === "listening" || root.state === "processing") ? Quickshell.screens.slice(0, 1) : []

        PanelWindow {
            id: overlay
            required property var modelData
            screen: modelData

            anchors {
                bottom: true
                left: true
                right: true
            }
            margins { bottom: 80 }

            implicitHeight: overlayContainer.height

            color: "transparent"
            mask: Region {}
            WlrLayershell.namespace: "noctalia:dictation-overlay"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            // Centered pill
            Item {
                id: overlayContainer
                anchors.horizontalCenter: parent.horizontalCenter
                width: overlayRect.width
                height: overlayRect.height

                Rectangle {
                    id: overlayRect
                    width: overlayContent.width + 40
                    height: overlayContent.height + 24
                    radius: 20
                    color: Qt.rgba(0, 0, 0, 0.8)
                    border.color: root.state === "listening" ? Color.mPrimary : Color.mTertiary
                    border.width: 2

                    RowLayout {
                        id: overlayContent
                        anchors.centerIn: parent
                        spacing: 12

                        // Pulsing mic dot
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            color: root.state === "listening" ? Color.mPrimary : Color.mTertiary

                            SequentialAnimation on opacity {
                                running: root.state === "listening"
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }

                        NText {
                            text: {
                                if (root.state === "processing") return "Processing...";
                                if (root.partialText) return root.partialText;
                                return "Listening...";
                            }
                            color: "#ffffff"
                            pointSize: 14
                            Layout.maximumWidth: 500
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    // ─── Event Handler ───────────────────────────────────────────

    function handleEvent(line) {
        var msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            Logger.w("Dictation", "Invalid JSON from daemon: " + line);
            return;
        }

        var event = msg.event;

        if (event === "ready") {
            state = "ready";
        } else if (event === "model_loading") {
            state = "loading";
            ToastService.showNotice("Loading dictation model...");
        } else if (event === "listening") {
            state = "listening";
            partialText = "";
        } else if (event === "partial") {
            partialText = msg.text || "";
        } else if (event === "processing") {
            state = "processing";
        } else if (event === "text") {
            var text = msg.text || "";
            partialText = "";
            // Hide overlay BEFORE injecting so wtype targets the right window
            state = "ready";
            if (text) {
                injectText(text);
            }
        } else if (event === "error") {
            lastError = msg.message || "Unknown error";
            Logger.e("Dictation", lastError);
            ToastService.showError("Dictation: " + lastError);
        }
    }
}
