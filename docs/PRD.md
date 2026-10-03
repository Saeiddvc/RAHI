# سند نیازمندی محصول (PRD) — راهی

**نام پروژه:** راهی (RAHI) — Smart Navigation  
**نسخه سند:** 1.0  
**وضعیت:** Release Candidate از نظر کد؛ Device/Live validation هنوز کامل نشده  
**زبان:** فارسی

## ۱. چشم‌انداز

راهی یک مسیریاب بومی و سه‌زبانه برای ایران است که روی تجربه روان، RTL/LTR، استقلال از Provider نقشه و رفتار قابل‌اعتماد تمرکز دارد. نسخه فعلی هسته جستجو، مسیریابی، Turn-by-turn، راهنمای صوتی، تشخیص خروج از مسیر و reroute با تأیید کاربر را در سطح کد و CI پیاده کرده است.

## ۲. کاربران هدف

- راننده شهری: جستجوی سریع مقصد، چند مسیر و ناوبری
- راننده بین‌شهری: مسیرهای بلند، اطلاعات مسیر و گام‌های باقی‌مانده
- گردشگر عرب‌زبان: رابط RTL و TTS عربی در صورت پشتیبانی موتور دستگاه
- کاربر انگلیسی‌زبان: رابط LTR و متون انگلیسی

## ۳. نیازمندی‌های عملکردی v1

| کد | نیاز | اولویت | وضعیت |
|---|---|---|---|
| FR-01 | نقشه تعاملی با flutter_map و OSM fallback / Parsimap tile | حیاتی | پیاده‌سازی شده |
| FR-02 | نمایش موقعیت زنده کاربر | حیاتی | Build-PASS؛ Device-Pending |
| FR-03 | جستجوی مکان با Neshan Search | حیاتی | Build-PASS؛ Live-Key Pending |
| FR-04 | مسیریابی با Neshan Direction | حیاتی | Build-PASS؛ Live-Key Pending |
| FR-05 | نمایش چند مسیر پیشنهادی | حیاتی | پیاده‌سازی شده |
| FR-06 | انتخاب نوع مسیر خودرو/موتورسیکلت | بالا | پیاده‌سازی شده |
| FR-07 | راهنمای صوتی fa/ar/en با flutter_tts | بالا | Build-PASS؛ Device-Pending |
| FR-08 | Turn-by-turn با maneuver steps | بالا | پیاده‌سازی شده؛ Road-Test Pending |
| FR-09 | تغییر زبان fa/ar/en | حیاتی | پیاده‌سازی شده |
| FR-10 | تم روشن/تاریک/سیستم | بالا | پیاده‌سازی شده |
| FR-11 | فاصله، زمان و انتخاب مسیر | حیاتی | پیاده‌سازی شده |
| FR-12 | ذخیره تنظیمات کاربر | متوسط | پیاده‌سازی شده |
| FR-13 | تشخیص خروج از مسیر با آستانه 50m | بالا | Unit-Test PASS؛ Road-Test Pending |
| FR-14 | Reroute فقط با تأیید کاربر | حیاتی | Unit/Build-PASS؛ Live Pending |
| FR-15 | فهرست گام‌های باقی‌مانده | متوسط | پیاده‌سازی شده |

## ۴. نیازمندی‌های غیرعملکردی

- هدف زمان راه‌اندازی: کمتر از ۳ ثانیه؛ نیازمند اندازه‌گیری Device
- هدف پشتیبانی محصول: Android 6.0 / API 23 به بالا؛ minSdk نهایی باید پیش از Release pin و Verify شود
- حجم APK debug فعلی: حدود 158 MiB
- هدف نرخ فریم: 60fps روی گوشی میان‌رده؛ نیازمند profiling
- Cleartext HTTP در Manifest غیرفعال است
- هیچ داده زنده‌ای نباید جعل شود

## ۵. خارج از محدوده v1

- لایه کامل ترافیک زنده روی نقشه
- دوربین‌ها و رخدادهای ترافیکی
- Waypoint/Trip Planner هوشمند
- حالت آفلاین کامل
- دستیار مکالمه‌ای RahYar AI
- هوش آب‌وهوا، سوخت و ایمنی
- Map Matching و Heading Smoothing پیشرفته

این موارد در ROADMAP.md نگاشت شده‌اند.

## ۶. معیارهای موفقیت فعلی

- CI روی Commitهای اصلی v1 شامل pub get، l10n، analyze، unit test، build APK و manifest verification سبز است
- APK debug در GitHub Actions تولید می‌شود
- Static analysis و Unit Tests روی آخرین baseline سبز هستند
- Device/Live validation هنوز بخشی از Release Gate نهایی است

## ۷. وابستگی‌های خارجی

| سرویس | کاربرد | وضعیت |
|---|---|---|
| Neshan API | Search، Reverse، Direction | نیازمند API Key |
| Parsimap | Reverse و Tile | نیازمند token |
| OpenStreetMap | Tile fallback | بدون کلید |
| flutter_tts | راهنمای صوتی | وابسته به TTS engine دستگاه |

## ۸. وضعیت انتشار

نسخه package در pubspec فعلاً 0.1.0+1 است. برچسب v1.0.0 تا پایان Device Testing، Signing و Release Polish نباید Final تلقی شود.
