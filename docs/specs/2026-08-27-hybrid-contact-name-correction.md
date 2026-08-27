# Hybrid Contact Name Correction 1.0.2

## Objective

Improve Android and iOS speech contact-name correction by combining the same
on-device PERSON span model with the existing contact-list Pinyin matcher. This
release aims for useful coverage, not a claimed accuracy percentage.

## Scope

- Keep `com.pyramius.reminder` unchanged and bump the app to `1.0.2+3`.
- Run the same Baidu LAC Lite model and dictionaries locally on Android and iOS
  after speech recognition stops.
- Use only LAC `PER` spans as additional context for `NameCorrector`.
- Let the contact list and Pinyin score choose the replacement text.
- Keep the current relationship-cue fallback when the model is unavailable.
- Keep the existing Pinyin implementation as the fallback on both platforms.
- Do not upload or submit either build until both platforms pass the same fixed
  PERSON cases and their production-package checks.

## Required behavior

1. A near-sounding contact name can be corrected at sentence start or after an
   arbitrary prefix when LAC marks that exact source span as `PER`.
2. The existing relationship-cue cases continue to work without model output.
3. A LAC false positive such as `李子/PER` cannot relax a different or longer
   candidate span and cannot by itself select a contact.
4. Ambiguous contacts remain unchanged.
5. Missing native code, an unsupported ABI, model-copy failure, or inference
   failure returns no spans and leaves the existing Pinyin path operational on
   either platform.
6. Manual edits remain synchronous and use the existing analyzer path; model
   inference runs only once on the final speech transcript.
7. In-place Android and iOS updates preserve installed app data and contact
   lists.
8. The Android and iOS native detectors return identical PERSON words for the
   fixed release corpus because they use byte-identical model and dictionary
   assets.

## Design

`CaptureReviewScreen` requests PERSON spans asynchronously after `stt.stop()`.
A small Dart service calls a Flutter `MethodChannel`. Each platform resolves the
same versioned LAC assets, runs native inference off the main thread, and returns
the detected PERSON words. Dart maps those exact words back to rune offsets and
passes validated spans into `NoteAnalyzer` and `NameCorrector`.

The lower Pinyin threshold is allowed only when the candidate boundaries exactly
match a model span and enough syllables match exactly. The exact-syllable count
scales with contact length; it is not a fixed two- or three-character name rule.

The Android bundle keeps Flutter's existing ABIs. ARM devices use the official
Paddle Lite runtime; unsupported native ABIs build a stub that returns no spans.
iOS uses the official Paddle Lite v2.6.0 arm64 runtime with extra sequence
operators, which matches the generation of the existing LAC Lite model. Both
platforms keep the Pinyin fallback when native inference is unavailable.

## Reused components

- Existing `NameCorrector`, ambiguity filter, contact store, and Pinyin package.
- Existing `NoteAnalyzer` ordering so reminder and intent logic see corrected text.
- Existing Flutter `MethodChannel` pattern used by speech recognition.
- Official Baidu LAC C++ implementation, Lite model, dictionaries, and official
  platform Paddle Lite libraries under Apache-2.0.

## Verification

- Focused Dart tests for sentence start, arbitrary prefixes, false `PER` spans,
  ambiguity, fallback, and screen save behavior.
- Kotlin tests for PERSON-word to UTF-16 span mapping and missing words.
- iOS device tests that load the production model and assert the fixed PERSON
  outputs used by Android.
- Full `flutter test`, `flutter analyze`, Android unit tests, and iOS unit tests.
- Reversible manual mutations proving the model-context test and false-span guard
  fail when their protection is removed.
- Signed release APK/AAB and IPA inspection, including IDs, versions, packaged
  model assets, Android 16 KB ELF alignment, and iOS distribution signing.
- In-place installs on the existing Pixel 7 and iPhone; verify version
  `1.0.2+3`, package ID, retained data, and matching PERSON results.

## Rollback

Do not uninstall or downgrade either installed app. If rollback is needed,
revert the feature commits, increment each platform build number above `3`, and
ship another signed in-place update so local data remains intact.

## Sources

- https://github.com/baidu/lac
- https://github.com/PaddlePaddle/Paddle-Lite/releases/tag/v2.6.0
- https://docs.flutter.dev/platform-integration/platform-channels
- https://developer.android.com/studio/projects/gradle-external-native-builds
- https://developer.android.com/guide/practices/page-sizes
