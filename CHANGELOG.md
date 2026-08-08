## Unreleased

- Replaced account membership, role, subscription-state, history-type, and
  generation-state scalar values with semantic enums.
- Removed the redundant raw `stateCode` fields from history items and task
  results; both now expose `SharedCoreTaskStatus` through `status`.
- Corrected backend generation state `2` to normalize as `failed`.
- Changed purchase-item `isShow` from `int` to `bool` while retaining legacy
  `0`/`1` decoding compatibility.

## 0.3.5

- Android device metadata now reports carrier MCC/MNC codes
  (`networkOperator` / `simOperator`) instead of carrier names.
- iOS no longer collects carrier operator information; `networkOperator` and
  `simOperator` are left empty in the reported device payload.

## 0.3.4

- Fixed iOS release/IPA builds losing the Rust entry symbols. The podspec now
  applies `STRIP_STYLE = non-global` to consuming app targets so the archive
  strip step keeps `frb_get_rust_content_hash` and the linker-retention
  symbols exported. Without this, `flutter build ipa` stripped the export
  trie and apps crashed on launch with
  `Failed to lookup symbol 'frb_get_rust_content_hash'`.

## 0.3.3

- Fixed replacement-app and account URL fields decoding the lowercase-url JSON
  keys emitted by the Rust core. Renamed `downloadURLString` →
  `downloadUrlString`, `webURLString` → `webUrlString`,
  `purchaseVideoURLString` → `purchaseVideoUrlString`, and `activeURLString` →
  `activeUrlString`; these fields previously always decoded to empty strings.
- Added Rust and Flutter contract tests that lock the serialized URL key names.

## 0.3.2

- Added the iOS privacy manifest for app-only `UserDefaults` and native file
  metadata access, bundled through both CocoaPods and Swift Package Manager.
- Stopped reading the active-keyboard list on iOS; `inputLanguage` now uses the
  current locale language so keyboard-derived information is not sent off-device.
- Changed the default `apiPathMode` to `bundleDerived`; `builtIn` now requires
  explicit selection.
- Removed `bindEmail`; email login and registration now share `login`.
- Kept `updatePassword` as the only password-change API and moved its backend
  request to `changePassword` without changing the request fields.
- Made session credentials fully SDK-owned: removed the public token/session
  accessors and injection/start/clear methods, added automatic bootstrap and
  `logout`, and serialized credential persistence.
- Moved credentials to iOS Keychain and Android Keystore-backed AES-GCM
  storage, including plaintext migration, reinstall cleanup on iOS, and
  redacted Rust Session diagnostics.
- Hardened `saveDevice` recovery: rejected credentials are removed before an
  anonymous fallback, missing Sessions self-heal on the next business call,
  and transient refresh failures retain credentials.
- Added caller-visible `isRetryable` and `isAuthenticationError` exception
  semantics plus distinct unauthorized, forbidden, not-found, and server
  local HTTP categories.
- Hardened native release artifacts with per-build obfuscation for selected
  internal protocol fields and expanded Android/iOS plaintext scans.

## 0.3.1

- Separated history `recordId` from `extendId` and added
  `extendVideoTask`, which always submits that explicit extension source ID.
- Simplified extension submissions to one positive `extendId`; the SDK maps it
  to the backend extension fields internally.

## 0.3.0

This release is intentionally incompatible with 0.2.1 and does not retain old
API aliases. See `MIGRATION_0_3_0.md` for old/new code examples and the upgrade
checklist.

### Runtime and lifecycle

- Raised the minimum supported toolchain to Flutter 3.38.0 and Dart 3.10.0.
- Replaced the former C++ platform implementations with a shared Rust core
  accessed through precompiled FRB binaries; Rust source is not distributed in
  the Flutter plugin.
- Kept one application-wide `SharedCore` client. Native-library initialization
  and device collection now happen automatically during `configure`.
- Fixed iOS static Rust-library initialization and symbol retention for both
  CocoaPods and Swift Package Manager integrations.
- Fixed Android release builds by applying the Kotlin Gradle plugin explicitly
  in the plugin and example projects.
- Replaced required `SharedCoreDeviceConfiguration` with optional
  `SharedCoreDeviceOverrides`; Android and iOS collect platform-owned device
  information automatically.

### Session behavior

- Changed `setSession` to accept only `accessToken`; it refreshes the account to
  populate the complete internal session.
- Preserved the old iOS `NSUserDefaults` session keys and Keychain UDID
  namespace for upgrade continuity.
- Added automatic Android session persistence in plugin-owned private
  `SharedPreferences`. Existing app-owned Android tokens must be imported once.
- Removed `migrateUserSession`.

### Public API changes

- Changed `exchangeCode` from a backend-data map to `Future<bool>`: parsed JSON
  code 200 returns `true`, and every other parsed business code returns `false`.
- Replaced named attribution parameters with `SharedCoreSingularIdentifiers`.
- Replaced named video-task parameters with `SharedCoreSubmitVideoOptions`.
- Renamed `deleteHistoryItemIds` to `deleteHistoryItems`, `uploadFileResult` to
  `uploadFile`, and `loadSensitiveWordList` to `loadSensitiveWords`.
- Renamed WaveSpeed-facing methods to `submitImageTaskFromImageUrl` and
  `submitImageTaskFromImagePath`; raw style IDs are now
  `SharedCoreImageStyle` values.
- Unified four Apple/Google purchase and subscription verification methods as
  `verifyPurchase`, with automatic platform and v2-catalog type selection.
- Replaced duplicate numeric/string error fields with `backendCode` for backend
  failures and `SharedCoreLocalError` for SDK/device failures. `httpStatus` is
  nullable; `businessReason`, `retryable`, and `underlying*` were removed.
- Removed the public `SharedCoreEndpoint` enum and `endpointPaths`; callers can
  no longer enumerate or override backend routes.

### Configuration and endpoints

- Made `signSecret` nullable. `null` selects the protected Rust-embedded
  default; non-null values are used exactly as supplied.
- Limited `apiPathMode` to `builtIn` and `bundleDerived`; the former `custom`
  mode and caller-supplied endpoint mappings were removed.
- Made `testServerMode` always select the built-in test server address and real,
  unobfuscated endpoint paths.
- Encoded the test-server URL and built-in paths at build time and added a
  release-binary scan that rejects plaintext route leakage.
- Made bundle-derived mode derive its endpoint paths and `_xxxxxxxx_` JSON noise
  prefix from the runtime Bundle ID/package name, with exactly 20 noise fields.
- Replaced `proxyHost` and `proxyPort` with
  `SharedCoreHttpConfiguration.proxyUrl`; connection, read-idle, and overall
  request timeouts default to 60 seconds.

### Model and platform changes

- Removed `schema` and `hasTarget` from `SharedCoreReplacementApp`;
  `isEnabled` now follows only the backend enable flag.
- Removed `shouldDiscardReceipt` from
  `SharedCorePurchaseVerificationResult`.
- Added `SharedCoreSession` for reading the complete current session.
- Limited bundled binaries to Android ARM64, iOS ARM64 devices, and iOS ARM64
  simulators on Apple Silicon. x86, x86_64, and 32-bit ARM are unsupported.

## 0.0.1

* Add the complete SharedCore Rust client surface through FRB.
* Bundle precompiled Android and iOS ARM64 artifacts without Rust source.
* Add a handwritten Dart facade that keeps generated FRB types internal.
