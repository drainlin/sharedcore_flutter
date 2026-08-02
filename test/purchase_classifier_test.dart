import 'package:flutter_test/flutter_test.dart';
import 'package:sharedcore_flutter/sharedcore_flutter.dart';
import 'package:sharedcore_flutter/src/purchase_classifier.dart';

void main() {
  const purchase = SharedCorePurchaseItem(
    itemId: 1,
    price: 1.99,
    amount: 100,
    giftAmount: 0,
    productId: 'credits.100',
    type: 0,
    pageType: 0,
    cycle: 0,
    isShow: 1,
    subscriptionPeriod: '',
    freeTryDays: 0,
  );
  const subscription = SharedCorePurchaseItem(
    itemId: 2,
    price: 4.99,
    amount: 0,
    giftAmount: 0,
    productId: 'subscription.monthly',
    type: 0,
    pageType: 0,
    cycle: 1,
    isShow: 1,
    subscriptionPeriod: 'P1M',
    freeTryDays: 0,
  );
  const catalog = SharedCorePurchaseCatalog(
    schemaVersion: 2,
    creditPagePurchaseItems: <SharedCorePurchaseItem>[purchase],
    creditPageSubscribeItems: <SharedCorePurchaseItem>[subscription],
  );

  test('creditPage purchaseList products are one-time purchases', () {
    expect(subscriptionStatusForProduct(catalog, purchase.productId), isFalse);
  });

  test('all other known v2 products are subscriptions', () {
    expect(
      subscriptionStatusForProduct(catalog, subscription.productId),
      isTrue,
    );
  });

  test('purchaseList wins if a product appears in multiple sections', () {
    const duplicateCatalog = SharedCorePurchaseCatalog(
      schemaVersion: 2,
      creditPagePurchaseItems: <SharedCorePurchaseItem>[purchase],
      creditPageSubscribeItems: <SharedCorePurchaseItem>[purchase],
    );

    expect(
      subscriptionStatusForProduct(duplicateCatalog, purchase.productId),
      isFalse,
    );
  });

  test('unknown products are not guessed as subscriptions', () {
    expect(subscriptionStatusForProduct(catalog, 'unknown'), isNull);
  });
}
