import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""

    readonly property string screenName: screen ? screen.name : ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property real barHeight: Style.getBarHeightForScreen(screenName)
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property string dictState: mainInstance?.state ?? "idle"
    readonly property bool hideInactive:
        pluginApi?.pluginSettings?.hideInactive ??
        pluginApi?.manifest?.metadata?.defaultSettings?.hideInactive ??
        false

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
    readonly property string iconColorKey: cfg.iconColor ?? defaults.iconColor ?? "none"
    readonly property color iconColor: Color.resolveColorKey(iconColorKey)

    readonly property bool shouldShow: !hideInactive || dictState === "listening" || dictState === "processing" || dictState === "loading"

    visible: true
    opacity: shouldShow ? 1.0 : 0.0
    implicitWidth: shouldShow ? baseSize : 0
    implicitHeight: shouldShow ? baseSize : 0

    Behavior on opacity {
        NumberAnimation { duration: Style.animationNormal }
    }

    Behavior on implicitWidth {
        NumberAnimation { duration: Style.animationNormal }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: Style.animationNormal }
    }

    icon: "microphone"
    tooltipText: {
        if (dictState === "idle") return "Dictation (click to start)";
        if (dictState === "loading") return "Loading model...";
        if (dictState === "ready") return "Ready (click to listen)";
        if (dictState === "listening") return "Listening... (click to stop)";
        if (dictState === "processing") return "Processing...";
        return "Dictation";
    }
    tooltipDirection: BarService.getTooltipDirection()
    baseSize: root.capsuleHeight
    applyUiScale: false
    customRadius: Style.radiusL

    colorBg: {
        if (dictState === "listening") return Color.mPrimary;
        if (dictState === "processing") return Color.mTertiary;
        if (dictState === "loading") return Color.mSecondary;
        return Style.capsuleColor;
    }
    colorFg: {
        if (dictState === "listening") return Color.mOnPrimary;
        if (dictState === "processing") return Color.mOnTertiary;
        if (dictState === "loading") return Color.mOnSecondary;
        return root.iconColor;
    }
    colorBorder: "transparent"
    colorBorderHover: "transparent"
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    // Pulse animation when listening
    SequentialAnimation on opacity {
        id: pulseAnim
        running: dictState === "listening" && shouldShow
        loops: Animation.Infinite
        NumberAnimation { to: 0.6; duration: 800; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
        onRunningChanged: {
            if (!running) root.opacity = shouldShow ? 1.0 : 0.0;
        }
    }

    onClicked: {
        if (mainInstance) {
            mainInstance.toggle();
        }
    }

    onRightClicked: {
        PanelService.showContextMenu(contextMenu, root, screen);
    }

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": I18n.tr("actions.widget-settings"),
                "action": "widget-settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);

            if (action === "widget-settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest);
            }
        }
    }
}
