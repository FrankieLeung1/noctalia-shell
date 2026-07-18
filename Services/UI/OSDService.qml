pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  signal showCustomOSD(string icon, string text, real value, real maxValue, string color, int duration)
  signal hideCustomOSD()

  function show(icon, text, value, maxValue, color, duration) {
    if (value === undefined || isNaN(value)) value = -1.0;
    if (maxValue === undefined || isNaN(maxValue)) maxValue = 1.0;
    if (duration === undefined || isNaN(duration)) duration = -1;
    showCustomOSD(icon || "", text || "", value, maxValue, color || "", duration);
  }

  function hide() {
    hideCustomOSD();
  }
}
