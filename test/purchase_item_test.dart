import 'package:flutter_test/flutter_test.dart';
import 'package:sharedcore_flutter/sharedcore_flutter.dart';

void main() {
  Map<String, Object?> purchaseItemMap(Object? isShow) => <String, Object?>{
    'itemId': 1,
    'price': 1.99,
    'amount': 100,
    'giftAmount': 0,
    'productId': 'credits.100',
    'type': 0,
    'pageType': 0,
    'cycle': 0,
    'isShow': isShow,
    'subscriptionPeriod': '',
    'freeTryDays': 0,
  };

  test('isShow accepts numeric backend flags', () {
    expect(SharedCorePurchaseItem.fromMap(purchaseItemMap(1)).isShow, isTrue);
    expect(SharedCorePurchaseItem.fromMap(purchaseItemMap(0)).isShow, isFalse);
  });

  test('isShow accepts boolean values', () {
    expect(
      SharedCorePurchaseItem.fromMap(purchaseItemMap(true)).isShow,
      isTrue,
    );
    expect(
      SharedCorePurchaseItem.fromMap(purchaseItemMap(false)).isShow,
      isFalse,
    );
  });
}
