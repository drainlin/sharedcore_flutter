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

  test('cookbook names every public model field and enum', () {
    final cookbook = File('docs/cookbook.html').readAsStringSync();
    const sourcePaths = <String>[
      'lib/src/configuration.dart',
      'lib/src/models.dart',
      'lib/src/errors.dart',
    ];

    for (final path in sourcePaths) {
      final source = File(path).readAsStringSync();
      final declarations = RegExp(
        r'^(class|enum) (SharedCore[A-Za-z0-9]+)',
        multiLine: true,
      ).allMatches(source).toList(growable: false);

      for (var index = 0; index < declarations.length; index++) {
        final declaration = declarations[index];
        final name = declaration.group(2)!;
        final marker = '{ n: "$name"';
        final entryStart = cookbook.indexOf(marker);
        expect(
          entryStart,
          isNonNegative,
          reason: '$name from $path is missing from the cookbook',
        );
        final entryEnd = cookbook.indexOf('\n', entryStart);
        final entry = cookbook.substring(
          entryStart,
          entryEnd < 0 ? cookbook.length : entryEnd,
        );

        if (declaration.group(1) != 'class') continue;
        final bodyEnd = index + 1 < declarations.length
            ? declarations[index + 1].start
            : source.length;
        final body = source.substring(declaration.end, bodyEnd);
        final fields = RegExp(
          r'^\s*final\s+[A-Za-z0-9_<>,? ]+\s+(\w+);',
          multiLine: true,
        ).allMatches(body).map((match) => match.group(1)!);
        final getters =
            RegExp(
                  r'^\s*(?:bool|int|String|SharedCore\w+)\s+get\s+(\w+)',
                  multiLine: true,
                )
                .allMatches(body)
                .map((match) => match.group(1)!)
                .where((name) => name != 'hashCode');

        for (final member in <String>{...fields, ...getters}) {
          expect(
            entry,
            contains(member),
            reason: '$name.$member is missing from its cookbook model card',
          );
        }
      }
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
