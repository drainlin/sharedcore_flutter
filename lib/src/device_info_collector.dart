import 'package:flutter/services.dart';

import 'configuration.dart';

const MethodChannel _deviceInfoChannel = MethodChannel(
  'sharedcore_flutter/device_info',
);

/// Collects device information from the host Android or iOS application.
Future<SharedCoreDeviceInfo> collectSharedCoreDeviceInfo(String appId) async {
  final values = await _deviceInfoChannel.invokeMapMethod<String, Object?>(
    'collectDeviceInfo',
    <String, Object?>{'appId': appId},
  );
  if (values == null) {
    throw PlatformException(
      code: 'device_info_unavailable',
      message: 'The platform returned no device information.',
    );
  }

  return SharedCoreDeviceInfo(
    appId: _string(values['appId']),
    bundleId: _string(values['bundleId']),
    udid: _string(values['udid']),
    appVersion: _string(values['appVersion']),
    platform: _string(values['platform']),
    deviceName: _string(values['deviceName']),
    systemName: _string(values['systemName']),
    osVersion: _string(values['osVersion']),
    language: _string(values['language']),
    templateLanguage: _string(values['templateLanguage']),
    timezone: _string(values['timezone']),
    inputLanguage: _string(values['inputLanguage']),
    vpn: values['vpn'] == true,
    hasWeChatOrQQInstalled: values['hasWxOrQq'] == true,
    networkOperator: _string(values['networkOperator']),
    simOperator: _string(values['simOperator']),
    installReferrer: _string(values['installReferrer']),
  );
}

/// Merges automatically collected values with explicit configuration values.
///
/// Non-null values supplied by the caller take precedence.
SharedCoreDeviceInfo mergeSharedCoreDeviceInfo(
  SharedCoreDeviceInfo collected,
  SharedCoreDeviceOverrides overrides,
) => SharedCoreDeviceInfo(
  appId: collected.appId,
  bundleId: collected.bundleId,
  udid: collected.udid,
  appVersion: collected.appVersion,
  platform: collected.platform,
  deviceName: collected.deviceName,
  systemName: collected.systemName,
  osVersion: collected.osVersion,
  language: collected.language,
  templateLanguage: _preferConfigured(
    overrides.templateLanguage,
    collected.templateLanguage,
  ),
  timezone: collected.timezone,
  inputLanguage: collected.inputLanguage,
  vpn: overrides.vpn ?? collected.vpn,
  hasWeChatOrQQInstalled:
      overrides.hasWeChatOrQQInstalled ?? collected.hasWeChatOrQQInstalled,
  networkOperator: _preferConfigured(
    overrides.networkOperator,
    collected.networkOperator,
  ),
  simOperator: _preferConfigured(overrides.simOperator, collected.simOperator),
  installReferrer: _preferConfigured(
    overrides.installReferrer,
    collected.installReferrer,
  ),
);

String _string(Object? value) => value is String ? value : '';

String _preferConfigured(String? configured, String collected) =>
    configured ?? collected;
