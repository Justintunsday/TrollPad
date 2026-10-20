# TrollPad

This branch builds on TrollPad for vertical split layout research. See
[development status and device evidence checklist](docs/VERTICAL_SPLIT_STATUS_ZH.md).
The added vertical diagnostics are opt-in; vertical two-app resizing is not yet verified.
Troll SpringBoard into thinking it's running on iPadOS

## Features
- Grid app switcher
- Multitasking button
- Floating dock
  + Recent apps
  + App Library
- Split View
- Slide Over
- Stage Manager
  + Requires iOS 16 or later
  + External display supports AirPlay too!
- Floating keyboard
  + Only works on ios 16 or later for now

### Enabling Stage Manager
> [!WARNING]
> It is recommended to enable Stage Manager using Control Center module only, so that there will be no risk of bootloop.
- Add Stage Manager toggle to Control Center

For external display, the behavior is same as on iPadOS: plug and play.

## Side effects
- In multitasking modes in landscape, left and right are affected by safe area layout margins. This issue doesn't happen in external display.
