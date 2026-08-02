/// Local failures produced before, during, or after a backend request.
enum SharedCoreLocalError {
  /// The operation was cancelled.
  cancelled,

  /// A caller-supplied argument is invalid.
  invalidArgument,

  /// The SDK or operation is in an invalid state.
  invalidState,

  /// [SharedCore.configure] has not completed successfully.
  notConfigured,

  /// SharedCore was configured again with different settings.
  alreadyConfigured,

  /// A network transport failure occurred.
  network,

  /// A request or operation timed out.
  timeout,

  /// An HTTP response failed without a backend business error envelope.
  http,

  /// Data could not be encoded or decoded.
  parse,

  /// Purchase verification failed locally.
  paymentVerification,

  /// A file upload failed locally.
  upload,

  /// A file download failed locally.
  download,

  /// A required cached value was missing or expired.
  cache,

  /// The operation did not have the required permission.
  permissionDenied,

  /// A generation or polling task failed locally.
  task,

  /// The current platform does not support the operation.
  unsupportedPlatform,

  /// A product was not present in the v2 purchase catalog.
  purchaseProductNotFound,

  /// Native device information could not be collected.
  deviceInfoUnavailable,

  /// The native session store could not be read or written.
  sessionStorageUnavailable,

  /// An unclassified platform-channel failure occurred.
  platform,

  /// An unclassified local failure occurred.
  unknown,
}

/// Unified exception exposed by the handwritten Dart API.
///
/// A backend failure has a non-null [backendCode] and a null [localError]. A
/// local failure has a non-null [localError] and a null [backendCode].
class SharedCoreException implements Exception {
  /// Creates a backend or local SharedCore exception.
  const SharedCoreException({
    required this.message,
    this.backendCode,
    this.localError,
    this.httpStatus,
  }) : assert(
         (backendCode == null) != (localError == null),
         'Exactly one of backendCode and localError must be provided',
       );

  /// Backend response code, or null when the failure is local.
  final int? backendCode;

  /// Local error category, or null when the backend returned the failure.
  final SharedCoreLocalError? localError;

  /// Backend-provided message or local diagnostic message.
  final String message;

  /// HTTP status when one was available.
  final int? httpStatus;

  /// Whether this failure was returned by the backend business envelope.
  bool get isBackendError => backendCode != null;

  /// Whether this failure was produced locally by the SDK or platform.
  bool get isLocalError => localError != null;

  @override
  String toString() {
    final source = backendCode != null
        ? 'backendCode: $backendCode'
        : 'localError: ${localError!.name}';
    final status = httpStatus == null ? '' : ', httpStatus: $httpStatus';
    return 'SharedCoreException($source$status, message: $message)';
  }
}
