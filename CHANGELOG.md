# تغییرات راهی (RAHI)

تمام تغییرات مهم پروژه در این سند ثبت می‌شوند.

## [1.0.0] — 2026-10-03 (Release Candidate)

### افزوده‌شده
- نقشه تعاملی با flutter_map و OSM fallback / Parsimap tile
- GPS و Location Provider با مدیریت خطای دسترسی
- جستجوی مکان و Direction از طریق Neshan API
- چند مسیر پیشنهادی و انتخاب RouteType
- رابط فارسی، عربی و انگلیسی با RTL/LTR
- راهنمای صوتی مبتنی بر flutter_tts
- Turn-by-turn، maneuver steps و remaining steps
- تشخیص خروج از مسیر با threshold پنجاه متر
- grace period شش‌ثانیه‌ای و reroute فقط با تأیید کاربر
- تم روشن، تاریک و سیستم
- ذخیره تنظیمات با SharedPreferences
- MapService abstraction برای استقلال از Provider
- Release CI، signing setup و verification با apksigner
- launcher icon و native splash اختصاصی RAHI
- مستندات فارسی محصول و Release

### امنیت
- API configuration با String.fromEnvironment و --dart-define
- عدم نگهداری secret واقعی در Git
- usesCleartextTraffic=false
- Release build با minify و shrinkResources
- Production Release بدون keystore و NESHAN_API_KEY معتبر Fail می‌شود

### محدودیت‌های شناخته‌شده
- Device/Live validation هنوز کامل نشده است
- Parsimap routing تا تأیید endpoint رسمی فعال نیست
- ترافیک زنده به‌عنوان layer مستقل روی نقشه نمایش داده نمی‌شود
- حالت آفلاین کامل و Foreground Service پیاده نشده‌اند
- قابلیت‌های RahYar AI برای v2+ در Roadmap نگه‌داری می‌شوند
