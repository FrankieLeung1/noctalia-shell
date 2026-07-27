import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Power
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // Master enable
  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.idle.enable-label")
    description: I18n.tr("panels.idle.enable-description")
    checked: Settings.data.idle.enabled
    defaultValue: Settings.getDefaultValue("idle.enabled")
    onToggled: checked => Settings.data.idle.enabled = checked
  }

  // Live idle status
  RowLayout {
    Layout.fillWidth: true
    enabled: Settings.data.idle.enabled
    visible: IdleService.nativeIdleMonitorAvailable

    NLabel {
      label: I18n.tr("panels.idle.status-label")
      description: I18n.tr("panels.idle.status-description")
    }

    Item {
      Layout.fillWidth: true
    }

    NText {
      Layout.alignment: Qt.AlignBottom | Qt.AlignRight
      text: IdleService.idleSeconds > 0 ? I18n.trp("common.second", IdleService.idleSeconds) : I18n.tr("common.active")
      family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeM
      color: IdleService.idleSeconds > 0 ? Color.mPrimary : Color.mOnSurfaceVariant
    }
  }

  NLabel {
    visible: !IdleService.nativeIdleMonitorAvailable
    description: I18n.tr("panels.idle.unavailable")
  }

  NDivider {
    Layout.fillWidth: true
  }

  IdleCommandEditPopup {
    id: editPopup
    parent: Overlay.overlay
  }

  function openEdit(actionName, cmdVal, resumeCmdVal, onSaveCmd, onSaveResume) {
    editPopup.editIndex = -1;
    editPopup.showCommand = true;
    editPopup.showTimeout = false;
    editPopup.titleText = I18n.tr("common.edit") + " " + actionName;
    editPopup.timeoutValue = 0;
    editPopup.commandValue = cmdVal;
    editPopup.resumeCommandValue = resumeCmdVal;

    try {
      editPopup.saved.disconnect(editPopup._savedSlot);
    } catch (e) {}

    editPopup._savedSlot = function (timeout, cmd, resumeCmd, name) {
      onSaveCmd(cmd);
      onSaveResume(resumeCmd);
    };

    editPopup.saved.connect(editPopup._savedSlot);
    editPopup.open();
  }

  // Timeout spinboxes and resume commands
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginL
    enabled: Settings.data.idle.enabled

    NLabel {
      label: I18n.tr("panels.idle.timeouts-label")
      description: I18n.tr("panels.idle.timeouts-description")
    }

    DefaultActionRow {
      actionName: I18n.tr("panels.idle.screen-off-label")
      actionDescription: I18n.tr("panels.idle.screen-off-description")
      timeoutValue: Settings.data.idle.screenOffTimeout
      defaultValue: Settings.getDefaultValue("idle.screenOffTimeout")
      command: Settings.data.idle.screenOffCommand
      resumeCommand: Settings.data.idle.resumeScreenOffCommand
      onActionTimeoutChanged: val => Settings.data.idle.screenOffTimeout = val
      onActionCommandChanged: cmd => {
        Settings.data.idle.screenOffCommand = cmd;
        Settings.saveImmediate();
      }
      onActionResumeCommandChanged: cmd => {
        Settings.data.idle.resumeScreenOffCommand = cmd;
        Settings.saveImmediate();
      }
    }

    DefaultActionRow {
      actionName: I18n.tr("panels.idle.lock-screen-off-label")
      actionDescription: I18n.tr("panels.idle.lock-screen-off-description")
      timeoutValue: Settings.data.idle.lockScreenOffTimeout
      defaultValue: Settings.getDefaultValue("idle.lockScreenOffTimeout")
      hasCommands: false
      onActionTimeoutChanged: val => Settings.data.idle.lockScreenOffTimeout = val
    }

    DefaultActionRow {
      actionName: I18n.tr("panels.idle.lock-label")
      actionDescription: I18n.tr("panels.idle.lock-description")
      timeoutValue: Settings.data.idle.lockTimeout
      defaultValue: Settings.getDefaultValue("idle.lockTimeout")
      command: Settings.data.idle.lockCommand
      resumeCommand: Settings.data.idle.resumeLockCommand
      onActionTimeoutChanged: val => Settings.data.idle.lockTimeout = val
      onActionCommandChanged: cmd => {
        Settings.data.idle.lockCommand = cmd;
        Settings.saveImmediate();
      }
      onActionResumeCommandChanged: cmd => {
        Settings.data.idle.resumeLockCommand = cmd;
        Settings.saveImmediate();
      }
    }

    DefaultActionRow {
      actionName: I18n.tr("common.suspend")
      actionDescription: I18n.tr("panels.idle.suspend-description")
      timeoutValue: Settings.data.idle.suspendTimeout
      defaultValue: Settings.getDefaultValue("idle.suspendTimeout")
      command: Settings.data.idle.suspendCommand
      resumeCommand: Settings.data.idle.resumeSuspendCommand
      onActionTimeoutChanged: val => Settings.data.idle.suspendTimeout = val
      onActionCommandChanged: cmd => {
        Settings.data.idle.suspendCommand = cmd;
        Settings.saveImmediate();
      }
      onActionResumeCommandChanged: cmd => {
        Settings.data.idle.resumeSuspendCommand = cmd;
        Settings.saveImmediate();
      }
    }

    NDivider {
      Layout.fillWidth: true
    }

    NSpinBox {
      label: I18n.tr("panels.idle.fade-duration-label")
      description: I18n.tr("panels.idle.fade-duration-description")
      from: 1
      to: 60
      suffix: "s"
      value: Settings.data.idle.fadeDuration
      defaultValue: Settings.getDefaultValue("idle.fadeDuration")
      onValueChanged: Settings.data.idle.fadeDuration = value
    }

    NDivider {
      Layout.fillWidth: true
    }

    // Idle inhibit ignore list
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NLabel {
        label: I18n.tr("panels.idle.ignore-list-label")
        description: I18n.tr("panels.idle.ignore-list-description")
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NTextInputButton {
          id: newIgnoreInput
          Layout.fillWidth: true
          placeholderText: I18n.tr("panels.idle.ignore-list-placeholder")
          buttonIcon: "add"
          onButtonClicked: {
            if (newIgnoreInput.text.length > 0) {
              var newEntry = newIgnoreInput.text.trim();
              var exists = false;
              for (var i = 0; i < ignoreListModel.count; i++) {
                if (ignoreListModel.get(i).rule === newEntry) {
                  exists = true;
                  break;
                }
              }
              if (!exists) {
                ignoreListModel.append({ "rule": newEntry });
                newIgnoreInput.text = "";
                saveIgnoreList();
              }
            }
          }
        }
      }
    }

    // List of current ignore list items
    NListView {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.max(50, Math.min(150, ignoreListModel.count * 40))
      visible: ignoreListModel.count > 0
      gradientColor: Color.mSurface

      model: ignoreListModel
      delegate: Item {
        width: ListView.width
        height: 40

        Rectangle {
          anchors.fill: parent
          anchors.margins: Style.marginXS
          color: "transparent"
          border.color: Color.mOutline
          border.width: Style.borderS
          radius: Style.radiusS
          visible: model.rule !== undefined && model.rule !== ""
        }

        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.marginS
          anchors.rightMargin: Style.marginS
          spacing: Style.marginS

          NText {
            anchors.verticalCenter: parent.verticalCenter
            text: model.rule
            elide: Text.ElideRight
          }

          NIconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "close"
            baseSize: 12 * Style.uiScaleRatio
            colorBg: Color.mSurfaceVariant
            colorFg: Color.mOnSurfaceVariant
            colorBgHover: Color.mError
            colorFgHover: Color.mOnError
            onClicked: {
              ignoreListModel.remove(index);
              saveIgnoreList();
            }
          }
        }
      }
    }
  }

  ListModel {
    id: ignoreListModel
  }

  Component.onCompleted: {
    // Load existing ignore list from settings
    try {
      var list = JSON.parse(Settings.data.idle.idleInhibitIgnoreList);
      for (var i = 0; i < list.length; i++) {
        ignoreListModel.append({ "rule": list[i] });
      }
    } catch (e) {}
  }

  function saveIgnoreList() {
    var newList = [];
    for (var i = 0; i < ignoreListModel.count; i++) {
      newList.push(ignoreListModel.get(i).rule);
    }
    Settings.data.idle.idleInhibitIgnoreList = JSON.stringify(newList);
    Settings.saveImmediate();
  }

  component DefaultActionRow: RowLayout {
    id: rowRoot
    Layout.fillWidth: true
    spacing: Style.marginM

    property string actionName
    property string actionDescription
    property alias timeoutValue: spinBox.value
    property int defaultValue
    property string command
    property string resumeCommand
    property bool hasCommands: true

    signal actionTimeoutChanged(int newValue)
    signal actionCommandChanged(string newCmd)
    signal actionResumeCommandChanged(string newCmd)

    NSpinBox {
      id: spinBox
      Layout.fillWidth: true
      label: rowRoot.actionName
      description: rowRoot.actionDescription
      from: 0
      to: 86400
      suffix: "s"
      defaultValue: rowRoot.defaultValue
      onValueChanged: rowRoot.actionTimeoutChanged(value)
    }

    NIconButton {
      id: settingsButton
      Layout.alignment: Qt.AlignVCenter
      icon: "settings"
      tooltipText: I18n.tr("common.edit")
      visible: rowRoot.hasCommands
      onClicked: root.openEdit(rowRoot.actionName, rowRoot.command, rowRoot.resumeCommand, rowRoot.actionCommandChanged, rowRoot.actionResumeCommandChanged)
    }

    Item {
      Layout.alignment: Qt.AlignVCenter
      implicitWidth: settingsButton.implicitWidth
      implicitHeight: settingsButton.implicitHeight
      visible: !rowRoot.hasCommands
    }
  }
}
