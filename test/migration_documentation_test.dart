import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('0.3.0 migration guide covers endpoint configuration removal', () {
    final migration = File('MIGRATION_0_3_0.md').readAsStringSync();

    expect(migration, contains('`SharedCoreEndpoint`'));
    expect(migration, contains('`endpointPaths`'));
    expect(migration, contains('`SharedCoreApiPathMode.custom`'));
    expect(migration, contains('均已删除'));
  });

  test('cookbook and migration guide cover the breaking API contracts', () {
    final migration = File('MIGRATION_0_3_0.md').readAsStringSync();
    final cookbook = File('docs/cookbook.html').readAsStringSync();
    const requiredTerms = <String>[
      'SharedCoreDeviceOverrides',
      'SharedCore.configure',
      'logout()',
      'Future&lt;bool&gt;',
      'submitImageTaskFromImageUrl',
      'submitImageTaskFromImagePath',
      'SharedCoreImageStyle',
      'verifyPurchase',
      'SharedCoreLocalError',
      'backendCode',
      'shouldDiscardReceipt',
      'LSApplicationQueriesSchemes',
    ];

    for (final term in requiredTerms) {
      final markdownTerm = term.replaceAll('&lt;', '<').replaceAll('&gt;', '>');
      expect(migration, contains(markdownTerm));
      expect(cookbook, contains(term));
    }
  });

  test('Flutter-user documentation does not expose Rust or FRB details', () {
    final migration = File('MIGRATION_0_3_0.md').readAsStringSync();
    final cookbook = File('docs/cookbook.html').readAsStringSync();

    expect(migration, isNot(contains('Rust')));
    expect(migration, isNot(contains('FRB')));
    expect(cookbook, isNot(contains('Rust')));
    expect(cookbook, isNot(contains('FRB')));
  });

  test('public Dart API does not expose session credentials', () {
    final client = File('lib/src/client.dart').readAsStringSync();
    final configuration = File('lib/src/configuration.dart').readAsStringSync();

    expect(client, isNot(contains('Future<String> get accessToken')));
    expect(client, isNot(contains('Future<void> setSession')));
    expect(client, isNot(contains('Future<void> startSession')));
    expect(client, isNot(contains('Future<void> clearSession')));
    expect(configuration, isNot(contains('class SharedCoreSession')));
    expect(client, contains('Future<void> logout()'));
  });

  test('iOS privacy manifest covers UserDefaults for CocoaPods and SPM', () {
    const manifestPath =
        'ios/sharedcore_flutter/Sources/sharedcore_flutter/'
        'PrivacyInfo.xcprivacy';
    final manifest = File(manifestPath).readAsStringSync();
    final podspec = File('ios/sharedcore_flutter.podspec').readAsStringSync();
    final package = File(
      'ios/sharedcore_flutter/Package.swift',
    ).readAsStringSync();
    final cocoaPodsImplementation = File(
      'ios/Classes/SharedcoreFlutterPlugin.swift',
    ).readAsStringSync();
    final spmImplementation = File(
      'ios/sharedcore_flutter/Sources/sharedcore_flutter/'
      'SharedcoreFlutter.swift',
    ).readAsStringSync();

    expect(manifest, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
    expect(manifest, contains('CA92.1'));
    expect(manifest, contains('NSPrivacyAccessedAPICategoryFileTimestamp'));
    expect(manifest, contains('C617.1'));
    expect(manifest, contains('<key>NSPrivacyTracking</key>'));
    expect(manifest, contains('<false/>'));
    expect(podspec, contains(manifestPath.substring('ios/'.length)));
    expect(package, contains('.process("PrivacyInfo.xcprivacy")'));
    expect(cocoaPodsImplementation, isNot(contains('activeInputModes')));
    expect(spmImplementation, isNot(contains('activeInputModes')));
  });
}
