# Phonetic Contact Name Update

Status: Release candidate ready; store submission pending approval

## Objective

Correct a likely person-name span in a Traditional Chinese STT transcript by
ranking the user's on-device contact names. The implementation must remain
offline and must not assume a fixed name length.

## Production Identity

- Android application ID: `com.pyramius.reminder`
- iOS bundle ID: `com.pyramius.reminder`
- Release version: `1.0.1+2`
- Android updates must use the existing release signing key and `adb install -r`.
- Uninstall-and-reinstall is not an update test because Android removes private
  app data during uninstall.

## Acceptance Cases

- `提醒我明天下午要跟李佩瑜吃飯` with contact `李沛米` becomes
  `提醒我明天下午要跟李沛米吃飯`.
- Two-, three-, and four-character names are supported.
- Similar-sounding initials and finals are ranked.
- Equally plausible contact names remain unchanged.
- Ordinary phrases remain unchanged.
- The corrected text is shown before saving and is the text that is stored.

## Release Gates

1. [x] Focused and full Flutter tests pass without skips.
2. [x] Static analysis has no findings.
3. [x] Android release APK and App Bundle build successfully.
4. [x] An in-place Pixel 7 update preserves the existing contact list.
5. [x] The real speech case is corrected on the Pixel 7.
6. [ ] Store submission requires separate explicit approval.

The real-device result in gate 5 was confirmed by the user on 2026-08-27.

## Rollback

If the update causes false name corrections, stop rollout and build the prior
code with a version code greater than `2`. Existing Hive data is unchanged by
this feature, so rollback requires no data migration. Do not install a lower
version code or uninstall the production app during rollback testing.
