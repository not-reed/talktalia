import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

ColumnLayout {
    id: root
    spacing: Style.marginL

    property var pluginApi: null

    property string editModel: pluginApi?.pluginSettings?.model ?? pluginApi?.manifest?.metadata?.defaultSettings?.model ?? "base"
    property string editLanguage: pluginApi?.pluginSettings?.language || pluginApi?.manifest?.metadata?.defaultSettings?.language || "en"
    property string editDaemonPath: pluginApi?.pluginSettings?.daemonPath || pluginApi?.manifest?.metadata?.defaultSettings?.daemonPath || "dictation-daemon"
    property real editSilenceDuration: pluginApi?.pluginSettings?.silenceDuration ?? pluginApi?.manifest?.metadata?.defaultSettings?.silenceDuration ?? 1.5
    property bool editHideInactive: pluginApi?.pluginSettings?.hideInactive ?? pluginApi?.manifest?.metadata?.defaultSettings?.hideInactive ?? false
    property bool editAutoStart: pluginApi?.pluginSettings?.autoStart ?? pluginApi?.manifest?.metadata?.defaultSettings?.autoStart ?? false

    function saveSettings() {
        if (!pluginApi) return;

        pluginApi.pluginSettings.model = root.editModel;
        pluginApi.pluginSettings.language = root.editLanguage;
        pluginApi.pluginSettings.daemonPath = root.editDaemonPath;
        pluginApi.pluginSettings.silenceDuration = root.editSilenceDuration;
        pluginApi.pluginSettings.hideInactive = root.editHideInactive;
        pluginApi.pluginSettings.autoStart = root.editAutoStart;

        pluginApi.saveSettings();
    }

    // Model
    NComboBox {
        label: "Whisper Model"
        description: "Larger models are more accurate but slower and use more VRAM."
        model: [
            { "key": "tiny", "name": "Tiny (~1GB VRAM)" },
            { "key": "base", "name": "Base (~1GB VRAM)" },
            { "key": "small", "name": "Small (~2GB VRAM)" },
            { "key": "medium", "name": "Medium (~5GB VRAM)" },
            { "key": "large-v3", "name": "Large v3 (~10GB VRAM)" }
        ]
        currentKey: root.editModel
        onSelected: key => root.editModel = key
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.model ?? "base"
    }

    // Language
    NTextInput {
        label: "Language"
        description: "ISO 639-1 code (e.g., en, fr, de) or 'auto' for auto-detection."
        placeholderText: "en"
        text: root.editLanguage
        onTextChanged: root.editLanguage = text
        Layout.fillWidth: true
    }

    NDivider {
        Layout.fillWidth: true
    }

    // Silence Duration
    NComboBox {
        label: "Silence Duration"
        description: "How long to wait after you stop speaking before finalizing. Longer = fewer accidental cutoffs."
        model: [
            { "key": "0.5", "name": "0.5s (aggressive)" },
            { "key": "1.0", "name": "1.0s" },
            { "key": "1.5", "name": "1.5s (default)" },
            { "key": "2.0", "name": "2.0s" },
            { "key": "3.0", "name": "3.0s (patient)" }
        ]
        currentKey: String(root.editSilenceDuration)
        onSelected: key => root.editSilenceDuration = parseFloat(key)
        defaultValue: "1.5"
    }

    // Daemon Path
    NTextInput {
        label: "Daemon Path"
        description: "Path to the dictation-daemon executable."
        placeholderText: "dictation-daemon"
        text: root.editDaemonPath
        onTextChanged: root.editDaemonPath = text
        Layout.fillWidth: true
    }

    NDivider {
        Layout.fillWidth: true
    }

    // Hide When Inactive
    NToggle {
        label: "Hide When Inactive"
        description: "Hide the bar widget when not actively dictating."
        checked: root.editHideInactive
        onToggled: root.editHideInactive = checked
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.hideInactive ?? false
    }

    // Auto Start
    NToggle {
        label: "Auto Start Daemon"
        description: "Automatically start the dictation daemon when the plugin loads."
        checked: root.editAutoStart
        onToggled: root.editAutoStart = checked
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.autoStart ?? false
    }

    Item {
        Layout.fillHeight: true
    }
}
