# Hybrid Contact Name Update

Status: Android release candidate installed; real speech confirmation pending

## Production identity

- Android application ID: `com.pyramius.reminder`
- iOS bundle ID: `com.pyramius.reminder`
- Release version: `1.0.2+3`
- Store submission is outside this release task and has not been performed.

## Change

Android now runs Baidu LAC Lite locally after speech recognition stops. LAC only
identifies candidate PERSON spans. The existing contact list, Pinyin score,
ambiguity margin, and exact-span guard still decide whether text is replaced.
If native inference is unavailable, the existing Pinyin and relationship-cue
path continues without blocking the review screen. iOS remains on that existing
path in this release.

## Verification

- All 149 Flutter tests passed without skips.
- `flutter analyze` completed with no findings.
- App Android unit tests passed through `:app:testDebugUnitTest`.
- Debug APK, signed release APK, and signed release AAB built successfully.
- Fixed Pixel model check matched all 10 expected outputs; model load was about
  60 ms and average inference was about 0.44 ms.
- Two reversible Dart mutations were caught: ignoring model context broke the
  sentence-start case, and accepting overlapping spans broke the partial-span
  false-positive guard.
- Release APK passed 16 KB ZIP alignment. Every arm64 library in the AAB had a
  minimum ELF load alignment of at least 16 KB.
- Pixel 7 was updated in place to `1.0.2+3`; the app launched and the saved
  contact list remained present.

Release artifacts:

- APK: 67,163,349 bytes, SHA-256
  `7ac6fc9a153d30b1e09ebfbc52de3f4038a54748d5f99fb869423e141ab86891`
- AAB: 50,263,090 bytes, SHA-256
  `f83008a0ebcd219968a191245595d79be2a77a54d3ad6ebb74de52bb03888575`

Running every dependency's Gradle unit tests also runs the bundled
`camera_android_camerax` Robolectric suite. That upstream suite had 47 failures
because Android SDK 36 requires Java 21 while this project uses Java 17. These
were not reported as passing; the App module tests were run separately and
passed.

## Remaining acceptance

- Repeat a real spoken sentence with a near-sounding contact name at sentence
  start or after a prefix and confirm the corrected text in the review screen.
- Store upload and staged rollout require separate approval.

## Rollback

Do not uninstall or downgrade. Revert the hybrid feature, increment the Android
version code above `3`, sign with the existing release key, and install with
`adb install -r` so local records and contacts remain intact.
