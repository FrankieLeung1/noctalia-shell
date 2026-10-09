import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.System
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  // Explicit screenName property ensures reactive binding when screen changes
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property string displayMode: widgetSettings.displayMode !== undefined ? widgetSettings.displayMode : (widgetMetadata.displayMode ?? "onhover")
  readonly property bool showUnreadBadge: widgetSettings.showUnreadBadge !== undefined ? widgetSettings.showUnreadBadge : widgetMetadata.showUnreadBadge
  readonly property bool showTimeSinceLastNotification: widgetSettings.showTimeSinceLastNotification !== undefined ? widgetSettings.showTimeSinceLastNotification : (widgetMetadata.showTimeSinceLastNotification ?? true)
  readonly property bool hideWhenZero: widgetSettings.hideWhenZero !== undefined ? widgetSettings.hideWhenZero : widgetMetadata.hideWhenZero
  readonly property bool hideWhenZeroUnread: widgetSettings.hideWhenZeroUnread !== undefined ? widgetSettings.hideWhenZeroUnread : widgetMetadata.hideWhenZeroUnread
  readonly property string unreadBadgeColor: widgetSettings.unreadBadgeColor !== undefined ? widgetSettings.unreadBadgeColor : widgetMetadata.unreadBadgeColor
  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor
  readonly property string textColorKey: widgetSettings.textColor !== undefined ? widgetSettings.textColor : widgetMetadata.textColor
  readonly property string iconPosition: widgetSettings.iconPosition !== undefined ? widgetSettings.iconPosition : (widgetMetadata.iconPosition ?? "left")
  readonly property string middleClickAction: widgetSettings.middleClickAction !== undefined ? widgetSettings.middleClickAction : (widgetMetadata.middleClickAction ?? "markAllRead")
  readonly property string middleClickCommand: widgetSettings.middleClickCommand !== undefined ? widgetSettings.middleClickCommand : (widgetMetadata.middleClickCommand ?? "")

  readonly property color badgeColor: Color.resolveColorKey(unreadBadgeColor)

  property int revision: 0

  Connections {
    target: NotificationService.historyModel
    function onCountChanged() {
      root.revision++;
    }
  }

  Connections {
    target: NotificationService.popupModel
    function onCountChanged() {
      root.revision++;
    }
  }

  Connections {
    target: NotificationService
    function onLastSeenTsChanged() {
      root.revision++;
    }
    function onDoNotDisturbChanged() {
      root.revision++;
    }
  }

  readonly property var unreadInfo: {
    var _rev = root.revision;
    var _now = Time.now;
    var since = NotificationService.lastSeenTs;
    var model = NotificationService.historyModel;
    var totalCount = model.count;
    var unreadCount = 0;
    var latestTitle = "";
    var latestItem = null;
    var latestTimestamp = 0;
    var uniqueApps = [];

    for (var i = 0; i < totalCount; i++) {
      var item = model.get(i);
      if (!item)
        continue;
      var ts = item.timestamp instanceof Date ? item.timestamp.getTime() : item.timestamp;
      if (ts > since) {
        unreadCount++;
        var title = (item.summary || "").trim().replace(/\s+/g, " ");
        if (!title) {
          title = (item.appName || "").trim() || (item.body || "").trim().replace(/\s+/g, " ") || I18n.tr("common.notification");
        }
        if (latestTitle === "") {
          latestTitle = title;
          latestItem = item;
          latestTimestamp = ts;
        }
        var appName = (item.appName || "").trim() || title;
        if (uniqueApps.indexOf(appName) === -1) {
          uniqueApps.push(appName);
        }
      }
    }

    var isGenericFreedesktopIcon = function(origImg) {
      if (!origImg)
        return false;
      var lower = origImg.toLowerCase();
      var genericNames = [
        "application-x-executable",
        "dialog-information",
        "dialog-warning",
        "dialog-error",
        "dialog-question",
        "dialog-password",
        "preferences-desktop-notification",
        "preferences-desktop-notification-bell",
        "applications-other",
        "system-run",
        "notification-symbolic",
        "dialog-information-symbolic",
        "notification"
      ];
      for (var k = 0; k < genericNames.length; k++) {
        var g = genericNames[k];
        if (lower.indexOf("fallback=" + g) !== -1 || lower.indexOf("/icon/" + g) !== -1 || lower.indexOf("/" + g + ".") !== -1 || lower === g || lower === "image://icon/" + g) {
          return true;
        }
      }
      return false;
    };

    var appIcon = "";
    if (unreadCount > 0 && uniqueApps.length === 1 && latestItem) {
      var orig = (latestItem.originalImage || "").trim();
      var isGeneric = isGenericFreedesktopIcon(orig);
      if (!isGeneric) {
        var img = latestItem.cachedImage || latestItem.originalImage || "";
        if (img && (img.startsWith("file://") || img.startsWith("/") || img.startsWith("image://"))) {
          appIcon = img;
        } else {
          var rawApp = (latestItem.appName || "").trim();
          if (rawApp) {
            var resolved = ThemeIcons.findAppEntry(rawApp.toLowerCase()) ? ThemeIcons.iconForAppId(rawApp.toLowerCase(), "") : "";
            if (resolved && !isGenericFreedesktopIcon(resolved)) {
              appIcon = resolved;
            }
          }
        }
      }
    }

    var timeText = "";
    if (latestTimestamp > 0) {
      var diffSec = Math.max(0, Math.floor((_now.getTime() - latestTimestamp) / 1000));
      if (diffSec < 60) {
        timeText = "< 1m";
      } else {
        var days = Math.floor(diffSec / 86400);
        var hours = Math.floor((diffSec % 86400) / 3600);
        var minutes = Math.floor((diffSec % 3600) / 60);
        var parts = [];
        if (days > 0)
          parts.push(days + "d");
        if (hours > 0)
          parts.push(hours + "h");
        if (minutes > 0)
          parts.push(minutes + "m");
        timeText = parts.join(" ");
      }
    }

    return {
      count: unreadCount,
      latestTitle: latestTitle,
      appCount: uniqueApps.length,
      appIcon: appIcon,
      timeText: timeText
    };
  }

  readonly property int count: unreadInfo.count

  implicitWidth: pill.width
  implicitHeight: pill.height

  visible: !((hideWhenZero && NotificationService.historyModel.count === 0) || (hideWhenZeroUnread && count === 0))
  opacity: !((hideWhenZero && NotificationService.historyModel.count === 0) || (hideWhenZeroUnread && count === 0)) ? 1.0 : 0.0

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": NotificationService.doNotDisturb ? I18n.tr("actions.disable-dnd") : I18n.tr("actions.enable-dnd"),
        "action": "toggle-dnd",
        "icon": NotificationService.doNotDisturb ? "bell" : "bell-off"
      },
      {
        "label": I18n.tr("actions.clear-history"),
        "action": "clear-history",
        "icon": "trash"
      },
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);

      if (action === "toggle-dnd") {
        NotificationService.doNotDisturb = !NotificationService.doNotDisturb;
      } else if (action === "clear-history") {
        NotificationService.clearHistory();
      } else if (action === "widget-settings") {
        BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
      }
    }
  }

  BarPill {
    id: pill

    screen: root.screen
    iconPosition: root.iconPosition
    oppositeDirection: BarService.getPillDirection(root)
    customIconColor: Color.resolveColorKeyOptional(root.iconColorKey)
    customTextColor: Color.resolveColorKeyOptional(root.textColorKey)
    icon: NotificationService.doNotDisturb ? "bell-off" : "bell"
    iconImage: NotificationService.doNotDisturb ? "" : root.unreadInfo.appIcon
    text: root.unreadInfo.latestTitle
    suffix: {
      var s = "";
      if (root.unreadInfo.appCount > 1) {
        s += ` + ${root.unreadInfo.appCount - 1}`;
      }
      if (root.showTimeSinceLastNotification && root.unreadInfo.timeText) {
        s += ` | ${root.unreadInfo.timeText}`;
      }
      return s;
    }
    autoHide: false
    forceOpen: !isBarVertical && root.displayMode === "alwaysShow" && text !== ""
    forceClose: isBarVertical || root.displayMode === "alwaysHide" || text === ""
    showBadge: root.showUnreadBadge
    badgeVisible: root.count > 0
    badgeColor: root.badgeColor

    onClicked: {
      var panel = PanelService.getPanel("notificationHistoryPanel", screen);
      if (panel)
        panel.toggle(this);
    }

    onRightClicked: {
      PanelService.showContextMenu(contextMenu, pill, screen);
    }

    onMiddleClicked: {
      switch (root.middleClickAction) {
      case "markAllRead":
        NotificationService.updateLastSeenTs();
        var panel = PanelService.getPanel("notificationHistoryPanel", screen);
        if (panel && panel.isPanelOpen && panel.panelContent) {
          panel.panelContent.sessionLastSeenTs = NotificationService.lastSeenTs;
          panel.panelContent.recalcRangeCounts();
        }
        break;
      case "clearHistory":
        NotificationService.clearHistory();
        break;
      case "toggleDnd":
        NotificationService.doNotDisturb = !NotificationService.doNotDisturb;
        break;
      case "openSettings":
        BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
        break;
      case "command":
        if (root.middleClickCommand) {
          Quickshell.execDetached(["sh", "-lc", root.middleClickCommand]);
        }
        break;
      case "none":
      default:
        break;
      }
    }

    tooltipText: {
      if (PanelService.getPanel("notificationHistoryPanel", screen)?.isPanelOpen) {
        return "";
      } else {
        return I18n.tr("tooltips.open-notification-history-enable-dnd");
      }
    }
  }
}
