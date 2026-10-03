# نقشه راه پروژه راهی

## وضعیت نسخه‌ها

| نسخه | وضعیت | تمرکز |
|---|---|---|
| v1.0.0 RC | کد هسته آماده؛ Device/Live Pending | Navigation core + سه‌زبانه |
| v1.5 | برنامه | Device testing، performance و polish |
| v2.0 | آینده | جستجو و route intelligence |
| v2.5 | آینده | Smart reroute + Trip Planner |
| v3.0 | آینده | RahYar AI / Driver Copilot |
| v3.5 | آینده | آب‌وهوا، سوخت و ایمنی |
| v4.0 | آینده | یادگیری و شخصی‌سازی |
| v4.5 | آینده | زبان محلی، Voice-First و Smart Brief |
| v5.0 | آینده | Verification و Confidence layer کامل |

## نگاشت آرشیو ۸۰ قابلیت

| نسخه | قابلیت‌ها |
|---|---|
| v1 foundation | ۳۰، ۳۱، ۷۴، ۷۵، ۷۹ در سطح foundation |
| v2.0 | ۹–۲۵ |
| v2.5 | ۲۶–۴۲ |
| v3.0 | ۱–۸ |
| v3.5 | ۴۳–۵۸ |
| v4.0 | ۵۹–۶۶ |
| v4.5 | ۶۷–۷۳ |
| v5.0 | ۷۶–۷۸ و ۸۰ |

## تاریخچه Commitهای v1

| # | عنوان | وضعیت |
|---|---|---|
| 1 | project skeleton | انجام شده |
| 2 | core layer + models | انجام شده |
| 3 | map service layer | انجام شده |
| 4 | providers layer | انجام شده |
| 5 | l10n fa/ar/en | انجام شده |
| 6 | UI splash/map/settings | انجام شده |
| 7 | Android manifest + permissions | انجام شده |
| 8 | search + multi-route | انجام شده |
| 9 | maneuver steps | انجام شده |
| 10 | voice + turn-by-turn | انجام شده |
| 11 | off-route + remaining steps | انجام شده |
| 12 | reroute with confirmation | انجام شده |
| 13 | documentation | این Commit |
| 14 | release CI + signing setup | آینده |
| 15 | polish + version + release tag | آینده |

## Release Gate پیش از v1.0.0 Final

1. Device smoke روی حداقل دو نسخه Android
2. GPS permission/runtime
3. Neshan Search/Direction با key واقعی
4. TTS فارسی/عربی
5. Road-Test Turn-by-turn
6. Off-route + reroute واقعی
7. battery/performance sanity
8. release signing
9. pubspec version → 1.0.0+1
10. Git tag v1.0.0
