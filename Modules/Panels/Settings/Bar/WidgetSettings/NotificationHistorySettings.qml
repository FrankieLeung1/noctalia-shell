import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  // Properties to receive data from parent
  property var screen: null
  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  // Local state
  property bool barIsVertical: (Settings.getBarPositionForScreen(screen?.name) === "left" || Settings.getBarPositionForScreen(screen?.name) === "right")
  property string valueDisplayMode: widgetData.displayMode !== undefined ? widgetData.displayMode : widgetMetadata.displayMode
  property string valueIconPosition: widgetData.iconPosition !== undefined ? widgetData.iconPosition : (widgetMetadata.iconPosition ?? "left")
  property string valueMiddleClickAction: widgetData.middleClickAction !== undefined ? widgetData.middleClickAction : (widgetMetadata.middleClickAction ?? "markAllRead")
  property string valueMiddleClickCommand: widgetData.middleClickCommand !== undefined ? widgetData.middleClickCommand : (widgetMetadata.middleClickCommand ?? "")
  property bool valueShowUnreadBadge: widgetData.showUnreadBadge !== undefined ? widgetData.showUnreadBadge : widgetMetadata.showUnreadBadge
  property bool valueHideWhenZero: widgetData.hideWhenZero !== undefined ? widgetData.hideWhenZero : widgetMetadata.hideWhenZero
  property bool valueHideWhenZeroUnread: widgetData.hideWhenZeroUnread !== undefined ? widgetData.hideWhenZeroUnread : widgetMetadata.hideWhenZeroUnread
  property string valueUnreadBadgeColor: widgetData.unreadBadgeColor !== undefined ? widgetData.unreadBadgeColor : widgetMetadata.unreadBadgeColor
  property string valueIconColor: widgetData.iconColor !== undefined ? widgetData.iconColor : widgetMetadata.iconColor
  property string valueTextColor: widgetData.textColor !== undefined ? widgetData.textColor : widgetMetadata.textColor

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.displayMode = valueDisplayMode;
    settings.iconPosition = valueIconPosition;
    settings.middleClickAction = valueMiddleClickAction;
    settings.middleClickCommand = valueMiddleClickCommand;
    settings.showUnreadBadge = valueShowUnreadBadge;
    settings.hideWhenZero = valueHideWhenZero;
    settings.hideWhenZeroUnread = valueHideWhenZeroUnread;
    settings.unreadBadgeColor = valueUnreadBadgeColor;
    settings.iconColor = valueIconColor;
    settings.textColor = valueTextColor;
    settingsChanged(settings);
  }

  NComboBox {
    label: I18n.tr("common.display-mode")
    description: I18n.tr("bar.volume.display-mode-description")
    minimumWidth: 200
    model: [
      {
        "key": "onhover",
        "name": I18n.tr("display-modes.on-hover")
      },
      {
        "key": "alwaysShow",
        "name": I18n.tr("display-modes.always-show")
      },
      {
        "key": "alwaysHide",
        "name": I18n.tr("display-modes.always-hide")
      }
    ]
    currentKey: valueDisplayMode
    onSelected: key => {
      valueDisplayMode = key;
      saveSettings();
    }
    defaultValue: widgetMetadata.displayMode
  }

  NComboBox {
    label: I18n.tr("bar.custom-button.icon-position-label")
    description: I18n.tr("bar.custom-button.icon-position-description")
    model: barIsVertical ? [
                             {
                               name: I18n.tr("bar.custom-button.icon-position-top"),
                               key: "left"
                             },
                             {
                               name: I18n.tr("bar.custom-button.icon-position-bottom"),
                               key: "right"
                             }
                           ] : [
                             {
                               name: I18n.tr("bar.custom-button.icon-position-left"),
                               key: "left"
                             },
                             {
                               name: I18n.tr("bar.custom-button.icon-position-right"),
                               key: "right"
                             }
                           ]
    currentKey: valueIconPosition
    onSelected: key => {
      valueIconPosition = key;
      saveSettings();
    }
    defaultValue: widgetMetadata.iconPosition
  }

  NColorChoice {
    label: I18n.tr("common.select-icon-color")
    currentKey: valueIconColor
    onSelected: key => {
      valueIconColor = key;
      saveSettings();
    }
    defaultValue: widgetMetadata.iconColor
  }

  NColorChoice {
    currentKey: valueTextColor
    onSelected: key => {
      valueTextColor = key;
      saveSettings();
    }
    defaultValue: widgetMetadata.textColor
  }

  NComboBox {
    label: I18n.tr("panels.bar.behavior-middle-click-label")
    description: I18n.tr("bar.notification-history.middle-click-action-description")
    minimumWidth: 200
    model: [
      {
        "key": "markAllRead",
        "name": I18n.tr("actions.mark-all-read")
      },
      {
        "key": "clearHistory",
        "name": I18n.tr("actions.clear-history")
      },
      {
        "key": "toggleDnd",
        "name": I18n.tr("actions.toggle-dnd")
      },
      {
        "key": "openSettings",
        "name": I18n.tr("actions.widget-settings")
      },
      {
        "key": "command",
        "name": I18n.tr("actions.run-custom-command")
      },
      {
        "key": "none",
        "name": I18n.tr("common.none")
      }
    ]
    currentKey: valueMiddleClickAction
    onSelected: key => {
      valueMiddleClickAction = key;
      saveSettings();
    }
    defaultValue: widgetMetadata.middleClickAction
  }

  NTextInput {
    label: I18n.tr("panels.bar.behavior-middle-click-command-label")
    description: I18n.tr("panels.bar.behavior-middle-click-command-description")
    placeholderText: I18n.tr("panels.bar.behavior-middle-click-command-placeholder")
    text: valueMiddleClickCommand
    onTextChanged: {
      valueMiddleClickCommand = text;
      saveSettings();
    }
    visible: valueMiddleClickAction === "command"
    defaultValue: widgetMetadata.middleClickCommand
  }

  NToggle {
    label: I18n.tr("bar.notification-history.show-unread-badge-label")
    description: I18n.tr("bar.notification-history.show-unread-badge-description")
    checked: valueShowUnreadBadge
    onToggled: checked => {
      valueShowUnreadBadge = checked;
      saveSettings();
    }
    defaultValue: widgetMetadata.showUnreadBadge
  }

  NColorChoice {
    label: I18n.tr("bar.notification-history.unread-badge-color-label")
    description: I18n.tr("bar.notification-history.unread-badge-color-description")
    currentKey: valueUnreadBadgeColor
    onSelected: key => {
      valueUnreadBadgeColor = key;
      saveSettings();
    }
    visible: valueShowUnreadBadge
    defaultValue: widgetMetadata.unreadBadgeColor
  }

  NToggle {
    label: I18n.tr("bar.notification-history.hide-widget-when-zero-label")
    description: I18n.tr("bar.notification-history.hide-widget-when-zero-description")
    checked: valueHideWhenZero
    onToggled: checked => {
      valueHideWhenZero = checked;
      saveSettings();
    }
    enabled: !valueHideWhenZeroUnread
    defaultValue: widgetMetadata.hideWhenZero
  }

  NToggle {
    label: I18n.tr("bar.notification-history.hide-widget-when-zero-unread-label")
    description: I18n.tr("bar.notification-history.hide-widget-when-zero-unread-description")
    checked: valueHideWhenZeroUnread
    onToggled: checked => {
      valueHideWhenZeroUnread = checked;
      saveSettings();
    }
    defaultValue: widgetMetadata.hideWhenZeroUnread
  }
}
