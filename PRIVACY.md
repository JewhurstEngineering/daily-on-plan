# Privacy Policy — Daily On Plan

Last updated: 14 August 2026

Daily On Plan (“the app”) is made by James Jewhurst / jamesware.dev. This policy describes what the app stores, what it sends, and what it does not do.

The app is a personal daily nutrition sheet. It is **not** a medical device and does not diagnose conditions, including ketosis.

## What stays on your devices

Most of what you log lives in the app on your iPhone, Apple Watch, and Mac:

- Daily plan (protein, followed-plan, ketosis self-report, meals, checklists)
- Weight, BMI inputs, body measurements, and body-composition readings you enter
- Feelings, cravings, notes, bathroom log (optional)
- Smoking and drinking counts you enter
- Saved meals, food preferences, and settings
- Optional USDA FoodData Central API key (Keychain on that device only — not iCloud, not backups)

There is no Daily On Plan account. We do not run a backend that stores your journal.

## Apple Health

On iPhone, if you allow it, the app reads and writes Apple Health data to keep the daily sheet in sync:

- **Reads:** water, alcoholic drinks, body weight, steps, sleep
- **Writes:** water, alcoholic drinks, workouts, body weight when you log them in the app

Cigarette counts stay in the app only. HealthKit has no public nicotine type.

You can revoke Health access in iPhone **Settings → Health → Data Access & Devices**.

## iCloud

If iCloud is signed in, the journal can sync through Apple’s CloudKit (`iCloud.com.dailyonplan.tracker`) across your iPhone and Mac. That data is in **your** iCloud account, not on a Daily On Plan server. Turning off iCloud for the app stops new sync. Apple’s iCloud terms apply to that copy.

## Camera and barcodes

The camera is used only to scan food-package barcodes. Frames are not uploaded to Daily On Plan. A successful scan may look up the barcode on Open Food Facts (see below).

## Network lookups (optional)

- **Open Food Facts** — public product search / barcode lookup. Your search text or barcode is sent to Open Food Facts. No API key. See [openfoodfacts.org](https://world.openfoodfacts.org/legal).
- **USDA FoodData Central** — only if you paste your own API key in Settings. Queries go to USDA. The key never leaves that device via iCloud or backup.

The app uses HTTPS. It does not use advertising SDKs, analytics SDKs, or App Tracking Transparency.

## Notifications

Reminders you enable (plan check-in, ketosis, water, and so on) are scheduled on-device. They are not sent through a Daily On Plan push server.

## What we do not collect

- No sign-in, email, or customer account
- No advertising ID, fingerprinting, or third-party ads
- No sale of personal data
- No sharing of your journal with other users

## Children

The app is not directed at children under 13. It can log alcohol and smoking if you turn those sections on.

## Your choices

- Delete the app to remove on-device data (use Backup first if you want a copy).
- Restore from an in-app backup you exported.
- Revoke Health, camera, notification, and iCloud access in system Settings.

## Contact

Questions about this policy: **jamesware.dev** (James Jewhurst).
