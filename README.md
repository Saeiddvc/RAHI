# راهی | RAHI
> Smart Navigation - مسیریاب هوشمند

## معرفی
راهی یک مسیریاب هوشمند بومی است با پشتیبانی سه‌زبانه (فارسی، عربی، انگلیسی)
و تجربه‌ای مدرن بر پایه Flutter.

## قابلیت‌های نسخه ۱.۰
- نقشه تعاملی با تایل نشان و پارسی‌مپ
- مسیریابی خودرو و موتورسیکلت (نشان)
- جستجوی مکان و آدرس‌یابی معکوس
- راهنمای صوتی سه‌زبانه
- تم روشن/تاریک/سیستم
- تغییر لحظه‌ای زبان و جهت (RTL/LTR)

## پیش‌نیازها
- Flutter 3.22+
- Android Studio با SDK 34
- JDK 17

## نصب و اجرا
```bash
flutter pub get
flutter gen-l10n
flutter run
```

## ساخت APK
```bash
flutter build apk --release
```
خروجی: `build/app/outputs/flutter-apk/app-release.apk`

## ساختار پروژه
```
lib/
├── core/        → ثابت‌ها، تم، سرویس‌ها، ابزارها، روتینگ
├── data/        → مدل‌ها و منابع داده
├── providers/   → مدیریت وضعیت (Riverpod)
├── features/    → صفحه‌ها و ویجت‌ها
└── l10n/        → فایل‌های ترجمه
```

## مستندات
- [`docs/PRD.md`](docs/PRD.md) - سند نیازمندی محصول
- [`docs/UX.md`](docs/UX.md) - راهنمای تجربه کاربری
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) - معماری فنی
- [`docs/TEST_SCENARIOS.md`](docs/TEST_SCENARIOS.md) - سناریوهای تست

## مجوز
MIT
