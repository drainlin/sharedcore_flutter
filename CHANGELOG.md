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
