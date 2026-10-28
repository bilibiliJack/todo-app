# Todo

A native to-do app for iPhone, iPad and Mac, written in SwiftUI and SwiftData. It syncs through iCloud (CloudKit) and supports Sign in with Apple.

- `App/`: the app (views, sign-in, reminders)
- `Shared/`: models, the shared store and smart lists (used by both the app and the widget)
- `Widget/`: the Today widget and its interactive "complete" button
- `Tests/`: unit tests (Swift Testing)
- `Config/`: entitlements and Info.plist files
- `RELEASE.md`: steps to publish to the App Store

Open `TodoApp.xcodeproj` in Xcode 26, choose the **TodoApp** scheme, then run on an iPhone or iPad simulator, or on **My Mac**.
