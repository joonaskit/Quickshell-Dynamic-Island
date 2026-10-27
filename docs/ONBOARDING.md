# Welcome guide

What the user sees is described in the README under Welcome guide. This is how it is built.

## Files

`onboarding/` holds `OnboardingWindow`, one centred overlay window on the main screen (`ScreenService.primaryScreen`), created in `shell.qml`, and one `Onboarding*.qml` page per step. `OnboardingService` holds its state.

## When it opens

`OnboardingService` opens it on a new install, which is when `SettingsService.onboardingVersion` is below `onboardingCurrent`.

- A `settings.json` without the key counts as done, so existing users are not shown it.
- Raise `onboardingCurrent` only to show the guide to everyone again.
