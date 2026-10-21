# Renewly

Track every subscription and get reminded before you pay. A Flutter app for Android.

## Features

- Monthly and yearly spend at a glance, with separate totals for each currency.
- Subscriptions sorted by next renewal; anything due within two days is highlighted.
- Free-trial mode: a warning before the trial turns into a charge.
- Reminders on the day or 1, 2, 3 or 7 days before, at a time you choose.
- Quick add for popular services (Netflix, Spotify, ChatGPT, iCloud and more) with links to their cancel pages.
- Pause a subscription to keep it in the list without reminders.
- Works offline. No account, and data never leaves the phone.

## Code

- `lib/data/renewal.dart`: billing cycles and next-bill dates (month ends and leap years handled).
- `lib/data/database.dart`: Drift tables for subscriptions and settings.
- `lib/core/notifications.dart`: schedules reminders for the next three bills of each subscription.
- `lib/features/`: home, add/edit and settings screens.

## Build

```
dart run build_runner build
flutter test
flutter build apk --debug
```
