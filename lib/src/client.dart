import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

import 'configuration.dart';
import 'device_info_collector.dart';
import 'errors.dart';
import 'generated/api.dart' as bridge;
import 'generated/frb_generated.dart';
import 'models.dart';
import 'purchase_classifier.dart';

part 'platform_session_store.dart';

/// Application-level SharedCore singleton and Rust library entry point.
abstract final class SharedCore {
  static Future<void>? _initialization;
  static SharedCoreConfiguration? _configuration;
  static SharedCoreClient? _client;
  static Future<SharedCoreClient>? _configureInFlight;
  static SharedCoreConfiguration? _configureInFlightConfiguration;

  static Future<void> _initialize() => _initialization ??= _initializeRust();

  static Future<void> _initializeRust() async {
    try {
      await SharedCoreRustLib.init(
        externalLibrary: Platform.isIOS
            ? ExternalLibrary.process(iKnowHowToUseIt: true)
            : null,
      );
    } on Exception catch (error) {
      throw SharedCoreException(
        localError: SharedCoreLocalError.invalidState,
        message: 'Failed to initialize SharedCore: $error',
      );
    }
  }

  /// Returns the version of the linked platform-neutral Rust core.
  static Future<String> version() async {
    await _initialize();
    return bridge.coreVersion();
  }

  /// Configures SharedCore once and returns the global client.
  ///
  /// Repeating this call with the same configuration returns the existing
  /// client. A different configuration throws [SharedCoreException].
  static Future<SharedCoreClient> configure(
    SharedCoreConfiguration configuration,
  ) {
    final existing = _client;
    if (existing != null) {
      if (_configuration == configuration) {
        return Future<SharedCoreClient>.value(existing);
      }
      return Future<SharedCoreClient>.error(_alreadyConfigured(false));
    }

    final inFlight = _configureInFlight;
    if (inFlight != null) {
      if (_configureInFlightConfiguration == configuration) return inFlight;
      return Future<SharedCoreClient>.error(_alreadyConfigured(true));
    }

    final future = _configure(configuration);
    _configureInFlight = future;
    _configureInFlightConfiguration = configuration;
    return future;
  }

  /// Returns the configured global client.
  static SharedCoreClient get instance {
    final existing = _client;
    if (existing == null) {
      throw const SharedCoreException(
        localError: SharedCoreLocalError.notConfigured,
        message: 'SharedCore is not configured',
      );
    }
    return existing;
  }

  /// Whether a global client has been configured successfully.
  static bool get isConfigured => _client != null;

  static Future<SharedCoreClient> _configure(
    SharedCoreConfiguration configuration,
  ) async {
    try {
      final client = await SharedCoreClient._create(configuration);
      _configuration = configuration;
      _client = client;
      return client;
    } finally {
      _configureInFlight = null;
      _configureInFlightConfiguration = null;
    }
  }

  static SharedCoreException _alreadyConfigured(
    bool inFlight,
  ) => SharedCoreException(
    localError: SharedCoreLocalError.alreadyConfigured,
    message: inFlight
        ? 'SharedCore is already being configured with a different configuration'
        : 'SharedCore has already been configured with a different configuration',
  );

  /// Clears the global client in debug and test builds.
  static void resetForTesting() {
    var assertionsEnabled = false;
    assert(() {
      assertionsEnabled = true;
      return true;
    }());
    if (!assertionsEnabled) {
      throw UnsupportedError(
        'SharedCore.resetForTesting is only available in debug/test builds',
      );
    }
    _configuration = null;
    _client = null;
    _configureInFlight = null;
    _configureInFlightConfiguration = null;
  }
}

/// Stateful Dart facade over the global opaque Rust `SharedCoreClient`.
class SharedCoreClient {
  SharedCoreClient._(
    this.configuration,
    this._inner, {
    required bool persistsPlatformSession,
    required String platform,
  }) : _persistsPlatformSession = persistsPlatformSession,
       _platform = platform;

  /// Configuration used to create this client.
  final SharedCoreConfiguration configuration;

  final bridge.RustSharedCoreClient _inner;
  final bool _persistsPlatformSession;
  final String _platform;
  _StoredSharedCoreSession? _lastPersistedSession;
  Future<void> _sessionPersistenceTail = Future<void>.value();
  SharedCorePurchaseCatalog? _purchaseCatalog;
  Future<SharedCorePurchaseCatalog>? _purchaseCatalogInFlight;

  static Future<SharedCoreClient> _create(
    SharedCoreConfiguration configuration,
  ) async {
    await SharedCore._initialize();
    final SharedCoreDeviceInfo collected;
    try {
      collected = await collectSharedCoreDeviceInfo(configuration.appId);
    } on PlatformException catch (error) {
      throw _exceptionFromPlatformException(error);
    } on Exception catch (error) {
      throw SharedCoreException(
        localError: SharedCoreLocalError.deviceInfoUnavailable,
        message: 'Failed to collect device information: $error',
      );
    }
    final deviceInfo = mergeSharedCoreDeviceInfo(
      collected,
      configuration.deviceOverrides,
    );
    final inner = await _guard(
      () => bridge.RustSharedCoreClient.create(
        configuration: _configurationToBridge(configuration, deviceInfo),
      ),
    );
    final client = SharedCoreClient._(
      configuration,
      inner,
      persistsPlatformSession:
          collected.platform == 'ios' || collected.platform == 'android',
      platform: collected.platform,
    );
    await client._bootstrapPlatformSession();
    return client;
  }

  /// Returns the device information currently held by Rust.
  Future<SharedCoreDeviceInfo> device() =>
      _guard(() async => _deviceFromBridge(await _inner.device()));

  /// Replaces the device information held by Rust.
  Future<void> setDevice(SharedCoreDeviceInfo device) =>
      _guard(() => _inner.setDevice(device: _deviceToBridge(device)));

  /// Returns the current account email.
  Future<String> get email => _guard(_inner.email);

  /// Reports whether the current session contains a non-blank email.
  Future<bool> get hasBindEmail => _guard(_inner.hasBindEmail);

  /// Logs out and replaces the current credential with a fresh anonymous session.
  Future<void> logout() async {
    Object? operationError;
    StackTrace? operationStackTrace;
    try {
      await _mapped(_inner.logout, SharedCoreAccountSnapshot.fromMap);
    } catch (error, stackTrace) {
      operationError = error;
      operationStackTrace = stackTrace;
    }

    // Logout is security-sensitive: a secure-store deletion failure must be
    // visible even when creating the replacement anonymous session also fails.
    await _persistPlatformSessionIfChanged();
    if (operationError != null) {
      Error.throwWithStackTrace(operationError, operationStackTrace!);
    }
  }

  /// Refreshes the current account snapshot.
  Future<SharedCoreAccountSnapshot> refreshAccount() => _mappedPersisting(
    _inner.refreshAccount,
    SharedCoreAccountSnapshot.fromMap,
  );

  /// Updates the password of the current account.
  ///
  /// Login and registration both use [login]; this is only for changing the
  /// password of an existing email account.
  Future<SharedCoreAccountSnapshot> updatePassword(String newPassword) async {
    _requireNonBlank(newPassword, 'New password is empty');
    return _mappedPersisting(
      () => _inner.updatePassword(newPassword: newPassword),
      SharedCoreAccountSnapshot.fromMap,
    );
  }

  /// Logs in or registers with email/password or a third-party token.
  Future<SharedCoreAccountSnapshot> login({
    String? email,
    String? password,
    String? threeToken,
  }) async {
    final hasEmail = !_isBlank(email);
    final hasPassword = !_isBlank(password);
    final hasThreeToken = !_isBlank(threeToken);
    final usesEmailCredentials = hasEmail && hasPassword && !hasThreeToken;
    final usesThreeToken = hasThreeToken && !hasEmail && !hasPassword;
    if (!usesEmailCredentials && !usesThreeToken) {
      throw const SharedCoreException(
        localError: SharedCoreLocalError.invalidArgument,
        message: 'Provide either email and password or threeToken',
      );
    }
    return _mappedPersisting(
      () => _inner.login(
        email: email,
        password: password,
        threeToken: threeToken,
      ),
      SharedCoreAccountSnapshot.fromMap,
    );
  }

  /// Uploads Singular attribution identifiers.
  Future<void> uploadUserDeviceIdentifiers(
    SharedCoreSingularIdentifiers identifiers,
  ) => _guardPersisting(
    () => _inner.uploadUserDeviceIdentifiers(
      identifiers: _identifiersToBridge(identifiers),
    ),
  );

  /// Exchanges a redemption code and reports whether the backend code is 200.
  Future<bool> exchangeCode(String code) async {
    _requireNonBlank(code, 'Exchange code is empty');
    return _guardPersisting(() => _inner.exchangeCode(code: code));
  }

  /// Loads home menus and modules.
  Future<SharedCoreHomeContent> loadHomeContent() =>
      _mappedPersisting(_inner.loadHomeContent, SharedCoreHomeContent.fromMap);

  /// Loads video templates.
  Future<List<SharedCoreTemplateItem>> loadVideoTemplateItems({
    int page = 1,
    int pageSize = 20,
    bool isHome = false,
  }) {
    _requirePositivePagination(page, pageSize);
    return _mappedListPersisting(
      () => _inner.loadVideoTemplateItems(
        page: page,
        pageSize: pageSize,
        isHome: isHome,
      ),
      SharedCoreTemplateItem.fromMap,
    );
  }

  /// Loads video templates by identifier.
  Future<List<SharedCoreTemplateItem>> loadVideoItems(List<int> ids) =>
      _mappedListPersisting(
        () => _inner.loadVideoItems(ids: ids),
        SharedCoreTemplateItem.fromMap,
      );

  /// Loads video generation history.
  Future<List<SharedCoreHistoryItem>> loadVideoHistoryItems({
    int page = 1,
    int pageSize = 20,
  }) {
    _requirePositivePagination(page, pageSize);
    return _mappedListPersisting(
      () => _inner.loadVideoHistoryItems(page: page, pageSize: pageSize),
      SharedCoreHistoryItem.fromMap,
    );
  }

  /// Loads image generation history.
  Future<List<SharedCoreHistoryItem>> loadImageHistoryItems({
    int page = 1,
    int pageSize = 20,
  }) {
    _requirePositivePagination(page, pageSize);
    return _mappedListPersisting(
      () => _inner.loadImageHistoryItems(page: page, pageSize: pageSize),
      SharedCoreHistoryItem.fromMap,
    );
  }

  /// Loads generation task status.
  Future<SharedCoreTaskInfo> loadGenerationTaskInfo(String promptId) =>
      _mappedPersisting(
        () => _inner.loadGenerationTaskInfo(promptId: promptId),
        SharedCoreTaskInfo.fromMap,
      );

  /// Uploads a local file.
  Future<SharedCoreUploadResult> uploadFile(String filePath) async {
    _requireNonBlank(filePath, 'Image path is empty');
    return _mappedPersisting(
      () => _inner.uploadFile(filePath: filePath),
      SharedCoreUploadResult.fromMap,
    );
  }

  /// Submits a video generation task.
  Future<SharedCoreGenerationSubmission> submitVideoTask(
    SharedCoreSubmitVideoOptions options,
  ) async {
    if (options.extendId < 0) {
      throw const SharedCoreException(
        localError: SharedCoreLocalError.invalidArgument,
        message: 'Video extension requires a positive extend ID',
      );
    }
    if (_isBlank(options.imagePath) && options.extendId == 0) {
      throw const SharedCoreException(
        localError: SharedCoreLocalError.invalidArgument,
        message: 'Image path is empty',
      );
    }
    return _mappedPersisting(
      () => _inner.submitVideoTask(options: _videoOptionsToBridge(options)),
      SharedCoreGenerationSubmission.fromMap,
    );
  }

  /// Extends an existing video using its backend task identifier.
  Future<SharedCoreGenerationSubmission> extendVideoTask({
    required SharedCoreHistoryItem source,
    String prompt = '',
    int definition = 0,
    int duration = 0,
    int variation = 0,
  }) {
    if (source.type != SharedCoreHistoryItemType.video) {
      throw const SharedCoreException(
        localError: SharedCoreLocalError.invalidArgument,
        message: 'Only video history items can be extended',
      );
    }
    if (source.canExtend == false) {
      throw const SharedCoreException(
        localError: SharedCoreLocalError.invalidArgument,
        message: 'The selected video cannot be extended',
      );
    }
    if (source.extendId <= 0) {
      throw const SharedCoreException(
        localError: SharedCoreLocalError.invalidArgument,
        message: 'The selected video does not contain a valid extend ID',
      );
    }
    return submitVideoTask(
      SharedCoreSubmitVideoOptions(
        prompt: prompt,
        extendId: source.extendId,
        definition: definition,
        duration: duration,
        variation: variation,
      ),
    );
  }

  /// Submits an image-to-image task from an uploaded image URL.
  Future<SharedCoreGenerationSubmission> submitImageTaskFromImageUrl({
    required String imageUrl,
    required SharedCoreImageStyle style,
  }) async {
    _requireNonBlank(imageUrl, 'Image URL is empty');
    return _mappedPersisting(
      () => _inner.submitWaveSpeedTask(imageUrl: imageUrl, styleId: style.id),
      SharedCoreGenerationSubmission.fromMap,
    );
  }

  /// Uploads a local image and submits an image-to-image task.
  Future<SharedCoreGenerationSubmission> submitImageTaskFromImagePath({
    required String imagePath,
    required SharedCoreImageStyle style,
  }) async {
    _requireNonBlank(imagePath, 'Image path is empty');
    return _mappedPersisting(
      () => _inner.submitWaveSpeedTaskWithImagePath(
        imagePath: imagePath,
        styleId: style.id,
      ),
      SharedCoreGenerationSubmission.fromMap,
    );
  }

  /// Deletes history items by identifier.
  Future<SharedCoreDeleteResult> deleteHistoryItems(List<int> ids) =>
      _mappedPersisting(
        () => _inner.deleteHistoryItems(ids: ids),
        SharedCoreDeleteResult.fromMap,
      );

  /// Loads purchase and subscription products.
  Future<SharedCorePurchaseCatalog> loadPurchaseCatalog() {
    final inFlight = _purchaseCatalogInFlight;
    if (inFlight != null) return inFlight;

    late final Future<SharedCorePurchaseCatalog> future;
    future =
        _mappedPersisting(
              _inner.loadPurchaseCatalog,
              SharedCorePurchaseCatalog.fromMap,
            )
            .then((catalog) {
              _purchaseCatalog = catalog;
              return catalog;
            })
            .whenComplete(() {
              if (identical(_purchaseCatalogInFlight, future)) {
                _purchaseCatalogInFlight = null;
              }
            });
    _purchaseCatalogInFlight = future;
    return future;
  }

  /// Verifies a one-time purchase or subscription for the current platform.
  ///
  /// On iOS, [purchaseData] is the Apple receipt data. On Android, it is the
  /// Google Play purchase token. The plugin selects the store and determines
  /// the purchase type from the v2 purchase catalog automatically. An unknown
  /// [productId] throws [SharedCoreLocalError.purchaseProductNotFound].
  Future<SharedCorePurchaseVerificationResult> verifyPurchase({
    required String productId,
    required String purchaseData,
  }) async {
    _requireNonBlank(productId, 'Product ID is empty');
    _requireNonBlank(purchaseData, 'Purchase data is empty');
    final normalizedProductId = productId.trim();
    final catalog = _purchaseCatalog ?? await loadPurchaseCatalog();
    final subscription = subscriptionStatusForProduct(
      catalog,
      normalizedProductId,
    );
    if (subscription == null) {
      throw SharedCoreException(
        localError: SharedCoreLocalError.purchaseProductNotFound,
        message: 'Product ID was not found in the v2 purchase catalog',
      );
    }
    final Future<String> Function() operation;
    switch (_platform) {
      case 'ios':
        operation = subscription
            ? () => _inner.verifyAppleSubscriptionResult(
                productId: normalizedProductId,
                receiptData: purchaseData,
              )
            : () => _inner.verifyApplePurchaseResult(
                productId: normalizedProductId,
                receiptData: purchaseData,
              );
        break;
      case 'android':
        operation = subscription
            ? () => _inner.verifyGoogleSubscriptionResult(
                productId: normalizedProductId,
                purchaseToken: purchaseData,
              )
            : () => _inner.verifyGooglePurchaseResult(
                productId: normalizedProductId,
                purchaseToken: purchaseData,
              );
        break;
      default:
        throw SharedCoreException(
          localError: SharedCoreLocalError.unsupportedPlatform,
          message: 'Purchase verification is not supported on $_platform',
        );
    }
    return _mappedPersisting(
      operation,
      SharedCorePurchaseVerificationResult.fromMap,
    );
  }

  /// Loads the backend sensitive-word list.
  Future<List<String>> loadSensitiveWords() =>
      _guardPersisting(_inner.loadSensitiveWords);

  Future<void> _bootstrapPlatformSession() async {
    if (!_persistsPlatformSession) return;
    final restored = await _platformStoreGuard(
      () =>
          _loadSharedCorePlatformSession(configuration.sessionStorageKeyPrefix),
    );
    _lastPersistedSession = restored;
    try {
      await _guard(() => _inner.bootstrap(accessToken: restored?.accessToken));
    } on SharedCoreException catch (error) {
      // Rust may have rejected and cleared a restored credential before an
      // anonymous fallback failed. Persist that state even on the error path
      // so an invalid token can never remain in secure storage.
      await _persistPlatformSessionIfChanged();
      final canRetryLater =
          restored != null &&
          (error.localError == SharedCoreLocalError.network ||
              error.localError == SharedCoreLocalError.timeout);
      if (!canRetryLater) rethrow;
      return;
    }
    await _persistPlatformSessionIfChanged();
  }

  Future<T> _guardPersisting<T>(Future<T> Function() operation) =>
      _persistAfter(_guard(operation));

  Future<T> _mappedPersisting<T>(
    Future<String> Function() operation,
    T Function(Map<String, Object?>) decode,
  ) => _persistAfter(_mapped(operation, decode));

  Future<List<T>> _mappedListPersisting<T>(
    Future<String> Function() operation,
    T Function(Map<String, Object?>) decode,
  ) => _persistAfter(_mappedList(operation, decode));

  Future<T> _persistAfter<T>(Future<T> operation) async {
    try {
      final result = await operation;
      await _persistPlatformSessionIfChanged();
      return result;
    } catch (error, stackTrace) {
      // This is a no-op when Session state did not change. If a real secure
      // write or deletion fails, surface that storage error instead of hiding
      // a potentially stale credential behind the original operation error.
      await _persistPlatformSessionIfChanged();
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _persistPlatformSessionIfChanged() {
    if (!_persistsPlatformSession) return Future<void>.value();
    final next = _sessionPersistenceTail.then(
      (_) => _persistPlatformSessionNow(),
    );
    _sessionPersistenceTail = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  Future<void> _persistPlatformSessionNow() async {
    final current = _storedSessionFromBridge(
      await _guard(_inner.sessionForPersistence),
    );
    if (_sameSession(current, _lastPersistedSession)) return;
    if (current.accessToken.trim().isEmpty) {
      await _platformStoreGuard(
        () => _clearSharedCorePlatformSession(
          configuration.sessionStorageKeyPrefix,
        ),
      );
      _lastPersistedSession = null;
      return;
    }
    await _platformStoreGuard(
      () => _saveSharedCorePlatformSession(
        configuration.sessionStorageKeyPrefix,
        current,
      ),
    );
    _lastPersistedSession = current;
  }
}

Future<T> _platformStoreGuard<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on PlatformException catch (error) {
    throw _exceptionFromPlatformException(error);
  } on Exception catch (error) {
    throw SharedCoreException(
      localError: SharedCoreLocalError.sessionStorageUnavailable,
      message: 'Failed to access the platform session store: $error',
    );
  }
}

bool _sameSession(
  _StoredSharedCoreSession current,
  _StoredSharedCoreSession? previous,
) =>
    previous != null &&
    current.accessToken == previous.accessToken &&
    current.userId == previous.userId &&
    current.email == previous.email;

Future<T> _guard<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on bridge.BridgeError catch (error) {
    final backendCode = error.backendCode;
    if (backendCode != null) {
      throw SharedCoreException(
        backendCode: backendCode,
        message: error.message,
        httpStatus: error.httpStatus,
        isRetryable: error.retryable,
      );
    }
    throw SharedCoreException(
      localError: _localErrorFromBridge(error.code),
      message: error.message,
      httpStatus: error.httpStatus,
      isRetryable: error.retryable,
    );
  } on FormatException catch (error) {
    throw SharedCoreException(
      localError: SharedCoreLocalError.parse,
      message: 'Invalid response data: ${error.message}',
    );
  } on TypeError catch (error) {
    throw SharedCoreException(
      localError: SharedCoreLocalError.parse,
      message: 'Invalid response data: $error',
    );
  } on SharedCoreException {
    rethrow;
  } on Exception catch (error) {
    throw SharedCoreException(
      localError: SharedCoreLocalError.unknown,
      message: 'SharedCore operation failed: $error',
    );
  }
}

SharedCoreLocalError _localErrorFromBridge(bridge.BridgeErrorCode code) =>
    switch (code) {
      bridge.BridgeErrorCode.cancelled => SharedCoreLocalError.cancelled,
      bridge.BridgeErrorCode.invalidArgument =>
        SharedCoreLocalError.invalidArgument,
      bridge.BridgeErrorCode.invalidState => SharedCoreLocalError.invalidState,
      bridge.BridgeErrorCode.network => SharedCoreLocalError.network,
      bridge.BridgeErrorCode.timeout => SharedCoreLocalError.timeout,
      bridge.BridgeErrorCode.unauthorized => SharedCoreLocalError.unauthorized,
      bridge.BridgeErrorCode.forbidden => SharedCoreLocalError.forbidden,
      bridge.BridgeErrorCode.notFound => SharedCoreLocalError.notFound,
      bridge.BridgeErrorCode.server => SharedCoreLocalError.server,
      bridge.BridgeErrorCode.parse => SharedCoreLocalError.parse,
      bridge.BridgeErrorCode.paymentVerificationFailed =>
        SharedCoreLocalError.paymentVerification,
      bridge.BridgeErrorCode.uploadFailed => SharedCoreLocalError.upload,
      bridge.BridgeErrorCode.downloadFailed => SharedCoreLocalError.download,
      bridge.BridgeErrorCode.cacheMiss => SharedCoreLocalError.cache,
      bridge.BridgeErrorCode.permissionDenied =>
        SharedCoreLocalError.permissionDenied,
      bridge.BridgeErrorCode.taskFailed => SharedCoreLocalError.task,
      bridge.BridgeErrorCode.ok ||
      bridge.BridgeErrorCode.unknown ||
      bridge.BridgeErrorCode.systemError ||
      bridge.BridgeErrorCode.membershipRequired ||
      bridge.BridgeErrorCode.insufficientBalance ||
      bridge.BridgeErrorCode.sensitiveContent => SharedCoreLocalError.unknown,
    };

SharedCoreException _exceptionFromPlatformException(PlatformException error) {
  final localError = switch (error.code) {
    'device_info_unavailable' => SharedCoreLocalError.deviceInfoUnavailable,
    'session_storage_unavailable' =>
      SharedCoreLocalError.sessionStorageUnavailable,
    _ => SharedCoreLocalError.platform,
  };
  return SharedCoreException(
    localError: localError,
    message: error.message ?? error.code,
  );
}

Future<T> _mapped<T>(
  Future<String> Function() operation,
  T Function(Map<String, Object?>) decode,
) => _guard(() async => decode(_decodeMap(await operation())));

Future<List<T>> _mappedList<T>(
  Future<String> Function() operation,
  T Function(Map<String, Object?>) decode,
) => _guard(() async {
  final values = jsonDecode(await operation());
  if (values is! List<Object?>) return <T>[];
  return values.map((value) => decode(_asMap(value))).toList(growable: false);
});

Map<String, Object?> _decodeMap(String source) => _asMap(jsonDecode(source));

Map<String, Object?> _asMap(Object? value) {
  if (value is! Map) return <String, Object?>{};
  return value.map((key, value) => MapEntry(key.toString(), value));
}

bridge.BridgeConfiguration _configurationToBridge(
  SharedCoreConfiguration value,
  SharedCoreDeviceInfo deviceInfo,
) => bridge.BridgeConfiguration(
  baseUrl: value.baseUrl,
  appId: value.appId,
  signSecret: value.signSecret,
  apiPathMode: _apiPathModeToBridge(value.apiPathMode),
  runtimeBundleId: deviceInfo.bundleId,
  testServerMode: value.testServerMode,
  requestTimeoutMillis: value.requestTimeout.inMilliseconds,
  jsonNoisePrefix: value.jsonNoisePrefix ?? '',
  jsonNoiseFieldCount: value.jsonNoiseFieldCount,
  device: _deviceToBridge(deviceInfo),
  http: bridge.BridgeHttpConfiguration(
    connectTimeoutMillis: value.http.connectTimeout.inMilliseconds,
    readTimeoutMillis: value.http.readTimeout.inMilliseconds,
    proxyUrl: value.http.proxyUrl,
    userAgent: value.http.userAgent,
    maxResponseBodyBytes: value.http.maxResponseBodyBytes,
  ),
);

bridge.BridgeApiPathMode _apiPathModeToBridge(SharedCoreApiPathMode mode) =>
    switch (mode) {
      SharedCoreApiPathMode.builtIn => bridge.BridgeApiPathMode.builtIn,
      SharedCoreApiPathMode.bundleDerived =>
        bridge.BridgeApiPathMode.bundleDerived,
    };

bridge.BridgeDeviceInfo _deviceToBridge(SharedCoreDeviceInfo value) =>
    bridge.BridgeDeviceInfo(
      appId: value.appId,
      udid: value.udid,
      appVersion: value.appVersion,
      platform: value.platform,
      deviceName: value.deviceName,
      systemName: value.systemName,
      osVersion: value.osVersion,
      language: value.language,
      templateLanguage: value.templateLanguage,
      timezone: value.timezone,
      inputLanguage: value.inputLanguage,
      vpn: value.vpn,
      hasWxOrQq: value.hasWeChatOrQQInstalled,
      networkOperator: value.networkOperator,
      simOperator: value.simOperator,
      installReferrer: value.installReferrer,
    );

SharedCoreDeviceInfo _deviceFromBridge(bridge.BridgeDeviceInfo value) =>
    SharedCoreDeviceInfo(
      appId: value.appId,
      udid: value.udid,
      appVersion: value.appVersion,
      platform: value.platform,
      deviceName: value.deviceName,
      systemName: value.systemName,
      osVersion: value.osVersion,
      language: value.language,
      templateLanguage: value.templateLanguage,
      timezone: value.timezone,
      inputLanguage: value.inputLanguage,
      vpn: value.vpn,
      hasWeChatOrQQInstalled: value.hasWxOrQq,
      networkOperator: value.networkOperator,
      simOperator: value.simOperator,
      installReferrer: value.installReferrer,
    );

_StoredSharedCoreSession _storedSessionFromBridge(bridge.BridgeSession value) =>
    _StoredSharedCoreSession(
      accessToken: value.accessToken,
      userId: value.userId,
      email: value.email,
    );

bridge.BridgeSingularIdentifiers _identifiersToBridge(
  SharedCoreSingularIdentifiers value,
) => bridge.BridgeSingularIdentifiers(
  sdid: value.sdid,
  idfa: value.idfa,
  idfv: value.idfv,
  aifa: value.aifa,
  asid: value.asid,
  amid: value.amid,
  oaid: value.oaid,
  andi: value.andi,
);

bridge.BridgeSubmitVideoOptions _videoOptionsToBridge(
  SharedCoreSubmitVideoOptions value,
) => bridge.BridgeSubmitVideoOptions(
  imagePath: value.imagePath,
  prompt: value.prompt,
  templateId: value.templateId,
  extendId: value.extendId,
  definition: value.definition,
  duration: value.duration,
  variation: value.variation,
);

bool _isBlank(String? value) => value == null || value.trim().isEmpty;

void _requireNonBlank(String value, String message) {
  if (value.trim().isNotEmpty) return;
  throw SharedCoreException(
    localError: SharedCoreLocalError.invalidArgument,
    message: message,
  );
}

void _requirePositivePagination(int page, int pageSize) {
  if (page > 0 && pageSize > 0) return;
  throw const SharedCoreException(
    localError: SharedCoreLocalError.invalidArgument,
    message: 'Page and pageSize must be greater than zero',
  );
}
