import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharedcore_flutter/sharedcore_flutter.dart';
import 'package:sharedcore_flutter/src/device_info_collector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('configuration preserves the Rust-facing values', () {
    const configuration = SharedCoreConfiguration(
      baseUrl: 'https://example.test',
      appId: 'app-id',
      signSecret: 'secret',
      deviceOverrides: SharedCoreDeviceOverrides(installReferrer: 'campaign'),
      jsonNoisePrefix: '_custom_',
      jsonNoiseFieldCount: 12,
    );

    expect(configuration.appId, 'app-id');
    expect(configuration.deviceOverrides.installReferrer, 'campaign');
    expect(configuration.jsonNoisePrefix, '_custom_');
    expect(configuration.jsonNoiseFieldCount, 12);
  });

  test('account model decodes Rust camel-case JSON fields', () {
    final account = SharedCoreAccountSnapshot.fromMap(<String, Object?>{
      'userId': '42',
      'email': 'hello@example.test',
      'totalCredits': 9,
      'isPro': true,
    });

    expect(account.userId, '42');
    expect(account.email, 'hello@example.test');
    expect(account.totalCredits, 9);
    expect(account.isPro, isTrue);
  });

  test('url fields decode the lowercase-url keys emitted by the Rust core', () {
    final account = SharedCoreAccountSnapshot.fromMap(<String, Object?>{
      'purchaseVideoUrlString': 'https://purchase-video',
      'activeUrlString': 'https://active',
      'replacementApp': <String, Object?>{
        'downloadUrlString': 'https://download',
        'webUrlString': 'https://web',
        'isEnabled': true,
      },
    });

    expect(account.purchaseVideoUrlString, 'https://purchase-video');
    expect(account.activeUrlString, 'https://active');
    expect(account.replacementApp.downloadUrlString, 'https://download');
    expect(account.replacementApp.webUrlString, 'https://web');
    expect(account.replacementApp.isEnabled, isTrue);
  });

  test('history model keeps record and task identifiers separate', () {
    final history = SharedCoreHistoryItem.fromMap(<String, Object?>{
      'type': 'video',
      'recordId': 2810,
      'extendId': 450080,
      'canExtend': true,
    });

    expect(history.recordId, 2810);
    expect(history.extendId, 450080);
    expect(history.type, SharedCoreHistoryItemType.video);
    expect(history.status, SharedCoreTaskStatus.unknown);
  });

  test('account semantic codes decode as enums', () {
    final account = SharedCoreAccountSnapshot.fromMap(<String, Object?>{
      'membership': 'inactive',
      'role': 'review',
      'subscribeState': 'cancelled',
    });

    expect(account.membership, SharedCoreMembershipStatus.inactive);
    expect(account.role, SharedCoreAccountRole.review);
    expect(account.subscribeState, SharedCoreSubscriptionStatus.cancelled);
  });

  test('task state code 2 decodes as failed for legacy payloads', () {
    final task = SharedCoreTaskInfo.fromMap(<String, Object?>{'stateCode': 2});
    final history = SharedCoreHistoryItem.fromMap(<String, Object?>{
      'stateCode': 2,
    });

    expect(task.status, SharedCoreTaskStatus.failed);
    expect(history.status, SharedCoreTaskStatus.failed);
  });

  test('exception exposes a local error without a backend code', () {
    const error = SharedCoreException(
      localError: SharedCoreLocalError.network,
      message: 'offline',
      isRetryable: true,
    );

    expect(error.toString(), contains('network'));
    expect(error.backendCode, isNull);
    expect(error.isLocalError, isTrue);
    expect(error.isBackendError, isFalse);
    expect(error.isRetryable, isTrue);
  });

  test('exception exposes backend code and message without a local error', () {
    const error = SharedCoreException(
      backendCode: 730,
      message: 'Insufficient balance',
      httpStatus: 200,
    );

    expect(error.backendCode, 730);
    expect(error.localError, isNull);
    expect(error.message, 'Insufficient balance');
    expect(error.isBackendError, isTrue);
    expect(error.isLocalError, isFalse);
  });

  test('equivalent configurations compare equal', () {
    const first = SharedCoreConfiguration(appId: 'app-id');
    const second = SharedCoreConfiguration(appId: 'app-id');

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test(
    'null sign secret selects the Rust default without conflating empty',
    () {
      const defaultSecret = SharedCoreConfiguration(appId: 'app-id');
      const emptySecret = SharedCoreConfiguration(
        appId: 'app-id',
        signSecret: '',
      );

      expect(defaultSecret.signSecret, isNull);
      expect(emptySecret.signSecret, isEmpty);
      expect(defaultSecret, isNot(emptySecret));
    },
  );

  test('configuration keeps the original iOS session storage prefix', () {
    const defaultConfiguration = SharedCoreConfiguration(appId: 'app-id');
    const customConfiguration = SharedCoreConfiguration(
      appId: 'app-id',
      sessionStorageKeyPrefix: 'Product',
    );

    expect(defaultConfiguration.sessionStorageKeyPrefix, 'SharedCore');
    expect(customConfiguration.sessionStorageKeyPrefix, 'Product');
    expect(defaultConfiguration, isNot(customConfiguration));
  });

  test('HTTP transport defaults both timeouts to 60 seconds', () {
    const http = SharedCoreHttpConfiguration();

    expect(http.connectTimeout, const Duration(seconds: 60));
    expect(http.readTimeout, const Duration(seconds: 60));
  });

  test('device overrides take precedence over collected values', () {
    const collected = SharedCoreDeviceInfo(
      appId: 'app-id',
      bundleId: 'com.example.automatic',
      udid: 'auto-id',
      platform: 'android',
      vpn: true,
      networkOperator: 'automatic-network',
    );
    const overrides = SharedCoreDeviceOverrides(
      vpn: false,
      installReferrer: 'campaign',
      hasWeChatOrQQInstalled: true,
    );

    final merged = mergeSharedCoreDeviceInfo(collected, overrides);

    expect(merged.appId, 'app-id');
    expect(merged.bundleId, 'com.example.automatic');
    expect(merged.udid, 'auto-id');
    expect(merged.platform, 'android');
    expect(merged.vpn, isFalse);
    expect(merged.hasWeChatOrQQInstalled, isTrue);
    expect(merged.networkOperator, 'automatic-network');
    expect(merged.installReferrer, 'campaign');
  });

  test('unset device overrides preserve automatically collected values', () {
    const collected = SharedCoreDeviceInfo(
      appId: 'app-id',
      udid: 'auto-id',
      platform: 'ios',
      language: 'zh',
      networkOperator: 'automatic-network',
      hasWeChatOrQQInstalled: true,
    );
    const overrides = SharedCoreDeviceOverrides(
      templateLanguage: 'en',
      installReferrer: 'campaign',
    );

    final merged = mergeSharedCoreDeviceInfo(collected, overrides);

    expect(merged.udid, 'auto-id');
    expect(merged.platform, 'ios');
    expect(merged.language, 'zh');
    expect(merged.hasWeChatOrQQInstalled, isTrue);
    expect(merged.networkOperator, 'automatic-network');
    expect(merged.templateLanguage, 'en');
    expect(merged.installReferrer, 'campaign');
  });

  test('platform device information is decoded', () async {
    const channel = MethodChannel('sharedcore_flutter/device_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'collectDeviceInfo');
          expect(call.arguments, <String, Object?>{'appId': 'app-id'});
          return <String, Object?>{
            'appId': 'app-id',
            'bundleId': 'com.example.host',
            'udid': 'native-id',
            'platform': 'ios',
            'vpn': true,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final device = await collectSharedCoreDeviceInfo('app-id');

    expect(device.udid, 'native-id');
    expect(device.bundleId, 'com.example.host');
    expect(device.platform, 'ios');
    expect(device.vpn, isTrue);
  });

  test('configuration keeps the explicit API path mode', () {
    const bundleDerivedPaths = SharedCoreConfiguration(appId: 'app-id');
    const builtInPaths = SharedCoreConfiguration(
      appId: 'app-id',
      apiPathMode: SharedCoreApiPathMode.builtIn,
    );

    expect(bundleDerivedPaths.apiPathMode, SharedCoreApiPathMode.bundleDerived);
    expect(builtInPaths.apiPathMode, SharedCoreApiPathMode.builtIn);
    expect(builtInPaths, isNot(bundleDerivedPaths));
  });

  test('global client reports not configured before configure', () {
    SharedCore.resetForTesting();

    expect(SharedCore.isConfigured, isFalse);
    expect(
      () => SharedCore.instance,
      throwsA(
        isA<SharedCoreException>().having(
          (error) => error.localError,
          'localError',
          SharedCoreLocalError.notConfigured,
        ),
      ),
    );
  });
}
