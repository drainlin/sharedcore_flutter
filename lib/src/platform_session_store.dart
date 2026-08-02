import 'package:flutter/services.dart';

import 'configuration.dart';

const MethodChannel _sessionStoreChannel = MethodChannel(
  'sharedcore_flutter/device_info',
);

/// Restores the session persisted by the platform plugin.
Future<SharedCoreSession?> loadSharedCorePlatformSession(String prefix) async {
  final values = await _sessionStoreChannel.invokeMapMethod<String, Object?>(
    'loadSession',
    <String, Object?>{'prefix': prefix},
  );
  final accessToken = _string(values?['accessToken']);
  if (accessToken.trim().isEmpty) return null;
  return SharedCoreSession(
    accessToken: accessToken,
    userId: _string(values?['userId']),
    email: _string(values?['email']),
  );
}

/// Persists a session using the configured platform storage namespace.
Future<void> saveSharedCorePlatformSession(
  String prefix,
  SharedCoreSession session,
) => _sessionStoreChannel.invokeMethod<void>('saveSession', <String, Object?>{
  'prefix': prefix,
  'accessToken': session.accessToken,
  'userId': session.userId,
  'email': session.email,
});

/// Clears the session persisted by the platform plugin.
Future<void> clearSharedCorePlatformSession(String prefix) =>
    _sessionStoreChannel.invokeMethod<void>('clearSession', <String, Object?>{
      'prefix': prefix,
    });

String _string(Object? value) => value is String ? value : '';
