import QtQuick
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

  property string valueInactiveColor: widgetData.inactiveColor !== undefined ? widgetData.inactiveColor : widgetMetadata.inactiveColor
  property string valueActiveColor: widgetData.activeColor !== undefined ? widgetData.activeColor : widgetMetadata.activeColor

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.inactiveColor = valueInactiveColor;
    settings.activeColor = valueActiveColor;
    settingsChanged(settings);
  }

  NColorChoice {
    label: I18n.tr("bar.keep-awake.select-inactive-color-label")
    currentKey: valueInactiveColor
    onSelected: key => {
      valueInactiveColor = key;
      saveSettings();
    }
    defaultValue: widgetMetadata.inactiveColor
  }

  NColorChoice {
    label: I18n.tr("bar.keep-awake.select-active-color-label")
    currentKey: valueActiveColor
    onSelected: key => {
      valueActiveColor = key;
      saveSettings();
    }
    defaultValue: widgetMetadata.activeColor
  }
}
