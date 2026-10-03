# راهی | RAHI

**Smart Navigation — مسیریاب هوشمند بومی**

Repository: https://github.com/Saeiddvc/RAHI

## وضعیت

RAHI در وضعیت v1.0.0 Release Candidate از نظر کد قرار دارد. نسخه package فعلی در pubspec برابر 0.1.0+1 است و تا پایان Device Testing، Signing و Commit نهایی Release به 1.0.0+1 ارتقا داده نمی‌شود.

CI فعلی روی branchهای v1-commit-* شامل analyze، unit test، debug APK build و manifest verification است.

## قابلیت‌های فعلی

- نقشه تعاملی با flutter_map
- OSM fallback برای tile
- Parsimap tile/reverse در صورت token معتبر
- GPS live با geolocator
- Search و Direction نشان
- چند مسیر پیشنهادی
- RouteType خودرو و موتورسیکلت
- سه زبان فارسی، عربی و انگلیسی
- RTL/LTR
- light/dark/system theme
- راهنمای صوتی با flutter_tts
- maneuver steps و Turn-by-turn
- remaining steps
- Off-route detection با threshold 50m
- grace period شش‌ثانیه‌ای
- Reroute فقط با تأیید کاربر
- SharedPreferences برای تنظیمات

## مواردی که هنوز Final-PASS نیستند

- Neshan Live API با key واقعی
- GPS runtime روی Device
- TTS فارسی/عربی روی Device
- Road-Test Turn-by-turn
- Road-Test Off-route/Reroute
- Performance/Battery
- Release signing

Build-PASS به معنی Device-PASS یا Live-API-PASS نیست.

## پیش‌نیاز توسعه

- Flutter stable
- Dart مطابق constraint پروژه: >=3.5.0 <4.0.0
- Android SDK / toolchain سازگار با Flutter stable
- Java/Gradle مطابق scaffold تولیدشده Flutter

پیش از Release، نسخه‌های Android SDK و minSdk باید به‌صورت صریح pin شوند.

## نصب dependencyها

    flutter pub get
    flutter gen-l10n
    flutter analyze
    flutter test

## Secrets

ابتدا template را کپی کنید:

    cp secrets.example.dart lib/core/constants/secrets.dart

مقادیر از String.fromEnvironment خوانده می‌شوند. نمونه build با Neshan:

    flutter build apk --debug --dart-define=NESHAN_API_KEY=YOUR_KEY

برای Parsimap در صورت نیاز:

    --dart-define=PARSIMAP_SERVICE_TOKEN=YOUR_SERVICE_TOKEN
    --dart-define=PARSIMAP_MAP_TOKEN=YOUR_MAP_TOKEN

کلید واقعی نباید Commit شود.

## اجرای محلی

    flutter run --dart-define=NESHAN_API_KEY=YOUR_KEY

## ساخت APK

Debug:

    flutter build apk --debug

Release فعلاً بخشی از Commit 14 است و تا تنظیم signing نباید خروجی production تلقی شود.

## ساختار پروژه

    lib/
    ├── core/
    │   ├── constants/
    │   ├── router/
    │   ├── services/
    │   ├── theme/
    │   └── utils/
    ├── data/
    │   ├── datasources/
    │   └── models/
    ├── providers/
    ├── features/
    │   ├── map/
    │   ├── navigation/
    │   ├── settings/
    │   └── splash/
    └── l10n/

## مستندات

- [PRD](docs/PRD.md)
- [UX](docs/UX.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Test Scenarios](docs/TEST_SCENARIOS.md)
- [Smart Features Archive](docs/SMART_FEATURES.md)
- [Principles](docs/PRINCIPLES.md)
- [Roadmap](docs/ROADMAP.md)

## آرشیو ۸۰ قابلیت

SMART_FEATURES.md آرشیو رسمی قابلیت‌های RahYar AI / Driver Copilot برای نقشه راه آینده RAHI است. این آرشیو نباید به‌اشتباه به معنی پیاده‌سازی همه ۸۰ قابلیت در v1 تلقی شود.

## License

MIT
