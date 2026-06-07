# Cats & Dogs (iOS)

iOS port of the [Android Cats & Dogs weather app](https://github.com/tuckercr/cats-dogs).

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

## CI

GitHub Actions runs on every push and pull request to `main` (see [`.github/workflows/ios.yml`](.github/workflows/ios.yml)).

The workflow builds the app, runs unit tests on an iOS Simulator, and uploads the `.xcresult` bundle if you need to inspect failures.

Add the same OpenWeather API key used for Android as a repository secret:

1. GitHub repo → **Settings** → **Secrets and variables** → **Actions**
2. Create secret **`OWM_API_KEY`** with your key

At build time the workflow writes that value into `Secrets.plist` (the file stays gitignored locally).

## Tests

Unit tests live in the `Cats&DogsTests` target (XCTest). Run them in Xcode with **⌘U**, or from the Test navigator.

Ported from Android:

- `ForecastAggregatorTests` — noon slot selection and multi-day grouping
- `OpenWeatherParsingTests` — JSON decoding for API responses
- `WeatherUnitsTests` — imperial vs metric by region
- `WeatherRepositoryTests` — repository mapping and error handling (fake API)
- `GeocodingRepositoryTests` — suggestion formatting and validation (fake API)

## App flow

Same as the Android app:

1. Welcome screen (auto-dismisses after 5 seconds, or tap **Get started**)
2. City search with geocoding suggestions
3. Current weather (temperature, feels like, humidity, wind)
4. Multi-day forecast (one row per day, sample closest to local noon)
