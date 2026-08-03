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
      'setSession(accessToken:',
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
}
