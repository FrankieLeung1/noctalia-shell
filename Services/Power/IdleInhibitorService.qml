pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI

Singleton {
  id: root

  property bool isInhibited: false
  property bool isManuallyInhibited: false
  property string reason: I18n.tr("system.user-requested")
  property var activeInhibitors: []
  property var timeout: null // in seconds

  // True when the native Wayland IdleInhibitor is handling inhibition
  // (set by the IdleInhibitor element in MainScreen via the nativeInhibitor property)
  property bool nativeInhibitorAvailable: false

  function init() {
    Logger.i("IdleInhibitor", "Service started");
  }

  // Add an inhibitor
  function addInhibitor(id, reason = "Application request") {
    if (activeInhibitors.includes(id)) {
      Logger.w("IdleInhibitor", "Inhibitor already active:", id);
      return false;
    }

    activeInhibitors.push(id);
    updateInhibition(reason);
    Logger.d("IdleInhibitor", "Added inhibitor:", id);
    return true;
  }

  // Remove an inhibitor
  function removeInhibitor(id) {
    const index = activeInhibitors.indexOf(id);
    if (index === -1) {
      Logger.w("IdleInhibitor", "Inhibitor not found:", id);
      return false;
    }

    activeInhibitors.splice(index, 1);
    updateInhibition();
    Logger.d("IdleInhibitor", "Removed inhibitor:", id);
    return true;
  }

  // Update the actual system inhibition
  function updateInhibition(newReason = reason) {
    isManuallyInhibited = activeInhibitors.includes("manual");
    const shouldInhibit = activeInhibitors.length > 0;

    if (shouldInhibit === isInhibited) {
      return;
      // No change needed
    }

    if (shouldInhibit) {
      startInhibition(newReason);
    } else {
      stopInhibition();
    }
  }

  // Start system inhibition
  function startInhibition(newReason) {
    reason = newReason;

    if (nativeInhibitorAvailable) {
      // Native IdleInhibitor in MainScreen handles it via isInhibited binding
      Logger.d("IdleInhibitor", "Native inhibitor active");
    } else {
      startSubprocessInhibition();
    }

    isInhibited = true;
    Logger.i("IdleInhibitor", "Started inhibition:", reason);
  }

  // Stop system inhibition
  function stopInhibition() {
    if (!isInhibited)
      return;

    if (!nativeInhibitorAvailable && inhibitorProcess.running) {
      inhibitorProcess.signal(15); // SIGTERM
    }

    isInhibited = false;
    Logger.i("IdleInhibitor", "Stopped inhibition");
  }

  // Subprocess fallback using systemd-inhibit
  function startSubprocessInhibition() {
    inhibitorProcess.command = ["systemd-inhibit", "--what=idle", "--why=" + reason, "--mode=block", "sleep", "infinity"];
    inhibitorProcess.running = true;
  }

  // Process for maintaining the inhibition (subprocess fallback only)
  Process {
    id: inhibitorProcess
    running: false

    onExited: function (exitCode, exitStatus) {
      if (isInhibited) {
        Logger.w("IdleInhibitor", "Inhibitor process exited unexpectedly:", exitCode);
        isInhibited = false;
      }
    }

    onStarted: function () {
      Logger.d("IdleInhibitor", "Inhibitor process started successfully");
    }
  }

  Timer {
    id: inhibitorTimeout
    repeat: true
    interval: 1000 // 1 second
    onTriggered: function () {
      if (timeout == null) {
        inhibitorTimeout.stop();
        return;
      }

      timeout -= 1;
      if (timeout <= 0) {
        removeManualInhibitor();
        return;
      }
    }
  }

  // Manual toggle for user control
  function manualToggle() {
    // clear any existing timeout
    timeout = null;
    if (activeInhibitors.includes("manual")) {
      removeManualInhibitor();
      return false;
    } else {
      addManualInhibitor(null);
      return true;
    }
  }

  function changeTimeout(delta) {
    if (timeout == null && delta < 0) {
      // no inhibitor, ignored
      return;
    }

    if (timeout == null && delta > 0) {
      // enable manual inhibitor and set timeout
      addManualInhibitor(timeout + delta);
      return;
    }

    if (timeout + delta <= 0) {
      // disable manual inhibitor
      removeManualInhibitor();
      return;
    }

    if (timeout + delta > 0) {
      // change timeout
      addManualInhibitor(timeout + delta);
      return;
    }
  }

  function removeManualInhibitor() {
    if (timeout !== null) {
      timeout = null;
      if (inhibitorTimeout.running) {
        inhibitorTimeout.stop();
      }
    }

    if (activeInhibitors.includes("manual")) {
      removeInhibitor("manual");
      ToastService.showNotice(I18n.tr("tooltips.keep-awake"), I18n.tr("common.disabled"), "keep-awake-off");
      Logger.i("IdleInhibitor", "Manual inhibition disabled");
    }
  }

  function addManualInhibitor(timeoutSec) {
    if (!activeInhibitors.includes("manual")) {
      addInhibitor("manual", "Manually activated by user");
      ToastService.showNotice(I18n.tr("tooltips.keep-awake"), I18n.tr("common.enabled"), "keep-awake-on");
    }

    if (timeoutSec === null && timeout === null) {
      Logger.i("IdleInhibitor", "Manual inhibition enabled");
      return;
    } else if (timeoutSec !== null && timeout === null) {
      timeout = timeoutSec;
      inhibitorTimeout.start();
      Logger.i("IdleInhibitor", "Manual inhibition enabled with timeout:", timeoutSec);
      return;
    } else if (timeoutSec !== null && timeout !== null) {
      timeout = timeoutSec;
      Logger.i("IdleInhibitor", "Manual inhibition timeout changed to:", timeoutSec);
      return;
    } else if (timeoutSec === null && timeout !== null) {
      timeout = null;
      inhibitorTimeout.stop();
      Logger.i("IdleInhibitor", "Manual inhibition timeout cleared");
      return;
    }
  }

  Timer {
    id: hyprlandPollTimer
    interval: 5000 // 5 seconds
    repeat: true
    running: CompositorService.isHyprland
    triggeredOnStart: true
    onTriggered: {
      if (!hyprlandClientsProcess.running) {
        hyprlandClientsProcess.running = true;
      }
    }
  }

  Process {
    id: hyprlandClientsProcess
    running: false
    command: ["hyprctl", "clients", "-j"]
    property string accumulatedOutput: ""

    stdout: SplitParser {
      onRead: function (line) {
        hyprlandClientsProcess.accumulatedOutput += line;
      }
    }

    onExited: function (exitCode) {
      if (exitCode !== 0 || !accumulatedOutput) {
        accumulatedOutput = "";
        return;
      }

      try {
        const clients = JSON.parse(accumulatedOutput);
        var hasInhibitor = false;
        for (var i = 0; i < clients.length; i++) {
          if (clients[i].inhibitingIdle === true) {
            hasInhibitor = true;
            break;
          }
        }

        if (hasInhibitor) {
          if (!activeInhibitors.includes("hyprland-external")) {
            addInhibitor("hyprland-external", "External application inhibiting idle");
          }
        } else {
          if (activeInhibitors.includes("hyprland-external")) {
            removeInhibitor("hyprland-external");
          }
        }
      } catch (e) {
        Logger.e("IdleInhibitor", "Failed to parse hyprctl clients JSON: " + e);
      }
      accumulatedOutput = "";
    }
  }

  // Clean up on shutdown
  Component.onDestruction: {
    stopInhibition();
  }
}
