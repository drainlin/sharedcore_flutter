import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('0.3.0 migration guide covers every renamed endpoint', () {
    final migration = File('MIGRATION_0_3_0.md').readAsStringSync();
    const renamedEndpoints = <String, String>{
      'homeData': 'homeDataNew',
      'videoHistory': 'videoTaskHistory',
      'imageHistory': 'userAlbum',
      'videoTemplates': 'videoList',
      'deleteHistory': 'videoDel',
      'submitBodyEnhance': 'submitWaveSpeed',
      'purchaseOptions': 'rechargePurchaseListV2',
      'appleSubscription': 'subscribeApple',
      'googleSubscription': 'subscribeGoogle',
      'uploadUserDeviceIdentifiers': 'updateUserData',
    };

    for (final entry in renamedEndpoints.entries) {
      expect(migration, contains('`${entry.key}`'));
      expect(migration, contains('`${entry.value}`'));
    }
    expect(migration, contains('`userMigration`'));
    expect(migration, contains('`/userMigration` 已移除'));
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
