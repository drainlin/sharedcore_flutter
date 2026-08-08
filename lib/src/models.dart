class SharedCoreCreditBalance {
  const SharedCoreCreditBalance({
    required this.free,
    required this.paid,
    required this.total,
  });

  final int free;
  final int paid;
  final int total;

  factory SharedCoreCreditBalance.fromMap(Map<String, Object?> map) {
    return SharedCoreCreditBalance(
      free: _int(map['free']),
      paid: _int(map['paid']),
      total: _int(map['total']),
    );
  }
}

class SharedCoreReplacementApp {
  /// Creates a backend-controlled replacement application configuration.
  const SharedCoreReplacementApp({
    required this.downloadUrlString,
    required this.webUrlString,
    required this.isEnabled,
  });

  /// Download URL supplied by the backend.
  final String downloadUrlString;

  /// Web fallback URL supplied by the backend.
  final String webUrlString;

  /// Whether the backend explicitly enabled the replacement application.
  final bool isEnabled;

  /// Decodes a replacement application returned by the Rust core.
  factory SharedCoreReplacementApp.fromMap(Map<String, Object?> map) {
    return SharedCoreReplacementApp(
      downloadUrlString: _string(map['downloadUrlString']),
      webUrlString: _string(map['webUrlString']),
      isEnabled: _bool(map['isEnabled']),
    );
  }
}

enum SharedCoreMembershipStatus { unknown, neverSubscribed, active, inactive }

enum SharedCoreAccountRole { unknown, standard, review }

enum SharedCoreSubscriptionStatus {
  unknown,
  neverSubscribed,
  active,
  cancelled,
  expired,
}

class SharedCoreAccountSnapshot {
  const SharedCoreAccountSnapshot({
    required this.userId,
    this.email = '',
    required this.credits,
    required this.membership,
    required this.isPro,
    required this.wasPro,
    required this.freeCredits,
    required this.paidCredits,
    required this.totalCredits,
    required this.hasUser,
    required this.hasContactUs,
    required this.shouldShowContactUs,
    required this.isUnderReview,
    this.role = SharedCoreAccountRole.unknown,
    this.subscribeState = SharedCoreSubscriptionStatus.unknown,
    this.subscriptionExpirationTime,
    required this.subscriptionPlan,
    this.nextRefreshTime,
    required this.purchaseVideoUrlString,
    required this.activeUrlString,
    required this.contactUs,
    required this.isNewDevice,
    required this.replacementApp,
  });

  final String userId;
  final String email;
  final SharedCoreCreditBalance credits;
  final SharedCoreMembershipStatus membership;
  final bool isPro;
  final bool wasPro;
  final int freeCredits;
  final int paidCredits;
  final int totalCredits;
  final bool hasUser;
  final bool hasContactUs;
  final bool shouldShowContactUs;
  final bool isUnderReview;
  final SharedCoreAccountRole role;
  final SharedCoreSubscriptionStatus subscribeState;
  final int? subscriptionExpirationTime;
  final String subscriptionPlan;
  final int? nextRefreshTime;
  final String purchaseVideoUrlString;
  final String activeUrlString;
  final String contactUs;
  final bool isNewDevice;
  final SharedCoreReplacementApp replacementApp;

  bool get hasBindEmail => email.trim().isNotEmpty;

  factory SharedCoreAccountSnapshot.fromMap(Map<String, Object?> map) {
    return SharedCoreAccountSnapshot(
      userId: _string(map['userId']),
      email: _string(map['email']),
      credits: SharedCoreCreditBalance.fromMap(_map(map['credits'])),
      membership: _membershipStatus(map['membership']),
      isPro: _bool(map['isPro']),
      wasPro: _bool(map['wasPro']),
      freeCredits: _int(map['freeCredits']),
      paidCredits: _int(map['paidCredits']),
      totalCredits: _int(map['totalCredits']),
      hasUser: _bool(map['hasUser']),
      hasContactUs: _bool(map['hasContactUs']),
      shouldShowContactUs: _bool(map['shouldShowContactUs']),
      isUnderReview: _bool(map['isUnderReview']),
      role: _accountRole(map['role']),
      subscribeState: _subscriptionStatus(map['subscribeState']),
      subscriptionExpirationTime: _nullableInt(
        map['subscriptionExpirationTime'],
      ),
      subscriptionPlan: _string(map['subscriptionPlan']),
      nextRefreshTime: _nullableInt(map['nextRefreshTime']),
      purchaseVideoUrlString: _string(map['purchaseVideoUrlString']),
      activeUrlString: _string(map['activeUrlString']),
      contactUs: _string(map['contactUs']),
      isNewDevice: _bool(map['isNewDevice']),
      replacementApp: SharedCoreReplacementApp.fromMap(
        _map(map['replacementApp']),
      ),
    );
  }
}

class SharedCoreHomeMenu {
  const SharedCoreHomeMenu({required this.title});

  final String title;

  factory SharedCoreHomeMenu.fromMap(Map<String, Object?> map) {
    return SharedCoreHomeMenu(title: _string(map['title']));
  }
}

class SharedCoreHomeModule {
  const SharedCoreHomeModule({
    required this.title,
    required this.moduleName,
    required this.paramIds,
  });

  final String title;
  final String moduleName;
  final List<int> paramIds;

  factory SharedCoreHomeModule.fromMap(Map<String, Object?> map) {
    return SharedCoreHomeModule(
      title: _string(map['title']),
      moduleName: _string(map['moduleName']),
      paramIds: _intList(map['paramIds']),
    );
  }
}

class SharedCoreHomeContent {
  const SharedCoreHomeContent({
    required this.menuList,
    required this.menuModuleMap,
  });

  final List<SharedCoreHomeMenu> menuList;
  final Map<String, List<SharedCoreHomeModule>> menuModuleMap;

  factory SharedCoreHomeContent.fromMap(Map<String, Object?> map) {
    final modules = <String, List<SharedCoreHomeModule>>{};
    for (final entry in _map(map['menuModuleMap']).entries) {
      modules[entry.key] = _list(entry.value)
          .map((item) => SharedCoreHomeModule.fromMap(_map(item)))
          .toList(growable: false);
    }
    return SharedCoreHomeContent(
      menuList: _list(map['menuList'])
          .map((item) => SharedCoreHomeMenu.fromMap(_map(item)))
          .toList(growable: false),
      menuModuleMap: modules,
    );
  }
}

class SharedCoreTemplateItem {
  const SharedCoreTemplateItem({
    required this.templateId,
    required this.title,
    required this.thumbUrl,
    required this.coveringUrl,
    required this.videoUrl,
    required this.favoriteCount,
    required this.isVipOnly,
    required this.prompt,
    required this.author,
  });

  final int templateId;
  final String title;
  final String thumbUrl;
  final String coveringUrl;
  final String videoUrl;
  final int favoriteCount;
  final bool isVipOnly;
  final String prompt;
  final String author;

  factory SharedCoreTemplateItem.fromMap(Map<String, Object?> map) {
    return SharedCoreTemplateItem(
      templateId: _int(map['templateId']),
      title: _string(map['title']),
      thumbUrl: _string(map['thumbUrl']),
      coveringUrl: _string(map['coveringUrl']),
      videoUrl: _string(map['videoUrl']),
      favoriteCount: _int(map['favoriteCount']),
      isVipOnly: _bool(map['isVipOnly'] ?? map['vipOnly']),
      prompt: _string(map['prompt']),
      author: _string(map['author']),
    );
  }
}

enum SharedCoreHistoryItemType { unknown, image, video }

class SharedCoreHistoryItem {
  const SharedCoreHistoryItem({
    required this.type,
    required this.recordId,
    this.extendId = 0,
    required this.title,
    required this.coveringUrl,
    required this.originUrl,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.styleId,
    this.canExtend,
  });

  final SharedCoreHistoryItemType type;

  /// Backend history-record identifier used by deletion APIs.
  final int recordId;

  /// Source task identifier used only when extending this video.
  final int extendId;

  final String title;
  final String coveringUrl;
  final String originUrl;
  final String reason;
  final SharedCoreTaskStatus status;
  final int createdAt;
  final int styleId;
  final bool? canExtend;

  factory SharedCoreHistoryItem.fromMap(Map<String, Object?> map) {
    return SharedCoreHistoryItem(
      type: _historyItemType(map['type']),
      recordId: _int(map['recordId']),
      extendId: _int(map['extendId']),
      title: _string(map['title']),
      coveringUrl: _string(map['coveringUrl']),
      originUrl: _string(map['originUrl']),
      reason: _string(map['reason']),
      status: _taskStatus(map['status'] ?? map['stateCode']),
      createdAt: _int(map['createdAt']),
      styleId: _int(map['styleId']),
      canExtend: _nullableBool(map['canExtend']),
    );
  }
}

enum SharedCoreTaskStatus { unknown, queued, running, succeeded, failed }

class SharedCoreTaskInfo {
  const SharedCoreTaskInfo({
    required this.promptId,
    required this.status,
    required this.ids,
    required this.originUrls,
  });

  final String promptId;
  final SharedCoreTaskStatus status;
  final List<int> ids;
  final List<String> originUrls;

  factory SharedCoreTaskInfo.fromMap(Map<String, Object?> map) {
    return SharedCoreTaskInfo(
      promptId: _string(map['promptId']),
      status: _taskStatus(map['status'] ?? map['stateCode']),
      ids: _intList(map['ids']),
      originUrls: _stringList(map['originUrls']),
    );
  }
}

class SharedCoreUploadResult {
  const SharedCoreUploadResult({required this.url});

  final String url;

  factory SharedCoreUploadResult.fromMap(Map<String, Object?> map) {
    return SharedCoreUploadResult(url: _string(map['url']));
  }
}

class SharedCoreGenerationSubmission {
  const SharedCoreGenerationSubmission({required this.promptId});

  final String promptId;

  factory SharedCoreGenerationSubmission.fromMap(Map<String, Object?> map) {
    return SharedCoreGenerationSubmission(promptId: _string(map['promptId']));
  }
}

class SharedCoreDeleteResult {
  const SharedCoreDeleteResult({required this.isDeleted});

  final bool isDeleted;

  factory SharedCoreDeleteResult.fromMap(Map<String, Object?> map) {
    return SharedCoreDeleteResult(
      isDeleted: _bool(map['isDeleted'] ?? map['deleted']),
    );
  }
}

class SharedCorePurchaseItem {
  const SharedCorePurchaseItem({
    required this.itemId,
    required this.price,
    required this.amount,
    required this.giftAmount,
    required this.productId,
    required this.type,
    required this.pageType,
    required this.cycle,
    required this.isShow,
    required this.subscriptionPeriod,
    required this.freeTryDays,
  });

  final int itemId;
  final double price;
  final int amount;
  final int giftAmount;
  final String productId;
  final int type;
  final int pageType;
  final int cycle;
  final bool isShow;
  final String subscriptionPeriod;
  final int freeTryDays;

  factory SharedCorePurchaseItem.fromMap(Map<String, Object?> map) {
    return SharedCorePurchaseItem(
      itemId: _int(map['itemId']),
      price: _double(map['price']),
      amount: _int(map['amount']),
      giftAmount: _int(map['giftAmount']),
      productId: _string(map['productId']),
      type: _int(map['type']),
      pageType: _int(map['pageType']),
      cycle: _int(map['cycle']),
      isShow: _nullableBool(map['isShow']) ?? false,
      subscriptionPeriod: _string(map['subscriptionPeriod']),
      freeTryDays: _int(map['freeTryDays']),
    );
  }
}

class SharedCorePurchaseCatalog {
  const SharedCorePurchaseCatalog({
    required this.schemaVersion,
    required this.creditPagePurchaseItems,
    required this.creditPageSubscribeItems,
    this.subscribePageTrialItem,
    this.subscribePageWeeklyItem,
    this.subscribePageYearlyItem,
    this.discountPageDiscountItem,
    this.secretPageSecretItem,
  });

  final int schemaVersion;

  /// creditPage.purchaseList. The only one-time purchase items in this catalog.
  final List<SharedCorePurchaseItem> creditPagePurchaseItems;

  /// creditPage.subscribeList. Subscription items shown on the credit page.
  final List<SharedCorePurchaseItem> creditPageSubscribeItems;

  /// subscribePage.trial subscription item.
  final SharedCorePurchaseItem? subscribePageTrialItem;

  /// subscribePage.weekly subscription item.
  final SharedCorePurchaseItem? subscribePageWeeklyItem;

  /// subscribePage.yearly subscription item.
  final SharedCorePurchaseItem? subscribePageYearlyItem;

  /// discountPage.discount subscription item.
  final SharedCorePurchaseItem? discountPageDiscountItem;

  /// secretPage.secret subscription item.
  final SharedCorePurchaseItem? secretPageSecretItem;

  factory SharedCorePurchaseCatalog.fromMap(Map<String, Object?> map) {
    List<SharedCorePurchaseItem> items(String key) {
      return _list(map[key])
          .map((item) => SharedCorePurchaseItem.fromMap(_map(item)))
          .toList(growable: false);
    }

    SharedCorePurchaseItem? item(String key) {
      final value = _map(map[key]);
      if (value.isEmpty) return null;
      final purchaseItem = SharedCorePurchaseItem.fromMap(value);
      if (purchaseItem.itemId == 0 && purchaseItem.productId.isEmpty) {
        return null;
      }
      return purchaseItem;
    }

    return SharedCorePurchaseCatalog(
      schemaVersion: _int(map['schemaVersion']),
      creditPagePurchaseItems: items('creditPagePurchaseItems'),
      creditPageSubscribeItems: items('creditPageSubscribeItems'),
      subscribePageTrialItem: item('subscribePageTrialItem'),
      subscribePageWeeklyItem: item('subscribePageWeeklyItem'),
      subscribePageYearlyItem: item('subscribePageYearlyItem'),
      discountPageDiscountItem: item('discountPageDiscountItem'),
      secretPageSecretItem: item('secretPageSecretItem'),
    );
  }
}

class SharedCorePurchaseVerificationResult {
  /// Creates the normalized result of backend purchase verification.
  const SharedCorePurchaseVerificationResult({
    required this.isSuccess,
    required this.isTrial,
    required this.status,
  });

  /// Whether the backend accepted the purchase or subscription.
  final bool isSuccess;

  /// Whether the verified subscription is currently a trial.
  final bool isTrial;

  /// Backend verification status text.
  final String status;

  /// Decodes a purchase verification result returned by the Rust core.
  factory SharedCorePurchaseVerificationResult.fromMap(
    Map<String, Object?> map,
  ) {
    return SharedCorePurchaseVerificationResult(
      isSuccess: _bool(map['isSuccess'] ?? map['success']),
      isTrial: _bool(map['isTrial']),
      status: _string(map['status']),
    );
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, Object?>{};
}

List<Object?> _list(Object? value) {
  if (value is List) return value;
  return const <Object?>[];
}

List<int> _intList(Object? value) {
  return _list(value).map(_int).toList(growable: false);
}

List<String> _stringList(Object? value) {
  return _list(value).map(_string).toList(growable: false);
}

String _string(Object? value) => value is String ? value : '';

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

double _double(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return 0;
}

bool _bool(Object? value) => value == true;

bool? _nullableBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value.toInt() != 0;
  return null;
}

SharedCoreTaskStatus _taskStatus(Object? value) {
  if (value is String) {
    switch (value.toLowerCase().replaceAll('-', '_')) {
      case 'queued':
      case 'queue':
      case 'pending':
      case 'waiting':
      case 'created':
        return SharedCoreTaskStatus.queued;
      case 'running':
      case 'processing':
      case 'generating':
      case 'progress':
      case 'in_progress':
        return SharedCoreTaskStatus.running;
      case 'succeeded':
      case 'success':
      case 'completed':
      case 'complete':
      case 'finished':
      case 'done':
        return SharedCoreTaskStatus.succeeded;
      case 'failed':
      case 'failure':
      case 'error':
      case 'cancelled':
      case 'canceled':
        return SharedCoreTaskStatus.failed;
    }
  }
  final code = value is num ? value.toInt() : null;
  switch (code) {
    case 10:
      return SharedCoreTaskStatus.queued;
    case 20:
      return SharedCoreTaskStatus.running;
    case 30:
      return SharedCoreTaskStatus.succeeded;
    case 2:
      return SharedCoreTaskStatus.failed;
    default:
      return SharedCoreTaskStatus.unknown;
  }
}

SharedCoreMembershipStatus _membershipStatus(Object? value) {
  switch (value) {
    case 'neverSubscribed':
      return SharedCoreMembershipStatus.neverSubscribed;
    case 'active':
      return SharedCoreMembershipStatus.active;
    case 'inactive':
      return SharedCoreMembershipStatus.inactive;
    default:
      return SharedCoreMembershipStatus.unknown;
  }
}

SharedCoreAccountRole _accountRole(Object? value) {
  if (value is num) {
    return value.toInt() == 7
        ? SharedCoreAccountRole.review
        : SharedCoreAccountRole.standard;
  }
  switch (value) {
    case 'standard':
      return SharedCoreAccountRole.standard;
    case 'review':
      return SharedCoreAccountRole.review;
    default:
      return SharedCoreAccountRole.unknown;
  }
}

SharedCoreSubscriptionStatus _subscriptionStatus(Object? value) {
  switch (value) {
    case 'neverSubscribed':
    case 0:
      return SharedCoreSubscriptionStatus.neverSubscribed;
    case 'active':
    case 2000:
      return SharedCoreSubscriptionStatus.active;
    case 'cancelled':
    case 2010:
      return SharedCoreSubscriptionStatus.cancelled;
    case 'expired':
    case 2020:
      return SharedCoreSubscriptionStatus.expired;
    default:
      return SharedCoreSubscriptionStatus.unknown;
  }
}

SharedCoreHistoryItemType _historyItemType(Object? value) {
  switch (value) {
    case 'image':
      return SharedCoreHistoryItemType.image;
    case 'video':
      return SharedCoreHistoryItemType.video;
    default:
      return SharedCoreHistoryItemType.unknown;
  }
}
