# Welcome guide

What the user sees is described in the README under Welcome guide. This is how it is built.

## Files

`onboarding/` holds `OnboardingWindow`, one centred overlay window on the main screen (`ScreenService.primaryScreen`), created in `shell.qml`, and one `Onboarding*.qml` page per step. `OnboardingService` holds its state. `OnboardingService.pages` lists every page in the order of the window's `StackLayout`, and `steps` the ones shown: the niri page (`OnboardingNiri.qml`, see `NIRI.md`) only under niri. `pageIndex` maps a step to its page.

## When it opens

`OnboardingService` opens it on a new install, which is when `SettingsService.onboardingVersion` is below `onboardingCurrent`.

- A `settings.json` without the key counts as done, so existing users are not shown it.
- Raise `onboardingCurrent` only to show the guide to everyone again.
