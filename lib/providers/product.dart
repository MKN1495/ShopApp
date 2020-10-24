import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Product with ChangeNotifier {
  final String id;
  final String title;
  final String description;
  final double price;
  final String imageUrl;
  bool isFavorite;

  Product({
    @required this.id,
    @required this.title,
    @required this.description,
    @required this.price,
    @required this.imageUrl,
    this.isFavorite = false,
  });

  void _setFavValue(bool newValue) {
    isFavorite = newValue;
    notifyListeners();
  }

  Future<void> toggleFavoriteStatus(String token, String userId) async {
    // keeping a copy of oldstatus to revert back to its original state if any error comes while updating to server
    var oldStatus = isFavorite;
    isFavorite = !isFavorite;
    notifyListeners();

    /*
    // url to make the product favorite irrespective of user
    final url =
        'https://shopapp-719ca.firebaseio.com/products/$id.json?auth=$token'; // where id is productID
    try {
      final response =
          await http.patch(url, body: json.encode({'isFavorite': isFavorite}));
      if (response.statusCode >= 400) {
        _setFavValue(oldStatus);
      }
    } catch (error) {
      _setFavValue(oldStatus);
    }
    */

    // url to make the product favorite for particular user
    var url =
        'https://shopapp-719ca.firebaseio.com/userFavorites/$userId/$id.json?auth=$token';

    try {
      final response = await http.put(
        url,
        body: json.encode(
          isFavorite,
        ),
      );
      //print(json.decode(response.body));
      if (response.statusCode >= 400) {
        _setFavValue(oldStatus);
      }
    } catch (error) {
      //print('error: $error');
      _setFavValue(oldStatus);
    }
  }
}
