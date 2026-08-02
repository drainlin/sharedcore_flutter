import 'models.dart';

/// Returns whether [productId] is a subscription according to the v2 catalog.
///
/// A product in `creditPage.purchaseList` always wins and returns `false`.
/// Other known products return `true`; an unknown product returns `null`.
bool? subscriptionStatusForProduct(
  SharedCorePurchaseCatalog catalog,
  String productId,
) {
  bool matches(SharedCorePurchaseItem item) => item.productId == productId;

  if (catalog.creditPagePurchaseItems.any(matches)) return false;
  if (catalog.creditPageSubscribeItems.any(matches)) return true;
  final optionalSubscriptionItems = <SharedCorePurchaseItem?>[
    catalog.subscribePageTrialItem,
    catalog.subscribePageWeeklyItem,
    catalog.subscribePageYearlyItem,
    catalog.discountPageDiscountItem,
    catalog.secretPageSecretItem,
  ];
  if (optionalSubscriptionItems.whereType<SharedCorePurchaseItem>().any(
    matches,
  )) {
    return true;
  }
  return null;
}
