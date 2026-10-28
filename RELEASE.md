# Releasing Todo to the App Store

The project builds and runs locally without a developer account: iCloud sync is off, and Sign in with Apple shows an error, so use **Continue Without an Account**. These steps turn on the real services and get the app to the App Store.

## 1. Join the Apple Developer Program
Enroll at https://developer.apple.com/programs/ ($99 per year). Approval can take 1–2 days.

## 2. Set your team and identifiers
1. Open `TodoApp.xcodeproj` in Xcode.
2. For **each target** (TodoApp, TodoWidgetExtension, TodoTests), go to *Signing & Capabilities* and pick your Team. Keep **Automatically manage signing** on.
3. If `com.wangminghai.todo` is already taken, change the bundle IDs everywhere at once. They appear in the project file, `Config/*.entitlements` and `Shared/Persistence/ModelContainer+Shared.swift`:
   - App: `com.<you>.todo`
   - Widget: `com.<you>.todo.widget`
   - iCloud container: `iCloud.com.<you>.todo`
   - App Group: `group.com.<you>.todo`

## 3. Register the capabilities
Xcode normally registers these when you pick the team. Check them at https://developer.apple.com/account/resources/identifiers:
- **App ID `com.<you>.todo`**: Sign in with Apple, iCloud (CloudKit, with the container `iCloud.com.<you>.todo`), App Groups (`group.com.<you>.todo`) and Push Notifications (used by CloudKit sync).
- **App ID `com.<you>.todo.widget`**: App Groups (the same group).

The **Debug** configuration uses `Config/TodoApp-Debug*.entitlements`, which contain only the sandbox and the App Group, so you can build without a team. Once a team is set, change the Debug entitlements to `Config/TodoApp.entitlements` (*Build Settings → Code Signing Entitlements*) so you can test iCloud and Sign in with Apple on your own devices.

## 4. Test sync on real devices
1. Run on an iPhone and a Mac that are signed in to the same Apple Account.
2. Add a task on one and wait about 10–30 seconds. It should appear on the other.
3. Open the CloudKit Console (https://icloud.developer.apple.com) and check that the `CD_TaskItem` and `CD_TaskList` record types exist in the **Development** environment.
4. **Deploy Schema Changes to Production** in the CloudKit Console. If you skip this, sync won't work in the App Store build.

## 5. Create the App Store Connect record
1. Go to https://appstoreconnect.apple.com → *Apps* → **+** → *New App*. Choose iOS and macOS, set the name to "Todo" (or another name, since it must be unique on the App Store), the primary language, and the bundle ID `com.<you>.todo`.
2. Fill in the text from `AppStore/metadata.md`: description, keywords, support URL and privacy answers.
3. Privacy: **Data Not Collected**. Tasks stay in the user's own iCloud, and the Apple ID identifier never leaves the device.
4. You need a privacy policy URL and a support URL. A simple GitHub Pages or Notion page is enough.

## 6. Screenshots
Required sizes:
- iPhone 6.9" (iPhone 17 Pro Max simulator)
- iPad 13" (iPad Pro 13-inch simulator)
- Mac (1280×800 or larger)

In the simulator, press ⌘S to save a screenshot. Use realistic sample tasks.

## 7. Archive and upload
1. In Xcode choose the destination **Any iOS Device (arm64)**, then *Product → Archive*. In the Organizer, *Distribute App → App Store Connect → Upload*.
2. Choose the destination **My Mac**, then archive and upload again. Both builds go to the same App Store Connect app because the app is multiplatform.
3. Each new upload needs a higher build number (`CURRENT_PROJECT_VERSION`).

## 8. TestFlight, then review
1. In App Store Connect → TestFlight, add yourself as an internal tester and install the build on your devices.
2. When it works, go to *App Store* → select the build → *Add for Review* → *Submit*.
3. Review notes to include: "The app can be used without an account via 'Continue Without an Account'. Sign in with Apple is optional and only personalizes the app. Tasks sync through the user's private iCloud database."

Review usually takes 1–3 days.
