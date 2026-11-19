# Testing distribution workflow templates

These are inactive examples. Copy the desired `.yml` file into `.github/workflows/`
to activate it. Both workflows run manually through **Actions → Run workflow**, only
on `main`. Each validates the selected revision before signing and uploading.
They do not run on pull requests or replace the `Flutter CI required` merge check.
No upload happens merely by adding these templates to the repository.

## Before activation

1. Resolve the Flutter version mismatch. The templates default to the requested
   **3.44.5**, but this project currently requires Dart **^3.13.7** and was tested
   with Flutter **3.47.9**. Set the environment variable `FLUTTER_VERSION` to a
   verified compatible version and align the project, AGENTS.md, and regular CI.
2. Choose permanent application identifiers. Android currently uses
   `com.example.continous_int_dev`; iOS uses `com.example.continousIntDev`.
   Register matching applications in Firebase and App Store Connect. The Android
   workflow uses the application ID in Gradle; the iOS template configures Runner's
   bundle ID and team on its temporary CI checkout.
3. Create GitHub environments named `firebase-testing` and `testflight` under
   **Settings → Environments**. Allow deployments only from `main`.
   Add variables and secrets to the matching environment. Secret values belong
   in GitHub settings, never in YAML, the repository, or chat.
4. Use new, increasing positive build numbers. Reusing an Apple build number
   for the same app version fails; use a new number for retries after upload.
   App version names come from `pubspec.yaml`.

## Firebase: Android APK distribution

Environment: `firebase-testing`.

| Kind | Name | Value |
| --- | --- | --- |
| Variable | `FLUTTER_VERSION` | Verified Flutter version; default `3.44.5` |
| Variable | `FIREBASE_ANDROID_APP_ID` | Firebase app ID, e.g. `1:123456789:android:abcdef`; this is not the package name |
| Variable | `FIREBASE_TESTER_GROUPS` | Existing group aliases, comma-separated, e.g. `internal-testers` |
| Variable | `FIREBASE_TOOLS_VERSION` | An exact Firebase CLI version you have tested |
| Secret | `FIREBASE_SERVICE_ACCOUNT_JSON` | Complete service account JSON with Firebase App Distribution Admin access to the intended project |
| Secret | `ANDROID_KEYSTORE_BASE64` | Single-line base64 of your Android release/testing keystore |
| Secret | `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| Secret | `ANDROID_KEY_ALIAS` | Signing key alias |
| Secret | `ANDROID_KEY_PASSWORD` | Signing key password |

Use the same signing key for successive installations of this testing app.
This example uses a service account credential for clarity. For a production CI
setup, consider GitHub OIDC with Google Workload Identity Federation instead of
a long-lived JSON key. No Firebase SDK or `google-services.json` is needed just
to upload an APK to App Distribution.

### Required Android signing configuration

The current project signs release builds with the debug key. Before activating
`firebase.yml`, add the following **after `plugins { ... }`** in
`android/app/build.gradle.kts`:

```kotlin
val releaseKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
```

Inside the existing `android { ... }` block, add the signing configuration before
`buildTypes` and replace the existing `buildTypes` block with:

```kotlin
signingConfigs {
    if (!releaseKeystorePath.isNullOrBlank()) {
        create("release") {
            storeFile = file(releaseKeystorePath)
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        }
    }
}

buildTypes {
    release {
        // Keeps unsigned-credential local/CI compilation checks working.
        // The Firebase workflow requires all signing credentials before building.
        signingConfig = if (!releaseKeystorePath.isNullOrBlank()) {
            signingConfigs.getByName("release")
        } else {
            signingConfigs.getByName("debug")
        }
    }
}
```

These Gradle changes are instructions only; the templates do not change the app's
existing native build configuration. Firebase is configured here for **Android**;
use TestFlight for iOS testers.

## TestFlight: signed iOS IPA upload

Environment: `testflight`.

| Kind | Name | Value |
| --- | --- | --- |
| Variable | `FLUTTER_VERSION` | Verified Flutter version; default `3.44.5` |
| Variable | `IOS_BUNDLE_ID` | Registered explicit bundle ID matching the App Store Connect app and profile |
| Variable | `APPLE_TEAM_ID` | Apple Developer team ID |
| Secret | `APPLE_CERTIFICATE_BASE64` | Single-line base64 of Apple Distribution `.p12`, including its private key |
| Secret | `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12`; use a nonempty password |
| Secret | `APPLE_PROFILE_BASE64` | Single-line base64 of an App Store distribution `.mobileprovision` profile |
| Secret | `KEYCHAIN_PASSWORD` | A random nonempty password for the temporary CI keychain |
| Secret | `ASC_KEY_ID` | App Store Connect team API key ID |
| Secret | `ASC_ISSUER_ID` | App Store Connect API issuer ID |
| Secret | `ASC_PRIVATE_KEY_BASE64` | Single-line base64 of the API key's `.p8` private key |

Use a paid Apple Developer account and create the App Store Connect app record
before uploading. The team API key needs permission to upload the app. This
example assumes a single Runner target without extensions; additional targets
need their own profiles and export mappings. The signing certificate must be
included in the provisioning profile, and both must be valid and unexpired.

The workflow installs signing credentials into a temporary keychain, configures
Runner signing on the CI checkout, builds an App Store signed IPA, and uploads it
with Xcode's `altool`. It cleans temporary credentials even after a failed step.
It requires Xcode 26.5 at `/Applications/Xcode_26.5.app` on the runner; verify the
runner image provides that version before activation.

A successful upload still needs Apple processing. Configure automatic internal
TestFlight distribution in App Store Connect, or assign the processed build
manually. External testing requires group configuration and beta review through
App Store Connect. This workflow does not submit the app for public App Store release.

## Encoding files on macOS

For a binary credential, copy a single-line base64 value directly to your clipboard:

```sh
base64 -i /path/to/distribution.p12 | tr -d '\n' | pbcopy
```

Repeat for the profile, API private key, and Android keystore. Store Firebase
service account JSON as its original JSON text, not base64. Do not paste credential
values into terminal logs or commit them.

## References

- [Flutter iOS release guide](https://docs.flutter.dev/deployment/ios)
- [GitHub Apple signing on macOS runners](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
- [Apple altool usage](https://help.apple.com/asc/appsaltool/en.lproj/static.html)
- [Flutter Android release signing](https://docs.flutter.dev/deployment/android)
- [Firebase CLI APK distribution](https://firebase.google.com/docs/app-distribution/android/distribute-cli?apptype=apk)
- [Firebase service account authentication](https://firebase.google.com/docs/app-distribution/authenticate-service-account?platform=android)
