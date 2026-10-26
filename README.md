# Sunny & Misty (iOS)

![iOS CI](https://github.com/tuckercr/cats-dogs-iOS/actions/workflows/ios.yml/badge.svg)

Native SwiftUI port of the [Android Sunny & Misty app](https://github.com/tuckercr/cats-dogs).
Features generally land on Android first and iOS catches up — see [Feature parity](#feature-parity-with-android).

Save multiple cities (or use your current location) and see current conditions with Sunny the dog and Misty the cat
acting out the weather, the best time to walk the dog, an hourly and 7-day forecast, an animated
precipitation radar, and optional daily weather notifications.

## Screenshots

| Pets, walk time & hourly | Radar & rest of week | Day detail | Settings & units |
|---|---|---|---|
| ![Sunny and Misty react to the weather, with best walk time and the hourly strip](./screenshots/current.png) | ![Animated RainViewer radar and the rest of the week](./screenshots/forecast.png) | ![Hour-by-hour detail for a day](./screenshots/day.png) | ![Settings with unit selection](./screenshots/settings.png) |

On iPad and in landscape, the pets sit beside today's details and the week splits into two columns:

![iPad layout with the pets beside today's details](./screenshots/tablet.png)

## How to run

1. Get a free API key from [OpenWeatherMap](https://openweathermap.org/api).
2. Copy the secrets template:

   ```bash
   cp "Cats&Dogs/Secrets.example.plist" "Cats&Dogs/Secrets.plist"
   ```

3. Edit `Cats&Dogs/Secrets.plist` and replace `your_key_here` with your key.
4. Open `Cats&Dogs.xcodeproj` in Xcode and run on a simulator or device.

New API keys can take up to two hours to activate.

`Secrets.plist` is gitignored so your key is never committed.

Firebase is optional. Without `GoogleService-Info.plist` the app builds and runs normally, with
analytics off and Remote Config on its built-in defaults. See [Firebase](#firebase).

Requires **iOS 17+**.

The app is called **Sunny & Misty** ("Sunny & Misty: Pet Weather" on the App Store). The Xcode project, target,
scheme and bundle ID (`com.tuckercr.Cats-Dogs`) keep the original Cats&Dogs name on purpose.

## App flow

1. **Splash** — a brief splash screen with the mascot.
2. **Welcome** — first launch only; tap **Get started**.
3. **Notification onboarding** — opt in to daily weather updates, or **Not now**.
4. **Location onboarding** — use the device location, or **Enter a city manually**.
5. **Current weather** — the main screen for the active city:
   - Hero card: Sunny and Misty act out one of 8 weather moods (sunny, cloudy, rain, storm, snow, hot,
     cold, night) on a mood-coloured card, with the city, temperature, min/max and a daily caption in
     the pets' voice. Tap it for today's hourly detail. The art is drawn in code as a placeholder,
     isolated in `PetScene`.
   - **Best walk time**: Great, Okay, Stay in, Paws hot or Too cold, with the first good window
     between 7 AM and 8 PM in the next 24 hours, shown as "Tomorrow around 7 AM" when it falls on the
     next day in the city's time zone. Hot pavement (estimated 52 °C / 125 °F) counts as paws hot
     even on a mild day. Hours that have already passed are dropped when the screen is drawn, so an
     older cached forecast never suggests a time in the past.
   - **Hourly**: the next 24 hours, with rain chance. Cities without coordinates fall back to
     OpenWeatherMap, which is 3-hourly, so the strip spans three days for them.
   - **Today**: feels like, humidity, wind, visibility, cloud cover, UV index (daytime only),
     sunrise and sunset.
   - **Radar**: RainViewer's recent radar frames animated over an OpenStreetMap base map, with the
     frame time, a Light→Heavy legend, play/pause and a scrubber. A caption under the map credits
     OpenStreetMap and RainViewer. Frames are refetched once they are 10 minutes old (checked every
     minute while the radar is on screen, and on returning to the app), with the old frames kept up
     until the new ones arrive.
   - **Rest of week**: one row per day (sample closest to local noon) with rain chance; tap a row
     for hourly detail.
   - All times — hours, days, sunrise/sunset, radar frames and "today" — are in the city's own time
     zone, not the device's.
   - On landscape phones and iPad the pets and walk card sit beside today's details, and the week
     splits into two columns.
   - City tabs appear under the title once two or more cities are saved.
   - Pull to refresh. Data also refreshes silently whenever the app returns to the foreground
     (unless `foreground_refresh_min_minutes` says that city was fetched recently), and periodically
     in the background.
   - The walk card and the radar can each be switched off from Remote Config.
6. **Add city** (＋) — search with geocoding suggestions; choosing a suggestion pins exact coordinates.
   A name added without choosing a suggestion appears straight away and is geocoded in the background.
7. **Settings** (gear):
   - Units: system, metric, or imperial
   - Location and notification permission status. A permission that was never requested is requested
     in-app (iOS has no Settings entry for it yet); a denied one links to the iOS Settings app.
     Granting location here adds your current location as a city.
   - Manage locations: add, set active, reorder, delete
   - Clear cached weather
   - Privacy: **Share usage statistics** turns analytics on or off. It starts on, except in the EU,
     EEA, UK and Switzerland, where it starts off until the user turns it on
   - OpenWeather and Open-Meteo attribution, and [privacy policy](https://fangjet.com/weather)

### Where the data comes from

| Data | Source |
|---|---|
| Current conditions, city search | OpenWeatherMap (needs the API key) |
| Forecast for cities with coordinates | [Open-Meteo](https://open-meteo.com): true hourly data, UV index, and solar radiation for the pavement estimate. Free, no key. |
| Forecast for name-only cities | OpenWeatherMap's 3-hourly `/forecast`, as a fallback |
| Radar | [RainViewer](https://www.rainviewer.com/api.html) frames (free, no key) at zoom 7, the highest it serves |
| Base map | OpenStreetMap tiles |

Open-Meteo's weather codes are mapped onto OpenWeatherMap-style conditions and icons, so icons and
pet moods work the same for both sources.

### Caching and errors

The last successful current weather and forecast are cached per city in `UserDefaults`. Cached data
is shown immediately while a refresh runs, and is kept on screen if the refresh fails. Errors only
surface when there is nothing cached, with **Retry** where retrying can help (offline, rate limited,
server error) and without it where it cannot (bad API key, city not found).

### Background refresh and notifications

If allowed, the app schedules local notifications at **9 AM, 1 PM and 7 PM** for the active city.

Android runs a periodic `WeatherUpdateWorker` plus a `WeatherNotificationWorker` at each of those
hours. iOS cannot run code at a fixed time of day, so `WeatherBackgroundRefresher` does both jobs in
a single `BGAppRefreshTask`. Each time iOS grants background time it:

1. fetches current weather and the forecast for the active city,
2. writes them to the per-city cache, so the app opens with fresh data,
3. rewrites the three pending notifications with the fresh text, and
4. requests the next run after `weather_refresh_interval_minutes` (default 30, as on Android), or 15
   minutes after a failed fetch.

The notifications themselves stay on calendar triggers, so they always arrive on time; their text is
as fresh as the most recent background run. They are also rewritten whenever the app itself loads
new data. The fetch-then-notify decision logic is `NotificationWorkerLogic`, a direct port of the
Android class with the same tests.

> **iOS decides when background refresh runs.** The interval is a minimum, not a schedule: iOS
> learns from how often the app is opened, and runs nothing if the user force-quits the app or turns
> off *Background App Refresh*. Expect fresher notifications for regular users than for occasional ones.

Background tasks never fire on the simulator. To trigger one on a device, run from Xcode, send the
app to the background, pause in the debugger and enter:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.tuckercr.Cats-Dogs.refresh"]
```

The task identifier and the `fetch` background mode are declared in [`Cats&Dogs/Info.plist`](Cats&Dogs/Info.plist),
which Xcode merges with the generated Info.plist.

## Architecture

| Layer | Choice |
|---|---|
| UI | SwiftUI, `NavigationStack` |
| State | `@Observable` view models on the main actor |
| Networking | `URLSession` + `Codable` behind `OpenWeatherAPI`, `OpenMeteoAPI` and `GeocodingAPI` protocols, plus an injectable RainViewer fetch (all faked in tests) |
| Persistence | `UserDefaults` via `PreferencesStore` — onboarding flags, saved cities, unit override, weather cache |
| Location | Core Location (when-in-use) |
| Notifications | `UserNotifications` local calendar triggers |
| Background work | `BackgroundTasks` (`BGAppRefreshTask`) via SwiftUI `.backgroundTask` |
| APIs | OpenWeatherMap `/weather`, `/forecast` and Geocoding (free tier); Open-Meteo; RainViewer; OpenStreetMap tiles |
| Fonts | Baloo 2 for display and title text (SIL OFL, licence bundled) |
| Analytics and config | Firebase Analytics (`FirebaseAnalyticsCore`) and Remote Config via Swift Package Manager, both optional |
| Dependencies | Firebase iOS SDK 12.x; everything else is Apple frameworks |

```
Cats&Dogs/
  Config/      API key loading
  Data/        Repositories, PreferencesStore, Remote Config
  Domain/      Units and unit override
  Models/      Weather and radar models, SavedLocation, CitySuggestion, LoadingState
  Services/    API clients, DTOs, forecast aggregation, notifications, background refresh, analytics,
               Firebase setup
  Resources/   Fonts
  Utilities/   Formatting, error messages, brand fonts and colours
  ViewModels/
  Views/       Screens; Pets/ holds the pet scene, moods, walk advice and their thresholds
```

## Feature parity with Android

| Feature | Android | iOS |
|---|---|---|
| Welcome, notification and location onboarding | ✅ | ✅ |
| Multiple saved cities, tabs, current location | ✅ | ✅ |
| City search with geocoding suggestions | ✅ | ✅ |
| Current conditions incl. sunrise / sunset and UV | ✅ | ✅ |
| Pet hero (8 weather moods, daily caption) | ✅ | ✅ |
| Best walk time card, incl. pavement heat | ✅ | ✅ |
| Walk card skips past hours, says "Tomorrow around…", looks 24 hours ahead | ✅ | ✅ |
| Hourly strip and rain chance | ✅ | ✅ |
| Open-Meteo forecast for cities with coordinates | ✅ | ✅ |
| All times in the city's own time zone | ✅ | ✅ |
| Rest of week + day detail sheet | ✅ | ✅ |
| Animated RainViewer radar | ✅ speed from Remote Config | ✅ speed from Remote Config |
| Radar refreshes frames older than 10 minutes | ✅ | ✅ |
| OpenStreetMap and RainViewer credit under the map | ✅ | ✅ |
| Wide layout for landscape and tablets | ✅ | ✅ |
| Branding: brand blue, gold accent, Baloo 2, themed icon | ✅ | ✅ tinted icon on iOS 18+ |
| Per-city cache, silent refresh on foreground | ✅ | ✅ |
| Settings: units, permissions, clear cache, about, privacy policy | ✅ | ✅ |
| Manage locations: set active, reorder, delete | ✅ | ✅ |
| Daily notifications at 9 / 13 / 19 | ✅ fetched at send time | ✅ text from the latest background refresh |
| Periodic background weather refresh | ✅ WorkManager, every 30 min (Remote Config) | ✅ `BGAppRefreshTask`, no sooner than the Remote Config interval |
| Follows the OS temperature-unit preference | ✅ Android 14+ | ⚠️ region-based only |
| Firebase Analytics, with kill switch and user opt-out | ✅ optional, opt-out in Settings → About | ✅ optional, opt-out in Settings → Privacy |
| Firebase Remote Config (same 17 keys) | ✅ optional | ✅ optional |
| Crashlytics | ✅ optional, release builds only | ❌ Xcode Organizer crash reports instead |
| View-model unit tests | ✅ | ✅ |
| UI tests in CI | ✅ Compose UI tests | ❌ |
| Release minification | ✅ R8 | n/a |

## Tests

Unit tests live in the `Cats&DogsTests` target (XCTest): 213 tests in 22 classes. Run them in Xcode
with **⌘U**, or from the Test navigator.

Ported from Android:

- `ForecastAggregatorTests` — noon slot selection, multi-day grouping, rain chance, local hour, UV
- `OpenWeatherParsingTests` — JSON decoding for API responses, including UTC offsets and rain chance
- `WeatherUnitsTests` — imperial vs metric by region, Celsius conversion
- `WeatherRepositoryTests` — repository mapping and error handling (fake API), Open-Meteo switched off by Remote Config
- `GeocodingRepositoryTests` — suggestion formatting and validation (fake API)
- `NotificationWorkerLogicTests` — notification content, permission and retry behaviour, "today" in the city's time zone, the Remote Config switch
- `OpenMeteoForecastTests` — hour filtering, city time zones (including half-hour zones and DST), WMO codes, UV, pavement heat
- `RadarTests` — RainViewer timeline parsing, tile URLs, load-once and retry, refreshing a stale timeline while the old one stays on screen
- `PetMoodTests`, `WalkAdvisorTests` (both in `PetTests.swift`) — mood mapping, walk ratings including night hours and pavement heat, Remote Config thresholds, today vs tomorrow in the city's time zone, the 24-hour cap, dropping past hours
- `CityListViewModelTests` — loading and legacy migration, add (with geocoding and de-duplication), remove, set active, reorder
- `WeatherForecastViewModelTests` — request routing, cache-first display, error mapping, silent background refresh, the foreground-refresh window, analytics events, and races between overlapping requests
- `GeoLocationViewModelTests` — debounced search, latest-input-wins, suggestion pinning, reset
- `LocationPermissionViewModelTests` — denied, located and failed states
- `SettingsViewModelTests` — unit override persistence, clear cache, permission requests, usage-sharing opt-out
- `WelcomeViewModelTests` — onboarding flags, including installs that predate the notification step, and the onboarding-complete event
- `AnalyticsRepositoryTests` — the three analytics gates and pushing the opt-out into the SDK
- `PetWeatherThresholdsTests` — walk and pet threshold ranges and pair checks

iOS only:

- `WeatherBackgroundRefresherTests` — background refresh caching, notification rescheduling and retry timing
- `PreferencesStoreTests` — per-city cache round trip, eviction when a city is removed, older cache format
- `WeatherFormattingTests` — sunrise/sunset in the city's time zone, UV categories
- `RemoteConfigRepositoryTests` — defaults, the refresh-interval floor, radar-speed and foreground-refresh limits

View-model tests run against real repositories with scripted API fakes, and a `PreferencesStore` backed
by a throwaway `UserDefaults` suite, so they never touch the app's real data. Shared helpers (including
`Gate`, which holds fake requests open so tests can control the order responses arrive in) live in
`ViewModelTestSupport.swift`.

## CI

GitHub Actions runs on every push and pull request to `main` (see [`.github/workflows/ios.yml`](.github/workflows/ios.yml)).

The workflow builds the app with Xcode 16.4, runs the unit tests on an iOS 18 simulator, and uploads
the `.xcresult` bundle as an artifact for inspecting failures.

The app targets **iOS 17+** so unit tests can run on the simulator runtimes preinstalled on GitHub-hosted Mac runners.

Xcode 16.4's Swift 6.1 compiler crashes on closure default arguments that are main-actor isolated
or read main-actor state. Initializers therefore take optional closures (`fetch: (() -> T)? = nil`)
and fill in the default in the body; keep to that pattern so CI keeps building.

Add the same OpenWeather API key used for Android as a repository secret:

1. GitHub repo → **Settings** → **Secrets and variables** → **Actions**
2. Create secret **`OWM_API_KEY`** with your key

At build time the workflow writes that value into `Secrets.plist` (the file stays gitignored locally).

Optionally add **`GOOGLE_SERVICE_INFO_PLIST`**, the base64 of `GoogleService-Info.plist`
(`base64 -i "Cats&Dogs/GoogleService-Info.plist" | pbcopy`), to build CI with Firebase included.
Without it CI builds with Firebase switched off. Unit tests never start Firebase either way.

## Firebase

Both apps share the Firebase project **`cats-dogs-weather`**, with Google Analytics
linked. The iOS app is registered as `com.tuckercr.Cats-Dogs`.

To build with Firebase, download `GoogleService-Info.plist` for the iOS app (Firebase console →
Project settings → Your apps, or `firebase apps:sdkconfig IOS <app id> --project cats-dogs-weather`)
and put it in `Cats&Dogs/`. It is git-ignored; the synchronized folder picks it up with no project
change. Without it, Firebase is never started.

Remote Config parameters are defined and deployed from the Android repo
(`firebase/remoteconfig.template.json`), so both platforms read the same values:

| Key | Default | Used for |
|---|---|---|
| `weather_refresh_interval_minutes` | 30 (minimum 15) | Earliest next background refresh |
| `radar_frame_interval_ms` | 850 (100–5000, otherwise the default) | Radar animation speed |
| `analytics_enabled` | true | Kill switch for every analytics event, and SDK collection |
| `radar_enabled` | true | Hides the radar card if RainViewer or the OpenStreetMap tiles become unavailable |
| `walk_card_enabled` | true | Hides the "time to walk the dog" card |
| `daily_weather_notifications_enabled` | true | Only the daily 9 / 13 / 19 weather summaries; off removes the pending ones. Future notification types get their own switches |
| `foreground_refresh_min_minutes` | 0 (0–1440) | Skips the silent refresh on returning to the app if that city was fetched this recently. Pull-to-refresh and city changes are never skipped |
| `walk_hot_pavement_c` | 52 (40–70) | Pavement temperature that triggers the hot-paws warning |
| `walk_max_rain_chance` | 30 (0–100) | Rain chance at or above which an hour isn't suggested for a walk |
| `walk_comfort_min_c` / `walk_comfort_max_c` | 3 (−20–20) / 27 (15–40) | Comfortable walking temperatures |
| `walk_hours_start` / `walk_hours_end` | 7 / 20 (0–23) | Local hours walks are suggested in, inclusive |
| `pet_hot_threshold_c` / `pet_cold_threshold_c` | 30 (20–45) / 0 (−20–10) | Switch the pets to their hot and cold moods, and the walk card to "paws hot" and "too cold" |
| `open_meteo_enabled` | true | Off sends forecasts for cities with coordinates to OpenWeatherMap (3-hourly) instead of Open-Meteo |
| `openweather_api_key` | "" | Replacement OpenWeather API key, used from the next launch; empty uses the key built into the app. Lets a leaked key be rotated without an update. Not secret: Remote Config values reach every device |

Walk and pet temperatures are Celsius whatever units the user picked. An out-of-range value falls
back to its default, and if a pair ends up inverted (minimum not below maximum), both fall back to
their defaults.

A missing or unreadable value always falls back to the default, so a console mistake can't break the
app. New values are fetched at most hourly; most apply on the next read, the analytics SDK switch on
the next launch.

### Analytics

The events and parameters match Android, so both platforms report into the same dashboards:

| Event | Parameters | When |
|---|---|---|
| `onboarding_complete` | — | The last onboarding step (location) finished or was skipped |
| `city_added` | — | A new city was saved (re-adding an existing one doesn't count) |
| `settings_opened` | — | Settings opened from the gear |
| `weather_error` | `error_key` (e.g. `offline`, `city_not_found`) | A current-weather or forecast fetch failed, even if cached data hid the error |

An event is sent only when all three gates are open:

1. Firebase is configured.
2. The Remote Config kill switch `analytics_enabled` is on.
3. **Settings → Privacy → Share usage statistics** is on. It starts on, except in the EU, EEA, UK
   and Switzerland (by the device's region), where analytics need opt-in consent, so it starts off
   until the user turns it on. Changing it isn't tracked, and clearing the cache keeps the choice.

`FIREBASE_ANALYTICS_COLLECTION_ENABLED` is false in `Info.plist`, so Firebase collects nothing until
the app has applied that choice at launch.

Gates 2 and 3 are also enforced in the SDK with `setAnalyticsCollectionEnabled`, so Firebase's
automatic events (sessions, screen views) stop too.

The app links `FirebaseAnalyticsCore`, so no advertising identifier or ads SDK is included, and
`GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS` is off. Firebase ships its own privacy
manifests; see [App Store](#app-store) for the app's own.

Firebase 13 needs Xcode 26.1 (Swift 6.2.1). The project stays on 12.x until CI moves off Xcode 16.4.

## App Store

- [`docs/app-store/listing.md`](docs/app-store/listing.md) is the draft App Store Connect listing:
  name, subtitle, description, keywords and the rest.
- [`screenshots/app-store/`](screenshots/app-store/) holds the 6.9-inch iPhone screenshots
  (1320 × 2868), numbered 01 to 06, and the 13-inch iPad ones (2064 × 2752), `ipad-01` and
  `ipad-02`. App Store Connect requires iPad screenshots because the app runs on iPad.
- Release builds fail if `Cats&Dogs/Secrets.plist` is missing or has no OpenWeather key (the "Check
  OpenWeather API key" build phase), so an archive can't ship without one. Debug builds skip the
  check. Radar map tiles are requested with a `SunnyAndMisty/<version>` User-Agent and cached on
  disk, as OpenStreetMap's tile policy asks.
- [`Cats&Dogs/PrivacyInfo.xcprivacy`](Cats&Dogs/PrivacyInfo.xcprivacy) is the privacy manifest: no
  tracking or tracking domains, product interaction data for analytics and precise location for
  app functionality (neither linked to the user), and `UserDefaults` as the only required-reason API.
  The App Store privacy answers in `listing.md` cover this plus what the Firebase SDK collects itself
  (coarse location and a per-install ID, for analytics).
- `ITSAppUsesNonExemptEncryption` is false in `Info.plist`, so uploads skip the export-compliance
  question.
- The app icons have no alpha channel, which App Store Connect requires.
- The privacy policy is at [fangjet.com/weather](https://fangjet.com/weather), linked from Settings.

## Credits

Weather data by [OpenWeather](https://openweathermap.org/) and [Open-Meteo.com](https://open-meteo.com)
(CC BY 4.0). Radar by [RainViewer](https://www.rainviewer.com). Base map ©
[OpenStreetMap](https://www.openstreetmap.org/copyright) contributors. [Baloo 2](https://github.com/EkType/Baloo2)
by Ek Type, under the SIL Open Font License.
