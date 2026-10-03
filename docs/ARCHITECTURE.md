# معماری فنی — راهی

## ۱. ساختار لایه‌ها

RAHI از معماری لایه‌ای سبک استفاده می‌کند:

    lib/
    ├── core/       ثابت‌ها، تم، سرویس‌ها، ابزارها و router
    ├── data/       مدل‌ها و data sourceها
    ├── providers/  state عمومی با Riverpod
    ├── features/   featureهای UI و state اختصاصی
    └── l10n/       ARB و localization تولیدشده

## ۲. تکنولوژی‌ها

| نقش | پکیج/فریم‌ورک | نسخه فعلی Repo |
|---|---|---|
| Framework | Flutter | stable؛ آخرین baseline ثبت‌شده 3.47.6 |
| State | flutter_riverpod | 2.6.1 |
| Navigation | go_router | 14.8.1 |
| Map | flutter_map | 8.2.2 |
| Geo | latlong2 | 0.9.1 |
| GPS | geolocator | 14.1.1 |
| HTTP | dio | 5.8.0+1 |
| TTS | flutter_tts | 4.2.5 |
| Storage | shared_preferences | 2.5.5 |
| i18n | intl + flutter_localizations | intl از SDK resolution |

## ۳. استقلال Provider نقشه

MapService abstraction لایه مشترک است.

    MapService
    ├── NeshanApi
    └── ParsimapApi

قرارداد شامل search، reverse، direction، supportedRouteTypes، tileUrlTemplate و tileUrlParams است.

Parsimap در baseline فعلی routing معتبر را اعلام نمی‌کند و supportedRouteTypes آن خالی است تا route جعلی ساخته نشود.

## ۴. مدل‌های داده

| مدل | کاربرد |
|---|---|
| Place | نتیجه جستجو و مقصد |
| MapRoute | polyline، distance، duration، summary و steps |
| RouteStep | instruction، maneuver، location، duration، distance |
| ManeuverType | نوع maneuver استانداردشده در اپ |

## ۵. State Management

- settingsProvider: زبان، تم، صدا، RouteType
- locationProvider: GPS live
- locationErrorProvider: خطای location
- selectedMapProviderProvider: Provider انتخابی
- mapServiceProvider: MapService فعال
- searchProvider: جستجو
- routingProvider: route candidates و destination
- navigationProvider: Turn-by-turn، remaining، off-route و reroute state

## ۶. جریان داده Navigation

    locationProvider
       ↓
    NavigationScreen
       ↓
    NavigationNotifier.updateUserLocation()
       ├─ OffRouteDetector
       ├─ step advancement
       ├─ remaining estimate
       ├─ TTS pre-announcement
       └─ reroute offer after grace period

GPS یک منبع truth دارد: locationProvider.

## ۷. Reroute

- آستانه فاصله: 50m
- grace period: 6s با Timer واقعی
- Timer با برگشت به route لغو می‌شود
- direction جدید فقط پس از تأیید Dialog کاربر فراخوانی می‌شود
- destination واقعی Place در NavigationState نگه داشته می‌شود
- failure از طریق rerouteError به UI می‌رسد

## ۸. Neshan

- Base: https://api.neshan.org
- Search path: /v3/search
- Reverse path: /v5/reverse
- Direction path: /v4/direction
- RouteType فعال در baseline: car و motorcycle
- پارامترهای zone: avoidTrafficZone و avoidOddEvenZone
- static map رسمی به‌عنوان XYZ tile استفاده نمی‌شود؛ NeshanApi فعلاً OSM tile fallback دارد

## ۹. Parsimap

- Reverse: /geocode/reverse
- Tile: /tile/parsimap/{z}/{x}/{y}
- Direction واقعی تا تأیید endpoint رسمی geometry/polyline غیرفعال نگه داشته شده است

## ۱۰. Secrets

secrets.example.dart فقط قرارداد String.fromEnvironment را نگه می‌دارد:

- NESHAN_API_KEY
- PARSIMAP_SERVICE_TOKEN
- PARSIMAP_MAP_TOKEN

فایل lib/core/constants/secrets.dart در Git نگهداری نمی‌شود. CI template را کپی می‌کند، اما بدون secret واقعی Live API کار نخواهد کرد.

## ۱۱. CI

Workflow فعلی:

Checkout → Flutter setup → constants template → Android scaffold → manifest verification → pub get → gen-l10n → format → analyze → test → debug APK → merged manifest verification → artifact upload.

Android scaffold در CI با flutter create تولید می‌شود؛ بنابراین پیش از Release باید تنظیمات Android نهایی مانند minSdk/signing به‌صورت صریح pin شوند.
