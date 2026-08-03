/// Selects how production API endpoint paths are resolved.
enum SharedCoreApiPathMode {
  /// Uses the real API endpoint paths built into the plugin.
  builtIn,

  /// Derives bundle-specific endpoint paths and JSON noise settings in Rust.
  bundleDerived,
}

/// Optional values that override automatically collected device information.
class SharedCoreDeviceOverrides {
  /// Creates device-information overrides.
  const SharedCoreDeviceOverrides({
    this.vpn,
    this.hasWeChatOrQQInstalled,
    this.networkOperator,
    this.simOperator,
    this.templateLanguage,
    this.installReferrer,
  });

  /// Overrides whether the device currently has an active VPN connection.
  final bool? vpn;

  /// Overrides whether WeChat or QQ is installed.
  final bool? hasWeChatOrQQInstalled;

  /// Active network operator.
  final String? networkOperator;

  /// Installed SIM operator.
  final String? simOperator;

  /// Language used to select backend templates.
  final String? templateLanguage;

  /// Install or acquisition referrer.
  final String? installReferrer;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedCoreDeviceOverrides &&
          runtimeType == other.runtimeType &&
          vpn == other.vpn &&
          hasWeChatOrQQInstalled == other.hasWeChatOrQQInstalled &&
          networkOperator == other.networkOperator &&
          simOperator == other.simOperator &&
          templateLanguage == other.templateLanguage &&
          installReferrer == other.installReferrer;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    vpn,
    hasWeChatOrQQInstalled,
    networkOperator,
    simOperator,
    templateLanguage,
    installReferrer,
  );
}

/// Complete device information automatically collected for the Rust core.
class SharedCoreDeviceInfo {
  /// Creates complete device information using empty optional backend fields.
  const SharedCoreDeviceInfo({
    this.appId = '',
    this.bundleId = '',
    this.udid = '',
    this.appVersion = '',
    this.platform = '',
    this.deviceName = '',
    this.systemName = '',
    this.osVersion = '',
    this.language = '',
    this.templateLanguage = '',
    this.timezone = '',
    this.inputLanguage = '',
    this.vpn = false,
    this.hasWeChatOrQQInstalled = false,
    this.networkOperator = '',
    this.simOperator = '',
    this.installReferrer = '',
  });

  /// Backend application identifier; an empty value inherits the client app ID.
  final String appId;

  /// Runtime Android package name or iOS bundle identifier.
  final String bundleId;

  /// Stable installation or device identifier collected by the plugin.
  final String udid;

  /// Application version sent to the backend.
  final String appVersion;

  /// Platform name, normally `android` or `ios`.
  final String platform;

  /// Human-readable device name.
  final String deviceName;

  /// Operating-system family name.
  final String systemName;

  /// Operating-system version.
  final String osVersion;

  /// Current application language.
  final String language;

  /// Language used to select backend templates.
  final String templateLanguage;

  /// Current timezone identifier.
  final String timezone;

  /// Current input-method language.
  final String inputLanguage;

  /// Whether the device currently has an active VPN connection.
  final bool vpn;

  /// Whether WeChat or QQ is installed.
  final bool hasWeChatOrQQInstalled;

  /// Active network operator.
  final String networkOperator;

  /// Installed SIM operator.
  final String simOperator;

  /// Install or acquisition referrer.
  final String installReferrer;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedCoreDeviceInfo &&
          appId == other.appId &&
          bundleId == other.bundleId &&
          udid == other.udid &&
          appVersion == other.appVersion &&
          platform == other.platform &&
          deviceName == other.deviceName &&
          systemName == other.systemName &&
          osVersion == other.osVersion &&
          language == other.language &&
          templateLanguage == other.templateLanguage &&
          timezone == other.timezone &&
          inputLanguage == other.inputLanguage &&
          vpn == other.vpn &&
          hasWeChatOrQQInstalled == other.hasWeChatOrQQInstalled &&
          networkOperator == other.networkOperator &&
          simOperator == other.simOperator &&
          installReferrer == other.installReferrer;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    appId,
    bundleId,
    udid,
    appVersion,
    platform,
    deviceName,
    systemName,
    osVersion,
    language,
    templateLanguage,
    timezone,
    inputLanguage,
    vpn,
    hasWeChatOrQQInstalled,
    networkOperator,
    simOperator,
    installReferrer,
  ]);
}

/// HTTP transport settings owned by Rust.
class SharedCoreHttpConfiguration {
  /// Creates Rust reqwest/rustls transport settings.
  const SharedCoreHttpConfiguration({
    this.connectTimeout = const Duration(seconds: 60),
    this.readTimeout = const Duration(seconds: 60),
    this.proxyUrl,
    this.userAgent = 'sharedcore_flutter/0.3.0',
    this.maxResponseBodyBytes,
  });

  /// Maximum time allowed to establish a connection.
  final Duration connectTimeout;

  /// Maximum idle time between successful response reads.
  final Duration readTimeout;

  /// Explicit HTTP(S) proxy URL, or `null` for no proxy.
  final String? proxyUrl;

  /// User-Agent used by requests that do not override it.
  final String userAgent;

  /// Optional maximum response body size in bytes.
  final int? maxResponseBodyBytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedCoreHttpConfiguration &&
          connectTimeout == other.connectTimeout &&
          readTimeout == other.readTimeout &&
          proxyUrl == other.proxyUrl &&
          userAgent == other.userAgent &&
          maxResponseBodyBytes == other.maxResponseBodyBytes;

  @override
  int get hashCode => Object.hash(
    connectTimeout,
    readTimeout,
    proxyUrl,
    userAgent,
    maxResponseBodyBytes,
  );
}

/// Runtime configuration used to create one Rust SharedCore client.
class SharedCoreConfiguration {
  /// Creates a complete configuration for `SharedCore.configure`.
  const SharedCoreConfiguration({
    this.baseUrl = '',
    required this.appId,
    this.deviceOverrides = const SharedCoreDeviceOverrides(),
    this.signSecret,
    this.sessionStorageKeyPrefix = 'SharedCore',
    this.apiPathMode = SharedCoreApiPathMode.builtIn,
    this.testServerMode = false,
    this.requestTimeout = const Duration(seconds: 60),
    this.jsonNoisePrefix,
    this.jsonNoiseFieldCount = 0,
    this.http = const SharedCoreHttpConfiguration(),
  });

  /// Backend base URL; ignored when [testServerMode] is true.
  final String baseUrl;

  /// Backend application identifier.
  final String appId;

  /// Optional values that override or supplement automatic device collection.
  final SharedCoreDeviceOverrides deviceOverrides;

  /// Secret used by the request signer, or `null` for the Rust-embedded value.
  final String? signSecret;

  /// Prefix used by Android and iOS to isolate the persisted session.
  ///
  /// On iOS, the default preserves the original plugin's UserDefaults keys.
  final String sessionStorageKeyPrefix;

  /// Selects the production API path strategy.
  ///
  /// Bundle-derived mode also derives the JSON noise prefix and fixes its count at 20.
  /// [testServerMode] overrides this value and always uses built-in real paths.
  final SharedCoreApiPathMode apiPathMode;

  /// Whether to use the Rust core's built-in test server URL and paths.
  final bool testServerMode;

  /// Overall API request timeout.
  final Duration requestTimeout;

  /// Prefix used by noisy JSON responses in real-path or mapped-path mode.
  ///
  /// This value is ignored when [apiPathMode] is
  /// [SharedCoreApiPathMode.bundleDerived]; the
  /// Rust core then derives a bundle-specific prefix automatically.
  final String? jsonNoisePrefix;

  /// Number of noise fields in real-path or mapped-path mode.
  ///
  /// This value is ignored when [apiPathMode] is
  /// [SharedCoreApiPathMode.bundleDerived]; the
  /// Rust core then always removes 20 derived-prefix noise fields.
  final int jsonNoiseFieldCount;

  /// Rust-owned HTTP transport settings.
  final SharedCoreHttpConfiguration http;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedCoreConfiguration &&
          baseUrl == other.baseUrl &&
          appId == other.appId &&
          deviceOverrides == other.deviceOverrides &&
          signSecret == other.signSecret &&
          sessionStorageKeyPrefix == other.sessionStorageKeyPrefix &&
          apiPathMode == other.apiPathMode &&
          testServerMode == other.testServerMode &&
          requestTimeout == other.requestTimeout &&
          jsonNoisePrefix == other.jsonNoisePrefix &&
          jsonNoiseFieldCount == other.jsonNoiseFieldCount &&
          http == other.http;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    baseUrl,
    appId,
    deviceOverrides,
    signSecret,
    sessionStorageKeyPrefix,
    apiPathMode,
    testServerMode,
    requestTimeout,
    jsonNoisePrefix,
    jsonNoiseFieldCount,
    http,
  ]);
}

/// Session state held by one Rust client.
class SharedCoreSession {
  /// Creates explicit session state.
  const SharedCoreSession({
    required this.accessToken,
    this.userId = '',
    this.email = '',
  });

  /// Backend access token.
  final String accessToken;

  /// Backend user identifier.
  final String userId;

  /// Email associated with the current account.
  final String email;
}

/// Singular attribution identifiers uploaded for an authenticated user.
class SharedCoreSingularIdentifiers {
  /// Creates an identifier set; empty values are preserved for the Rust core.
  const SharedCoreSingularIdentifiers({
    this.sdid = '',
    this.idfa = '',
    this.idfv = '',
    this.aifa = '',
    this.asid = '',
    this.amid = '',
    this.oaid = '',
    this.andi = '',
  });

  /// Singular device identifier.
  final String sdid;

  /// Apple advertising identifier.
  final String idfa;

  /// Apple vendor identifier.
  final String idfv;

  /// Android advertising identifier.
  final String aifa;

  /// Singular attribution identifier.
  final String asid;

  /// Amazon advertising identifier.
  final String amid;

  /// Open Anonymous Device Identifier.
  final String oaid;

  /// Android device identifier.
  final String andi;
}

/// Options forwarded to Rust's `submit_video_task` API.
class SharedCoreSubmitVideoOptions {
  /// Creates video generation options.
  const SharedCoreSubmitVideoOptions({
    this.imagePath = '',
    this.prompt = '',
    this.templateId = 0,
    this.videoExtend = 0,
    this.oldTaskId = 0,
    this.definition = 0,
    this.duration = 0,
    this.variation = 0,
  });

  /// Local source image path.
  final String imagePath;

  /// Generation prompt.
  final String prompt;

  /// Backend template identifier.
  final int templateId;

  /// Existing task extension mode.
  final int videoExtend;

  /// Existing task identifier.
  final int oldTaskId;

  /// Requested output definition.
  final int definition;

  /// Requested output duration.
  final int duration;

  /// Requested variation count or mode.
  final int variation;
}

/// Styles supported by image-to-image generation tasks.
enum SharedCoreImageStyle {
  /// Chest — Moderate (`styleId = 1`).
  chestModerate(1),

  /// Chest — Busty (`styleId = 2`).
  chestBusty(2),

  /// Butt — Curvy (`styleId = 3`).
  buttCurvy(3),

  /// Butt — Thick (`styleId = 4`).
  buttThick(4),

  /// Slim Waist — Trim (`styleId = 5`).
  slimWaistTrim(5),

  /// Slim Waist — Slim (`styleId = 6`).
  slimWaistSlim(6),

  /// Abs Define — Toned (`styleId = 7`).
  absDefineToned(7),

  /// Abs Define — Ripped (`styleId = 8`).
  absDefineRipped(8);

  const SharedCoreImageStyle(this.id);

  /// Numeric style identifier sent to the backend.
  final int id;
}
