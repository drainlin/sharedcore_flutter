import 'package:flutter_test/flutter_test.dart';
import 'package:sharedcore_flutter/sharedcore_flutter.dart';

void main() {
  test('configuration exposes one semantic path for each setting', () {
    const configuration = SharedCoreConfiguration(
      appId: 'app-id',
      deviceOverrides: SharedCoreDeviceOverrides(
        hasWeChatOrQQInstalled: true,
        templateLanguage: 'zh',
        installReferrer: 'campaign',
      ),
      apiPathMode: SharedCoreApiPathMode.builtIn,
      http: SharedCoreHttpConfiguration(proxyUrl: 'http://127.0.0.1:8080'),
    );

    expect(configuration.deviceOverrides.hasWeChatOrQQInstalled, isTrue);
    expect(configuration.apiPathMode, SharedCoreApiPathMode.builtIn);
    expect(configuration.http.proxyUrl, 'http://127.0.0.1:8080');
  });

  test('exception exposes one stable error vocabulary', () {
    const error = SharedCoreException(
      localError: SharedCoreLocalError.network,
      message: 'offline',
      isRetryable: true,
    );

    expect(error.localError, SharedCoreLocalError.network);
    expect(error.backendCode, isNull);
    expect(error.isLocalError, isTrue);
    expect(error.isRetryable, isTrue);
    expect(error.isAuthenticationError, isFalse);
  });

  test(
    'exception identifies authentication failures without exposing tokens',
    () {
      const error = SharedCoreException(
        backendCode: 510,
        message: 'credential expired',
        httpStatus: 200,
      );

      expect(error.isAuthenticationError, isTrue);
      expect(error.isRetryable, isFalse);
    },
  );

  test('semantic client surface compiles', () {
    expect(_compileAgainstSemanticClientSurface, isA<Function>());
  });

  test('image styles preserve the backend style identifiers', () {
    expect(
      SharedCoreImageStyle.values.map((style) => style.id),
      orderedEquals(<int>[1, 2, 3, 4, 5, 6, 7, 8]),
    );
  });
}

Future<void> _compileAgainstSemanticClientSurface(
  SharedCoreClient client,
) async {
  await client.logout();
  await client.updatePassword('next-secret');
  await client.login(email: 'person@example.test', password: 'secret');
  await client.login(threeToken: 'third-party-token');
  await client.uploadUserDeviceIdentifiers(
    const SharedCoreSingularIdentifiers(
      sdid: 'sdid',
      idfa: 'idfa',
      idfv: 'idfv',
      aifa: 'aifa',
      asid: 'asid',
      amid: 'amid',
      oaid: 'oaid',
      andi: 'andi',
    ),
  );
  final bool exchangeSucceeded = await client.exchangeCode('code');
  if (exchangeSucceeded) {
    await client.refreshAccount();
  }
  await client.refreshAccount();
  await client.loadHomeContent();
  await client.loadVideoTemplateItems();
  await client.loadVideoItems(<int>[1]);
  await client.loadImageHistoryItems();
  await client.loadVideoHistoryItems();
  await client.deleteHistoryItems(<int>[1]);
  await client.uploadFile('/tmp/image.jpg');
  await client.submitVideoTask(
    const SharedCoreSubmitVideoOptions(imagePath: '/tmp/image.jpg'),
  );
  await client.extendVideoTask(
    source: const SharedCoreHistoryItem(
      type: 'video',
      recordId: 2810,
      extendId: 450080,
      title: '',
      coveringUrl: '',
      originUrl: '',
      reason: '',
      stateCode: 30,
      createdAt: 0,
      styleId: 0,
      canExtend: true,
    ),
  );
  await client.submitImageTaskFromImageUrl(
    imageUrl: 'https://image',
    style: SharedCoreImageStyle.chestModerate,
  );
  await client.submitImageTaskFromImagePath(
    imagePath: '/tmp/image.jpg',
    style: SharedCoreImageStyle.absDefineRipped,
  );
  await client.loadGenerationTaskInfo('prompt-id');
  await client.loadPurchaseCatalog();
  await client.verifyPurchase(
    productId: 'product',
    purchaseData: 'purchase-data',
  );
  await client.loadSensitiveWords();
}
