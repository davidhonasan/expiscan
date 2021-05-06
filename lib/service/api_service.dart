import 'dart:async';

import 'package:openfoodfacts/openfoodfacts.dart';

Future<Product?> getProduct(String barcode) async {
  ProductQueryConfiguration configuration = ProductQueryConfiguration(barcode,
      language: OpenFoodFactsLanguage.GERMAN, fields: [ProductField.ALL]);
  ProductResult result = await OpenFoodAPIClient.getProduct(configuration);

  if (result.status == 1) {
    return result.product;
  } else {
    throw Exception("Product not found / supported for " + barcode);
  }
}
