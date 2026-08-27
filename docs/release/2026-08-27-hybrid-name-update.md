# Hybrid Contact Name Update

Status: Android and iOS release candidates verified and submitted for review

## Production identity

- Android application ID: `com.pyramius.reminder`
- iOS bundle ID: `com.pyramius.reminder`
- Release version: `1.0.2+3`

## Change

Android and iOS now run the same Baidu LAC model locally after speech
recognition stops. LAC only identifies candidate PERSON spans. The existing
contact list, Pinyin score, ambiguity margin, and exact-span guard still decide
whether text is replaced. If native inference is unavailable, the existing
Pinyin and relationship-cue path continues without blocking the review screen.

The iOS simulator does not run Paddle Lite v2.6.0 because the upstream archive
contains only an arm64 device library. Simulator builds use the existing Pinyin
fallback; production iPhone builds run the same model and dictionaries as
Android.

## Verification

- All 151 Flutter tests passed without skips.
- `flutter analyze` completed with no findings.
- Android App module tests passed through `:app:testDebugUnitTest`.
- Four iOS native tests passed on a physical iPhone. The model loaded and the
  fixed 10-sentence PERSON corpus matched Android's expected output.
- The Android and iOS LAC sources, model, and three dictionaries are guarded as
  byte-identical. SHA-256 checks of the packaged IPA assets matched Android.
- A reversible mutation removing iOS from the native-platform guard was caught
  by the parity test. Restoring the production code returned the test to green.
- The release APK passed 16 KB ZIP alignment. Every arm64 library in the AAB
  had a minimum ELF load alignment of at least 16 KB.
- Pixel 7 was updated in place to `1.0.2+3`; the App launched and the saved
  contact `李沛米` remained present.
- iPhone was updated in place to `1.0.2+3` and launched. Its contact database
  was empty, so retained contact content could not be verified on that device.
- The App Store IPA passed strict code-signature verification and uses an App
  Store profile with `get-task-allow=false`.

Release artifacts:

- APK: 67,163,349 bytes, SHA-256
  `c77b2390b915d307b69f06995bfc93117dcc0240a685c2d819118540e32d096b`
- AAB: 50,263,085 bytes, SHA-256
  `e82d4e44642d1ccb6c08d1027ec34e9186a8605686302ce1c9272bb9ae70132e`
- IPA: 26,013,453 bytes, SHA-256
  `6f2179dbfec25b9143f0ecad6ecbfec555f48027c0a2a837c2c5c2202d69c7d4`

Running every dependency's Gradle unit tests also runs the bundled
`camera_android_camerax` Robolectric suite. That upstream suite previously had
47 failures because Android SDK 36 requires Java 21 while this project uses
Java 17. These were not reported as passing; the App module tests were run
separately and passed.

## Remaining acceptance

- Automated tests verify text-to-model-to-contact matching, but they do not
  generate physical speech into the phone microphone. The user accepted this
  limitation for this release.
- Google Play accepted build `3 (1.0.2)` for a 100% production rollout. The
  release is under review and is not yet confirmed publicly available.
- App Store Connect accepted iOS `1.0.2 (3)` and reports "Waiting for Review".
  Automatic release is selected, but the update is not yet publicly available.
- Xcode uploaded the iOS archive with two non-blocking warnings: iOS 13 will no
  longer meet Apple's minimum version starting in spring 2027, and the bundled
  `objective_c.framework` has no matching dSYM. The latter limits crash-symbol
  quality for that dependency but did not block submission.

## Rollback

Do not uninstall or downgrade. Revert the hybrid feature, increment both build
numbers above `3`, sign with the existing release identities, and install as an
update so local records and contacts remain intact.
