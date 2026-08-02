import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sharedcore_flutter/sharedcore_flutter.dart';

void main() {
  test('endpoint enum names match the real API path names', () {
    expect(SharedCoreEndpoint.values.map((endpoint) => endpoint.name), <String>[
      'saveDevice',
      'homeDataNew',
      'videoTaskHistory',
      'userAlbum',
      'videoList',
      'getTaskInfo',
      'videoDel',
      'submitVideo',
      'upload',
      'sensitiveWords',
      'submitWaveSpeed',
      'getVideoListByIds',
      'rechargePurchaseListV2',
      'applePurchase',
      'subscribeApple',
      'googlePurchase',
      'subscribeGoogle',
      'bindEmail',
      'login',
      'updateUserData',
      'exchangeCode',
    ]);
  });

  test('cookbook lists every public endpoint enum and real path', () {
    final cookbook = File('docs/cookbook.html').readAsStringSync();

    for (final endpoint in SharedCoreEndpoint.values) {
      expect(
        cookbook,
        contains('["${endpoint.name}", "enum", "/${endpoint.name}"]'),
        reason: 'Missing SharedCoreEndpoint.${endpoint.name} from cookbook',
      );
    }
  });
}
