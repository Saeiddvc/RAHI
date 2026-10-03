# راهی | RAHI

**Smart Navigation — مسیریاب هوشمند بومی**

Repository: https://github.com/Saeiddvc/RAHI

## وضعیت نسخه

Package version فعلی: **1.0.0+1**

وضعیت محصول: **v1.0.0 Release Candidate**. Build و CI کامل‌اند، اما این موارد هنوز Device/Live-PASS نشده‌اند:

- کیفیت TTS فارسی و عربی روی دستگاه واقعی
- timing اعلان‌های صوتی در رانندگی
- رفتار GPS و reroute در رانندگی واقعی
- Neshan Live API با کلید production
- مصرف باتری و performance در سفر طولانی
- production keystore و Release عمومی

تا قبل از تکمیل این Gateها، Tag عمومی `v1.0.0` ساخته نمی‌شود.

## قابلیت‌های فعلی

- نقشه تعاملی با flutter_map
- OSM fallback و Parsimap tile/reverse در صورت token معتبر
- GPS live با geolocator
- Search و Direction نشان
- چند مسیر پیشنهادی
- RouteType خودرو و موتورسیکلت
- فارسی، عربی و انگلیسی با RTL/LTR
- light/dark/system theme
- راهنمای صوتی با flutter_tts
- maneuver steps و Turn-by-turn
- remaining steps
- Off-route detection با threshold 50m
- grace period شش‌ثانیه‌ای
- reroute فقط با تأیید کاربر
- SharedPreferences برای تنظیمات
- launcher icon و native splash اختصاصی

Build-PASS به معنی Device-PASS یا Live-API-PASS نیست.

## پیش‌نیاز توسعه

- Flutter stable
- Dart مطابق constraint پروژه: >=3.5.0 <4.0.0
- Android SDK / toolchain سازگار با Flutter
- Java/Gradle مطابق scaffold تولیدشده Flutter
- Python + Pillow فقط در صورت بازتولید source iconها

## کنترل پایه

    flutter pub get
    flutter gen-l10n
    flutter analyze
    flutter test

## بازتولید Branding

Source assetها در `assets/icon/` نگهداری می‌شوند.

    python -m pip install Pillow
    python tools/generate_icon.py
    dart run flutter_launcher_icons
    dart run flutter_native_splash:create

Debug و Release CI نیز generatorهای launcher icon و native splash را پس از ساخت Android scaffold اجرا می‌کنند.

## Secrets

`lib/core/constants/secrets.dart` در Git است، اما هیچ secret واقعی در آن قرار ندارد. مقادیر از `String.fromEnvironment` خوانده می‌شوند.

نمونه:

    flutter run --dart-define=NESHAN_API_KEY=YOUR_KEY

یا:

    flutter build apk --debug \
      --dart-define=NESHAN_API_KEY=YOUR_KEY \
      --dart-define=PARSIMAP_SERVICE_TOKEN=YOUR_SERVICE_TOKEN \
      --dart-define=PARSIMAP_MAP_TOKEN=YOUR_MAP_TOKEN

کلید واقعی نباید Commit شود. `--dart-define` کلید را از Git دور نگه می‌دارد ولی آن را داخل APK مخفی نمی‌کند.

## ساخت APK

Debug:

    flutter build apk --debug

Release production از `.github/workflows/release.yml` استفاده می‌کند و برای Tag واقعی به keystore و secrets production نیاز دارد. Smoke workflow از signing موقت CI استفاده می‌کند و GitHub Release عمومی نمی‌سازد.

## ساختار پروژه

    lib/
    ├── core/
    ├── data/
    ├── providers/
    ├── features/
    └── l10n/

    assets/icon/
    docs/
    test/
    tools/

## مستندات

- [PRD](docs/PRD.md)
- [UX](docs/UX.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Test Scenarios](docs/TEST_SCENARIOS.md)
- [Smart Features Archive](docs/SMART_FEATURES.md)
- [Principles](docs/PRINCIPLES.md)
- [Roadmap](docs/ROADMAP.md)
- [Release Guide](docs/RELEASE.md)
- [Changelog](CHANGELOG.md)

## License

MIT — see [LICENSE](LICENSE).
