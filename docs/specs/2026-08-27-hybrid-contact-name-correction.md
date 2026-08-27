# Hybrid Contact Name Correction 1.0.2

## Objective

Improve Android speech contact-name correction by combining an on-device PERSON
span model with the existing contact-list Pinyin matcher. This release aims for
useful coverage, not a claimed accuracy percentage.

## Scope

- Keep `com.pyramius.reminder` unchanged and bump the app to `1.0.2+3`.
- Run Baidu LAC Lite locally on Android after speech recognition stops.
- Use only LAC `PER` spans as additional context for `NameCorrector`.
- Let the contact list and Pinyin score choose the replacement text.
- Keep the current relationship-cue fallback when the model is unavailable.
- Keep iOS on the existing Pinyin implementation in this release.
- Do not upload or submit this build to either app store.

## Required behavior

1. A near-sounding contact name can be corrected at sentence start or after an
   arbitrary prefix when LAC marks that exact source span as `PER`.
2. The existing relationship-cue cases continue to work without model output.
3. A LAC false positive such as `李子/PER` cannot relax a different or longer
   candidate span and cannot by itself select a contact.
4. Ambiguous contacts remain unchanged.
5. Missing native code, an unsupported ABI, model-copy failure, or inference
   failure returns no spans and leaves the existing Pinyin path operational.
6. Manual edits remain synchronous and use the existing analyzer path; model
   inference runs only once on the final speech transcript.
7. An in-place Android update preserves the installed app data and contact list.

## Design

`CaptureReviewScreen` requests PERSON spans asynchronously after `stt.stop()`.
A small Dart service calls a Flutter `MethodChannel`. Android copies versioned
LAC assets into app cache, runs the native model off the main thread, and returns
the detected PERSON words. Dart maps those exact words back to rune offsets and
passes validated spans into `NoteAnalyzer` and `NameCorrector`.

The lower Pinyin threshold is allowed only when the candidate boundaries exactly
match a model span and enough syllables match exactly. The exact-syllable count
scales with contact length; it is not a fixed two- or three-character name rule.

The Android bundle keeps Flutter's existing ABIs. ARM devices use the official
Paddle Lite runtime; unsupported native ABIs build a stub that returns no spans,
so the Pinyin fallback remains available.

## Reused components

- Existing `NameCorrector`, ambiguity filter, contact store, and Pinyin package.
- Existing `NoteAnalyzer` ordering so reminder and intent logic see corrected text.
- Existing Flutter `MethodChannel` pattern used by speech recognition.
- Official Baidu LAC Android C++ implementation, Lite model, dictionaries, and
  Paddle Lite libraries under Apache-2.0.

## Verification

- Focused Dart tests for sentence start, arbitrary prefixes, false `PER` spans,
  ambiguity, fallback, and screen save behavior.
- Kotlin tests for PERSON-word to UTF-16 span mapping and missing words.
- Full `flutter test`, `flutter analyze`, and Android unit tests.
- Reversible manual mutations proving the model-context test and false-span guard
  fail when their protection is removed.
- Signed release APK and AAB inspection, including packaged ABIs/assets and 16 KB
  ELF alignment.
- In-place install on the existing Pixel 7; verify version `1.0.2+3`, package ID,
  retained contact `李沛米`, and the final speech-review flow.

## Rollback

Do not uninstall or downgrade the installed app. If rollback is needed, revert
the feature commits, increment the version code above `3`, build a signed APK,
and install it as another in-place update so local data remains intact.

## Sources

- https://github.com/baidu/lac
- https://docs.flutter.dev/platform-integration/platform-channels
- https://developer.android.com/studio/projects/gradle-external-native-builds
- https://developer.android.com/guide/practices/page-sizes
