# سناریوهای تست — راهی

## ۱. تست‌های خودکار موجود

### MapRoute / RouteStep

- ساخت MapRoute بدون steps
- hasSteps و حفظ steps در copyWith
- parsing ساختار مستند Neshan step
- تبدیل start_location از [lng, lat]
- turn + left
- exit rotary
- uturn
- رد step فاقد location قابل استفاده

### OffRouteDetector

| کد | سناریو | انتظار |
|---|---|---|
| UT-O-01 | نقطه روی segment | فاصله تقریباً صفر |
| UT-O-02 | نقطه عمود بر segment | فاصله نزدیک مقدار هندسی |
| UT-O-03 | قبل از ابتدای segment | فاصله تا endpoint اول |
| UT-O-04 | بعد از انتهای segment | فاصله تا endpoint آخر |

### NavigationState / Reroute

- currentStep و nextStep
- حفظ route و remaining state در copyWith
- حفظ destination در copyWith
- acceptReroute بدون destination یک no-op است

## ۲. تست‌های پیشنهادی Widget/Integration

| کد | سناریو | انتظار |
|---|---|---|
| WT-01 | Splash → Map | انتقال صحیح |
| WT-02 | Search Bar | باز شدن Bottom Sheet |
| WT-03 | زبان | تغییر fa/ar/en و RTL/LTR |
| WT-04 | Theme | light/dark/system |
| WT-05 | Settings | نمایش گزینه‌های اصلی |
| WT-06 | Reroute dialog | فقط یک Dialog همزمان |

این بخش تا زمانی که تست‌های Widget/Integration در Repo اضافه نشده‌اند، Planned است.

## ۳. Device Tests الزامی قبل از v1.0 Final

### GPS و Permission

| کد | سناریو | انتظار |
|---|---|---|
| MT-01 | اولین اجرای نصب تازه | درخواست runtime permission |
| MT-02 | Deny | null location + پیام مناسب |
| MT-03 | Allow | marker موقعیت واقعی |
| MT-04 | GPS خاموش | رفتار کنترل‌شده |

### Search / Direction با Key واقعی

| کد | سناریو | انتظار |
|---|---|---|
| MT-05 | جستجوی مقصد واقعی | نتایج معتبر |
| MT-06 | انتخاب مقصد | route واقعی |
| MT-07 | alternate routes | نمایش چند route در صورت پاسخ API |
| MT-08 | انتخاب route دوم | UI و Zoom هماهنگ |

### Navigation / TTS

| کد | سناریو | انتظار |
|---|---|---|
| MT-09 | Start | Navigation Screen |
| MT-10 | TTS فارسی | کیفیت و pronunciation قابل قبول |
| MT-11 | TTS عربی | fallback کنترل‌شده |
| MT-12 | عبور maneuver | advance در زمان درست |
| MT-13 | arrival | وضعیت arrived |
| MT-14 | long drive | بررسی battery و memory |

### Off-route / Reroute

| کد | سناریو | انتظار |
|---|---|---|
| MT-15 | بیش از 50m خروج | isOffRoute |
| MT-16 | بازگشت قبل از 6s | Timer لغو و بدون Dialog |
| MT-17 | ماندن 6s | Dialog یک‌بار |
| MT-18 | انتخاب «نه» | عدم تکرار تا ورود مجدد به route |
| MT-19 | انتخاب «بله» | Direction از current GPS تا Place destination |
| MT-20 | شکست API | توقف loading + نمایش خطا |

## ۴. Release Gate

تا زمان انجام Device Tests بالا، وضعیت پروژه باید Release Candidate تلقی شود نه v1.0 Final.

وضعیت فعلی:

- [x] flutter analyze
- [x] Unit Tests
- [x] Debug APK build
- [x] Android manifest verification در CI
- [ ] نصب و Smoke Test روی حداقل دو نسخه Android
- [ ] GPS runtime
- [ ] Neshan Live API با key واقعی
- [ ] TTS فارسی/عربی روی Device
- [ ] Road-Test Turn-by-turn
- [ ] Road-Test Off-route/Reroute
- [ ] Release signing
