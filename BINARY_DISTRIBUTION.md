# Binary distribution

`sharedcore_flutter` is the distributable repository. Rust source remains in
the private `shared_core_rust` repository and must never be copied here.

## Release contents

- Handwritten public Dart API under `lib/src/`
- FRB-generated Dart glue under `lib/src/generated/`
- Android ARM64 shared library under `android/src/main/jniLibs/arm64-v8a/`
- iOS ARM64 static libraries packaged as an XCFramework under
  `ios/Frameworks/`
- Minimal Swift/header linkage glue under `ios/Classes/`

## Build from the private repository

```sh
cd ../shared_core_rust/frb_bridge
./scripts/build_all.sh
```

The build uses pinned Rust/FRB versions, reqwest, rustls, and the embedded
Mozilla public root set from `webpki-root-certs`.

## App-specific release package

From the private core repository:

```sh
cd ../shared_core_rust/frb_bridge
./scripts/package_flutter_app.sh \
  --client my_app
```

The command creates an app-specific plugin ZIP, a separate private-symbol ZIP,
and a checksum manifest under `dist/apps/my_app/`. The Flutter package keeps
the name `sharedcore_flutter` and its public Dart API. The application name is
enough at packaging time. Runtime identifiers are collected automatically;
consumers do not pass them manually.

Never ship the private-symbol ZIP to plugin consumers. Keep it alongside the
release manifest for crash symbolication.

## Pre-release checks

```sh
find . -name '*.rs' -o -name Cargo.toml
flutter analyze
flutter test
cd example && flutter build apk && flutter build ios --no-codesign
```

The first command must print nothing. A release is incomplete if either native
artifact is absent, if generated Dart and Rust hashes disagree, or if a binary
contains an unsupported architecture.
