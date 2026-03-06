import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'railway_service.dart';

class PurchaseService {
  static final PurchaseService instance = PurchaseService._();
  PurchaseService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  final Set<String> _processedPurchaseIds = {};

  // Обновленные Product IDs
  static const String token100Id = 'dokki_tokens_100';
  static const String token500Id = 'dokki_tokens_500';
  static const String token1000Id = 'dokki_tokens_1000';

  static const Set<String> _kProductIds = {
    token100Id,
    token500Id,
    token1000Id,
  };

  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;

  Future<void> initialize() async {
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      debugPrint('Store not available');
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        debugPrint('Purchase stream error: $error');
      },
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    final ProductDetailsResponse response =
        await _iap.queryProductDetails(_kProductIds);

    if (response.error != null) {
      debugPrint('Error loading products: ${response.error!.message}');
      return;
    }

    _products = response.productDetails;

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs.join(", ")}');
    }
  }

  ProductDetails? getProduct(String id) {
    try {
      return _products.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> buyTokens(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    try {
      await _iap.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);
    } catch (e) {
      debugPrint('Error buying tokens: $e');
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
    }
  }

  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('Purchase pending: ${purchaseDetails.productID}');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint('Purchase error: ${purchaseDetails.error}');
      } else if (purchaseDetails.status == PurchaseStatus.purchased) {
        // Только для новых покупок начисляем токены
        await _handlePurchaseSuccess(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.restored) {
        // Для восстановленных покупок только завершаем транзакцию
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
          debugPrint('✅ Restored purchase completed: ${purchaseDetails.purchaseID}');
        }
      }
    }
  }

  Future<void> _handlePurchaseSuccess(PurchaseDetails details) async {
    final purchaseId = details.purchaseID ?? '';
    if (_processedPurchaseIds.contains(purchaseId)) {
      debugPrint('⚠️ Duplicate purchase ignored: $purchaseId');
      if (details.pendingCompletePurchase) {
        await _iap.completePurchase(details);
      }
      return;
    }
    _processedPurchaseIds.add(purchaseId);

    if (details.pendingCompletePurchase) {
      try {
        await _iap.completePurchase(details);
        debugPrint('✅ Purchase completed locally');
      } catch (e) {
        debugPrint('❌ Error completing purchase: $e');
        _processedPurchaseIds.remove(purchaseId);
        return;
      }
    }

    int amount = 0;
    switch (details.productID) {
      case token100Id:
        amount = 100;
        break;
      case token500Id:
        amount = 500;
        break;
      case token1000Id:
        amount = 1000;
        break;
    }

    if (amount > 0) {
      try {
        await RailwayService.instance.addTokens(amount, purchaseId);
        debugPrint('✅ Tokens added: $amount for $purchaseId');
      } catch (e) {
        debugPrint('❌ Failed to add tokens: $e');
      }
    }
  }

  void dispose() {
    if (_isAvailable) {
      _subscription.cancel();
    }
  }
}