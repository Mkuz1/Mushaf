# Install Mus'haf on iPhone and iPad without a paid developer account

The iPhone app is the Flutter app in `flutter_app` (the same as on Android). Every release publishes it unsigned as
**`Mushaf-iOS.ipa`** at <https://github.com/Mkuz1/Mushaf-releases/releases/latest/download/Mushaf-iOS.ipa>; the
user-facing guide, in Arabic, English and French, is <https://www.mushafapp.com/iphone.html> (`website/iphone.html`).

Apple only runs apps signed by an Apple ID. A free Apple ID can sign apps for your own devices, with two limits:
**the app stops opening after 7 days** unless it is refreshed, and at most **3 sideloaded apps** at a time. Notes,
bookmarks and settings survive a refresh.

## SideStore (refreshes from the phone)

1. Install SideStore once, following <https://sidestore.io> (needs a Mac or PC once, for the pairing file).
2. On the iPhone, download `Mushaf-iOS.ipa` in Safari (it goes to Files).
3. SideStore ▸ **My Apps ▸ +** ▸ pick the file; sign in with your Apple ID when asked.
4. If iOS asks: **Settings ▸ Privacy & Security ▸ Developer Mode ▸ On**, and **Settings ▸ General ▸ VPN & Device
   Management** ▸ your Apple ID ▸ **Trust**.
5. Refresh in SideStore before the 7 days are up (it can do it in the background).

## AltStore or Sideloadly (from a computer)

- **AltStore** (<https://altstore.io>): the same as SideStore, but refreshes through AltServer on a Mac or PC on the
  same Wi-Fi.
- **Sideloadly** (<https://sideloadly.io>, Mac or Windows): connect the iPhone by cable, drop in the IPA, enter your
  Apple ID, **Start**. Repeat every 7 days.

## Build and run from source (Mac with Xcode)

1. Install Xcode and Flutter 3.47.7; in Xcode ▸ Settings ▸ Accounts add your Apple ID (Personal Team).
2. `cd flutter_app && flutter pub get && open ios/Runner.xcworkspace`
3. Runner target ▸ **Signing & Capabilities**: Team = your Personal Team; change the bundle identifier
   `com.kousa.mushaf` to one only yours (e.g. `com.yourname.mushaf`).
4. Connect the iPhone, turn on Developer Mode, choose it as the destination and press **Run**; trust the developer
   in **VPN & Device Management** on first launch.

## Notes

- A sideloaded app can't update itself: when it shows that a new version is available, download the new IPA and
  install it the same way (it keeps your data).
- Bookmarks, last page, language and reciter from the earlier SwiftUI iPhone app (1.7.0) are carried over on first
  launch, when installed with the same bundle identifier.
- With a paid Apple Developer account the app lasts a year, and TestFlight or the App Store become possible
  (see `APP_STORE.md`).
