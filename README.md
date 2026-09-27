# MebLap — a map app built for Lebanon's roads

MebLap is a native iPhone app (SwiftUI + MapKit, iOS 17+). It does what Google Maps does (search, directions, turn-by-turn voice navigation, live traffic) and adds features for driving in Lebanon.

## Features

### What it shares with Google Maps
- Map, hybrid and satellite views with 3D elevation and live traffic
- Search for places, streets and businesses (Apple Maps data), limited to Lebanon
- Driving directions with alternative routes, ETA, tolls shown
- Turn-by-turn navigation with voice guidance, auto-rerouting, and background guidance when the screen is locked
- Saved places (Home, Work, favorites) and recent searches
- "Nearby" search: fuel, hospitals, pharmacies, parking, ATMs, food, coffee, EV charging

### Made for Lebanon
| Feature | What it does |
|---|---|
| **Road hazard reports** | One-tap reports for potholes, flooded roads, accidents, closures, checkpoints, **traffic lights out**, **unlit roads**, road works, snow/ice, rockfalls, roadblocks/protests and fuel-station queues. Each report expires after a sensible time and can be confirmed ("Still there") or cleared. |
| **Hazard-aware routing** | Every alternative route is scored against reported hazards. A **Safest** route is offered alongside **Fastest**, and routes through closures or roadblocks are flagged in red. |
| **Hazard warnings ahead** | While navigating, MebLap announces hazards on your route (for example "Caution, flooded road reported ahead in 400 meters") and shows a banner. |
| **Mountain pass conditions** | Live weather at Dahr el Baidar, Sofar, Tarshish, Dhour El Choueir, Faraya–Mzaar, Laqlouq, Bcharre–Cedars, Cedars–Ainata and Barouk. Snow, black ice, fog and wind are turned into a Clear / Caution / Dangerous rating. |
| **Arabic & alternative spellings** | Search understands Arabic (صيدا, جونيه…) and the many English and French spellings (Saida/Sidon, Sour/Tyre, Jbeil/Byblos, Trablos/Tripoli…). |
| **Trilingual voice** | Guidance alerts in English, Arabic or French. |
| **Landmark-based locations** | Lebanese addresses work by landmark, so MebLap describes any spot as "1.2 km north-east of Jounieh". It uses this for dropped pins, hazard reports and location sharing. |
| **Emergency (SOS)** | One-tap calls to ISF 112, Red Cross 140, Civil Defense 125, Fire Brigade 175 and the MoPH hotline 1214. Share your location (landmark, coordinates, Apple and Google Maps links) by message or WhatsApp. |
| **Trip cost in LBP & USD** | Fuel cost using the weekly per-20-litre price, split between passengers, plus taxi and *service* fare estimates. All prices are editable, including the USD rate. |
| **Built-in Lebanon gazetteer** | Towns, hospitals, border crossings (Masnaa, Arida, Aboudieh, Qaa), ski resorts, historic sites, with Arabic names. |

## Getting the `.ipa`

You can't build an iOS app on Linux or Windows, so the repo includes a GitHub Actions workflow (`.github/workflows/build-ipa.yml`). It builds the app on a macOS runner every time you push:

1. Open the repo on GitHub, go to **Actions**, then open **Build iOS IPA**.
2. Open the latest successful run and download the **MebLap-ipa** artifact.
3. Unzip it to get `MebLap-unsigned.ipa`.

The IPA is **unsigned**. iPhones only install signed apps, so sign it while installing with one of these:
- **[Sideloadly](https://sideloadly.io)** or **[AltStore](https://altstore.io)**: works with a free Apple ID. The app must be re-signed every 7 days.
- **Apple Developer account** ($99/year): sign with your certificate, then install directly or through TestFlight.

## Building locally (Mac)

```bash
brew install xcodegen
xcodegen generate          # creates MebLap.xcodeproj from project.yml
open MebLap.xcodeproj      # pick your team under Signing & Capabilities, then Run
```

## Project layout

```
project.yml                  XcodeGen spec (bundle id, Info.plist keys, iOS 17 target)
MebLap/App                   App entry point
MebLap/Models                Hazards, places, Lebanon data (places, passes, emergency numbers), settings
MebLap/Services              Location, search, routing, navigation, voice, hazard store, road weather
MebLap/Views                 Map screen, navigation HUD, search, report, emergency, road conditions, trip cost, settings
scripts/make_icon.py         Regenerates the app icon
```

## Notes & next steps
- Hazard reports are stored **on the device**. To share them with every driver, connect `HazardStore` to a backend (for example Supabase or Firebase). The store is the only place that needs to change.
- Mountain-pass risk comes from weather data (Open-Meteo), not official closure notices. Always follow ISF / Traffic Management Center announcements.
- Coordinates in the built-in gazetteer are approximate.
