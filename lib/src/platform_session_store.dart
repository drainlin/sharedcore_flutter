part of 'client.dart';

/// Internal credential snapshot exchanged only between Rust and native secure storage.
class _StoredSharedCoreSession {
  const _StoredSharedCoreSession({
    required this.accessToken,
    this.userId = '',
    this.email = '',
  });

  final String accessToken;
  final String userId;
  final String email;
}

const MethodChannel _sessionStoreChannel = MethodChannel(
  'sharedcore_flutter/device_info',
);

/// Restores the session persisted by the platform plugin.
Future<_StoredSharedCoreSession?> _loadSharedCorePlatformSession(
  String prefix,
) async {
  final values = await _sessionStoreChannel.invokeMapMethod<String, Object?>(
    'loadSession',
    <String, Object?>{'prefix': prefix},
  );
  final accessToken = _string(values?['accessToken']);
  if (accessToken.trim().isEmpty) return null;
  return _StoredSharedCoreSession(
    accessToken: accessToken,
    userId: _string(values?['userId']),
    email: _string(values?['email']),
  );
}

/// Persists a session using the configured platform storage namespace.
Future<void> _saveSharedCorePlatformSession(
  String prefix,
  _StoredSharedCoreSession session,
) => _sessionStoreChannel.invokeMethod<void>('saveSession', <String, Object?>{
  'prefix': prefix,
  'accessToken': session.accessToken,
  'userId': session.userId,
  'email': session.email,
});

/// Clears the session persisted by the platform plugin.
Future<void> _clearSharedCorePlatformSession(String prefix) =>
    _sessionStoreChannel.invokeMethod<void>('clearSession', <String, Object?>{
      'prefix': prefix,
    });

String _string(Object? value) => value is String ? value : '';
