# sharedcore_flutter

Flutter FFI bindings for the private SharedCore Rust implementation. The
package ships Dart code, generated FRB glue, and precompiled native binaries;
it deliberately does not ship Rust source code.

## Supported targets

- Android ARM64 (`arm64-v8a`)
- iOS ARM64 devices
- iOS ARM64 simulators on Apple Silicon

x86, x86_64, and 32-bit ARM are intentionally unsupported.

The minimum supported toolchain is Flutter 3.38.0 with Dart 3.10.0.

## Basic usage

```dart
import 'package:sharedcore_flutter/sharedcore_flutter.dart';

final client = await SharedCore.configure(
  const SharedCoreConfiguration(
    baseUrl: 'https://api.example.com',
    appId: 'example-app',
    signSecret: null, // Uses the protected default embedded in Rust.
  ),
);

final home = await SharedCore.instance.loadHomeContent();

final videoHistory = await client.loadVideoHistoryItems();
final source = videoHistory.firstWhere((item) => item.canExtend == true);
final extension = await client.extendVideoTask(
  source: source,
  prompt: 'continue the scene',
);

final verification = await client.verifyPurchase(
  productId: storePurchase.productID,
  purchaseData: storePurchaseData,
);
```

History items expose two intentionally different identifiers: `recordId` is
used by `deleteHistoryItems`, while `extendId` identifies the source task
used by `extendVideoTask`. Do not pass `recordId` as `oldTaskId`.

`verifyPurchase` detects iOS or Android automatically. On iOS, pass Apple
receipt data as `purchaseData`; on Android, pass the Google Play purchase token.
It also determines the purchase type from the v2 catalog: only products in
`creditPage.purchaseList` are one-time purchases; every other known catalog
product is a subscription. If the catalog has not been loaded yet, the plugin
loads and caches it before verification.

`SharedCore` has one application-wide lifecycle. Reconfiguring it with the
same values returns the existing client; using different values reports an
`SharedCoreLocalError.alreadyConfigured` error. Android and iOS device metadata is collected
automatically during `configure`. The old device APIs have been removed. Use
`SharedCoreDeviceOverrides` only for values the application intentionally
overrides, such as `installReferrer`.

The 0.3.0 API is intentionally breaking: compatibility aliases and duplicate
parameter shapes were removed so every operation has one public spelling.
Endpoint paths are entirely plugin-owned: callers cannot enumerate or override
them.

Email login and registration both use `login`. Use `updatePassword` only to
change the password of the current email account; there is no separate email
binding API.

Session credentials are entirely SDK-owned. `configure` restores and validates
the secure credential or creates a fresh anonymous session. Applications never
read, inject, or persist the access token; use `logout` to leave the current
account and immediately create a new anonymous session.

All operational failures are exposed as `SharedCoreException`. Callers can
branch on `backendCode` versus `localError`, inspect `httpStatus`, use
`isRetryable` for delayed retry, and use `isAuthenticationError` when UI login
guidance is appropriate. Credential refresh and anonymous recovery are attempted
inside the SDK before an authentication failure reaches the application. A
failed credential write or deletion is never hidden; it is reported as
`SharedCoreLocalError.sessionStorageUnavailable`.

### Endpoint path strategy

`SharedCoreConfiguration.apiPathMode` selects the production endpoint path
source:

- `SharedCoreApiPathMode.bundleDerived` (default): derive deterministic endpoint paths in
  Rust from the runtime Android
  package name or iOS bundle identifier. The plugin collects this identifier
  automatically. In this mode the Rust core also ignores caller-supplied
  `jsonNoisePrefix` and `jsonNoiseFieldCount`: it derives the noise prefix and
  fixes the field count at 20.
- `SharedCoreApiPathMode.builtIn`: use protected paths bundled with the native
  core. Select this explicitly only when the backend uses those paths.

The v1 SHA-256 input concatenates the fixed 16-byte salt
`9d61e74a2cb853f016aa7c35d2894eb1`, the bundle ID's four-byte big-endian UTF-8
length and bytes, then the endpoint name's four-byte big-endian UTF-8 length
and bytes. No additional readable fixed string is included. The 64-character
lowercase hex digest is split into four equal 16-character segments with
exactly three `/` separators and no leading or trailing slash. The backend must
implement the same algorithm. This is path obfuscation, not authentication or
secret-key encryption.

In bundle-derived mode, the JSON noise prefix uses the same salt, SHA-256 function,
Bundle ID normalization, and four-byte big-endian length encoding. The final
length-prefixed input is the opaque 16-byte value
`47c2916ea538db0f74b925e38a51fc60` instead of an endpoint name. Take the first
eight lowercase hexadecimal characters of the digest and wrap them with `_`;
for example, `com.example.app` produces `_bb316d91_`. Noise field names are
that prefix followed by an integer from 0 through 19. In `builtIn` mode, the
caller-supplied JSON noise prefix and count are used unchanged.

`testServerMode: true` has higher priority than `apiPathMode`: it always uses
the protected built-in test server address and built-in endpoint paths. It does
not require a runtime Bundle ID.

### iOS WeChat/QQ detection

To let the plugin detect WeChat and QQ, add their URL schemes to the host
application's `ios/Runner/Info.plist`:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>weixin</string>
  <string>mqq</string>
</array>
```

If the host already has an `LSApplicationQueriesSchemes` array, append these
two entries instead of declaring the key a second time. Without this allowlist,
iOS `canOpenURL` returns `false` even when WeChat or QQ is installed. Android
package visibility queries are already declared by the plugin.

The core business and HTTP APIs continue to use the bundled Rust library.
Only host-owned device metadata and platform session persistence use a Flutter
method channel.

The plugin automatically restores and persists the SharedCore session on both
Android and iOS. Android encrypts the credential with an app-owned Android
Keystore key before storing the ciphertext. iOS stores it in Keychain with a
this-device-only accessibility class. Existing plugin-owned plaintext values
are migrated internally. A sandbox installation marker clears a surviving iOS
Keychain credential after a normal uninstall and reinstall. The default prefix
is `SharedCore`; set `sessionStorageKeyPrefix` only when separate products need
different session namespaces.

## Documentation

Open [docs/cookbook.html](docs/cookbook.html) for the standalone Chinese
cookbook for Flutter plugin users, including installation, 0.2.1 migration,
business recipes, error handling, recommended APIs, and business models.

For a focused breaking-change checklist with old/new code examples, see
[MIGRATION_0_3_0.md](MIGRATION_0_3_0.md).

## Binary layout

```text
android/src/main/jniLibs/arm64-v8a/libsharedcore_flutter.so
ios/sharedcore_flutter/Frameworks/SharedCoreRustBinary.xcframework/
lib/src/generated/                    # generated FRB Dart glue
```

The private bridge crate lives outside this package at
`../shared_core_rust/frb_bridge`. Its `scripts/build_all.sh` regenerates glue
and replaces the staged binary artifacts.

See [BINARY_DISTRIBUTION.md](BINARY_DISTRIBUTION.md) for the release boundary
and verification checklist.
