# راهنمای Release — راهی

این سند روند ساخت APK امضاشده RAHI را توضیح می‌دهد.

## ۱. اصل امنیتی

- فایل keystore، android/key.properties و رمزها هرگز Commit نمی‌شوند.
- secrets.dart در Git است، اما فقط String.fromEnvironment دارد و هیچ مقدار حساس در آن ذخیره نمی‌شود.
- dart-define کلید را از Git دور نگه می‌دارد، اما آن را داخل APK مخفی نمی‌کند.
- Tag Release بدون keystore production و NESHAN_API_KEY معتبر باید Fail شود.
- Workflow دستی smoke از keystore موقت CI استفاده می‌کند و GitHub Release عمومی ایجاد نمی‌کند.

## ۲. ساخت keystore production

نمونه دستور:

    keytool -genkeypair -v       -storetype PKCS12       -keystore rahi-release.jks       -keyalg RSA       -keysize 2048       -validity 10000       -alias rahi-release

Keystore و رمزها باید در محل امن و دارای backup نگهداری شوند.

## ۲.۵. آماده‌سازی فونت Vazirmatn

RAHI نسخه ثابت **Vazirmatn v33.003** را با سه weight زیر داخل Git نگه می‌دارد:

- `Vazirmatn-Regular.ttf` — 400
- `Vazirmatn-Medium.ttf` — 500
- `Vazirmatn-Bold.ttf` — 700

در clone عادی نیازی به دانلود مجدد نیست. اگر فایل‌ها حذف یا خراب شدند:

    bash tools/download_fonts.sh

اسکریپت ابتدا فایل‌ها را از tag رسمی `v33.003` دانلود می‌کند و در صورت شکست، از ZIP رسمی همان Release استفاده می‌کند.

تأیید:

    ls -lh assets/fonts/Vazirmatn/

CI نیز وجود و حداقل اندازه هر سه فایل را قبل از `flutter pub get` کنترل می‌کند.

مجوز فونت SIL Open Font License 1.1 است و متن کامل آن در
`assets/fonts/Vazirmatn/OFL.txt` نگهداری می‌شود.

## ۳. تست محلی Release

1. فایل keystore را در android/app قرار دهید.
2. android/key.properties.example را به android/key.properties کپی کنید.
3. placeholderها را با اطلاعات واقعی جایگزین کنید.
4. Release build را با dart-define بسازید.

خروجی مورد انتظار:

    build/app/outputs/flutter-apk/app-release.apk

اگر key.properties وجود نداشته باشد، Gradle signing production را تنظیم نمی‌کند. برای تست قابل‌نصب Release از keystore واقعی یا Workflow smoke استفاده کنید؛ debug signing به‌عنوان production fallback استفاده نمی‌شود.

## ۴. GitHub Secrets

در Settings → Secrets and variables → Actions این مقادیر را تعریف کنید:

| Secret | کاربرد |
|---|---|
| KEYSTORE_BASE64 | محتوای Base64 keystore |
| KEYSTORE_PASSWORD | رمز keystore |
| KEY_PASSWORD | رمز alias |
| KEY_ALIAS | alias مانند rahi-release |
| NESHAN_API_KEY | Neshan API |
| PARSIMAP_SERVICE_TOKEN | Parsimap service token در صورت استفاده |
| PARSIMAP_MAP_TOKEN | Parsimap map token در صورت استفاده |

Linux:

    base64 -w 0 rahi-release.jks > rahi-release.jks.base64

macOS:

    base64 -i rahi-release.jks | tr -d '\n' > rahi-release.jks.base64

## ۵. Workflow دستی Smoke

از Actions → RAHI Release APK → Run workflow و smoke_test=true استفاده کنید.

این حالت:

- یک keystore موقت و disposable می‌سازد
- analyze/test را اجرا می‌کند
- APK release را sign می‌کند
- signature را با apksigner کنترل می‌کند
- Artifact می‌سازد
- GitHub Release عمومی ایجاد نمی‌کند
- برای انتشار واقعی مناسب نیست

## ۶. Release واقعی با Tag

پیش از Tag، Device/Live Release Gate، نسخه production در pubspec و GitHub Secrets باید آماده باشند.

سپس:

    git tag v1.0.0
    git push origin v1.0.0

Workflow روی tag، secrets production را validate می‌کند، release APK را می‌سازد، امضا و SHA-256 را کنترل می‌کند و GitHub Release می‌سازد.

## ۷. String.fromEnvironment

کلیدها در زمان Compile تزریق می‌شوند. این روش از Commit شدن secret جلوگیری می‌کند، اما secret داخل artifact قابل استخراج است. برای کلیدهای حساس، restriction سمت Provider و در صورت نیاز backend/proxy لازم است.

در Build بدون NESHAN_API_KEY، NeshanApi قبل از request خطای کنترل‌شده «کلید تنظیم نشده» می‌دهد؛ داده جعلی تولید نمی‌شود.

## ۸. چک‌لیست v1.0.0 Final

- [ ] Device smoke test
- [ ] GPS permission/runtime
- [ ] Neshan Live Search/Direction
- [ ] TTS فارسی و عربی
- [ ] Turn-by-turn road test
- [ ] Off-route/Reroute road test
- [ ] Performance/Battery sanity
- [ ] Production keystore backup
- [ ] GitHub production secrets
- [ ] pubspec version = 1.0.0+1
- [ ] Release smoke workflow PASS
- [ ] Tag v1.0.0 روی commit تأییدشده
- [ ] Production Release workflow PASS
- [ ] APK نصب و امضای آن کنترل شود
