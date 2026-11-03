# Good News!

A standalone iPhone app + home-screen widget that reads like a newspaper: serif headlines, masthead, thin rules, cream and dark editions, INDIA | GLOBAL pages. Free RSS only; headlines open the original articles.

- App: SwiftUI, iOS 17+
- Widget: WidgetKit, systemSmall / systemMedium / systemLarge, interactive India/Global tab buttons (iOS 17+ AppIntents), 15-minute timeline refresh
- Feeds: The Hindu, TOI, NDTV, Indian Express (India); BBC, Al Jazeera, Guardian, NPR (Global)
- Tests: RSS parsing/empty/dedupe criteria with synthetic fixtures F1-F10 (GoodNewsTests)
- CI: GitHub Actions macos runner - tests, simulator build, preview screenshots (artifact `previews`), optional signed TestFlight upload via ASC API key secrets
