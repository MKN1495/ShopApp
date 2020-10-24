import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shopApp/models/http_exception.dart';

import './product.dart';

class Products with ChangeNotifier {
  List<Product> _items = [
    // Product(
    //   id: 'p1',
    //   title: 'Red Shirt',
    //   description: 'A red shirt - it is pretty red!',
    //   price: 29.99,
    //   imageUrl:
    //       'https://cdn.pixabay.com/photo/2016/10/02/22/17/red-t-shirt-1710578_1280.jpg',
    // ),
    // Product(
    //   id: 'p2',
    //   title: 'Trousers',
    //   description: 'A nice pair of trousers.',
    //   price: 59.99,
    //   imageUrl:
    //       'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e8/Trousers%2C_dress_%28AM_1960.022-8%29.jpg/512px-Trousers%2C_dress_%28AM_1960.022-8%29.jpg',
    // ),
    // Product(
    //   id: 'p3',
    //   title: 'Yellow Scarf',
    //   description: 'Warm and cozy - exactly what you need for the winter.',
    //   price: 19.99,
    //   imageUrl:
    //       'https://live.staticflickr.com/4043/4438260868_cc79b3369d_z.jpg',
    // ),
    // Product(
    //   id: 'p4',
    //   title: 'A Pan',
    //   description: 'Prepare any meal you want.',
    //   price: 49.99,
    //   imageUrl:
    //       'https://upload.wikimedia.org/wikipedia/commons/thumb/1/14/Cast-Iron-Pan.jpg/1024px-Cast-Iron-Pan.jpg',
    // ),
  ];

  List<Product> get items {
    return [..._items];
  }

  List<Product> get favoriteItems {
    return _items.where((product) => product.isFavorite).toList();
  }

  final String authToken;
  final String userId;
  Products(this.authToken, this.userId, this._items);

  Future<void> fetchAndSetProduct([bool filterByUser = false]) async {
    // url for fetching all the products irrespective of users
    // var url =
    //     'https://shopapp-719ca.firebaseio.com/products.json?auth=$authToken';

    final String filterString =
        filterByUser ? 'orderBy="creatorId"&equalTo="$userId"' : '';

    var url =
        'https://shopapp-719ca.firebaseio.com/products.json?auth=$authToken&$filterString'; // filter where creatorId and userId matches for particular user, Firebase rules need to be modified
    try {
      final response = await http.get(url);
      //print(json.decode(response.body));
      final extractedData = json.decode(response.body) as Map<String, dynamic>;
      // check if any product exist
      if (extractedData == null) {
        return;
      }

      // check for favorite product for particular user
      url =
          'https://shopapp-719ca.firebaseio.com/userFavorites/$userId.json?auth=$authToken';

      final favoriteResponse = await http.get(url);
      final favoriteData = json.decode(favoriteResponse.body);

      final List<Product> loadedProducts = [];
      extractedData.forEach((prodId, prodData) {
        loadedProducts.add(
          Product(
            id: prodId,
            title: prodData['title'],
            description: prodData['description'],
            price: prodData['price'],
            imageUrl: prodData['imageUrl'],
            isFavorite: favoriteData == null
                ? false
                : favoriteData[prodId] ??
                    false, // check if favoriteData for null (user haven't made any favorite) and if favoriteData[prodId] is null (no prodId exist)
          ),
        );
      });
      _items = loadedProducts;
      notifyListeners();
    } catch (error) {
      throw '$error';
    }
  }

  Future<void> addProduct(Product product) async {
    final url =
        'https://shopapp-719ca.firebaseio.com/products.json?auth=$authToken';
    try {
      final response = await http.post(
        url,
        body: json.encode(
          {
            'title': product.title,
            'description': product.description,
            'price': product.price,
            'imageUrl': product.imageUrl,
            'creatorId': userId, // keeps the creatorId who added the product
          },
        ),
      );
      final newProduct = Product(
        id: json.decode(response.body)['name'],
        title: product.title,
        description: product.description,
        price: product.price,
        imageUrl: product.imageUrl,
      );
      _items.add(newProduct);
      notifyListeners();
    } catch (error) {
      print(error);
      throw '$error';
    }
  }

  Future<void> updateProduct(String id, Product newProduct) async {
    final prodIndex = _items.indexWhere((product) => product.id == id);
    if (prodIndex >= 0) {
      // need to change the url for updating the product for a particular id
      final url =
          'https://shopapp-719ca.firebaseio.com/products/$id.json?auth=$authToken';
      try {
        await http.patch(url,
            body: json.encode({
              'title': newProduct.title,
              'description': newProduct.description,
              'price': newProduct.price,
              'imageUrl': newProduct.imageUrl,
            }));
        _items[prodIndex] = newProduct;
        notifyListeners();
      } catch (error) {
        throw '$error';
      }
    } else {
      print('...');
    }
  }

  // Using async and await
  Future<void> deleteProduct(String id) async {
    final url =
        'https://shopapp-719ca.firebaseio.com/products/$id.json?auth=$authToken';
    // find the index of item to be deleted
    final existingProductIndex =
        _items.indexWhere((product) => product.id == id);
    // keep a copy of item to be deleted, to reinsert in list if any error occurs
    var existingProduct = _items[existingProductIndex];

    // ++++++++++++++++++++++++++++++++++++++
    /*
    // 1st way delete locally, notify, delete in server, if any error occurs rollback
    _items.removeAt(existingProductIndex);
    notifyListeners();

    final response = await http.delete(url);

    // if any error occurs rollback the item
    if (response.statusCode >= 400) {
      _items.insert(existingProductIndex, existingProduct);
      notifyListeners();
      throw HttpException('Could not delete the item');
    }
    // clear the memory
    existingProduct = null;
    */
    // ++++++++++++++++++++++++++++++++++++++

    // ========================================
    // 2nd way delete remotely then delete locally
    final response = await http.delete(url);

    if (response.statusCode >= 400) {
      // if error occurs throw an exception
      throw HttpException('Could not delete the item');
    }
    // if no error occurs, remove locally and clear memory
    _items.removeAt(existingProductIndex);
    notifyListeners();
    existingProduct = null;

    // ========================================
  }

/*
  // This works partially, So not a better way. Use the above method
  // Using Future and then
  void deleteProduct(String id) {
    final url = 'https://shopapp-719ca.firebaseio.com/products/$id';
    // find the index of item to be deleted
    final existingProductIndex =
        _items.indexWhere((product) => product.id == id);
    // keep a copy of item to be deleted, to reinsert in list if any error occurs
    var existingProduct = _items[existingProductIndex];

    // 1st way delete locally, notify, delete in server, if any error occurs rollback
    // _items.removeAt(existingProductIndex);
    // notifyListeners();
    // http.delete(url).then((response) {
    //   if (response.statusCode >= 400) {
    //     throw HttpException('Could not delete the item');
    //   }
    //   existingProduct = null;
    // }).catchError((error) {
    //   print('Exception received at catchError in deleteProduct');
    //   // if any error occurs, reinsert the item
    //   _items.insert(existingProductIndex, existingProduct);
    //   notifyListeners();
    //   throw error;
    // });

    //2nd way -> delete the item in server, then delete locally
    http.delete(url).then((response) {
      if (response.statusCode >= 400) {
        throw HttpException('Could not delete the item');
      }
      _items.removeAt(existingProductIndex);
      existingProduct = null;
      notifyListeners();
    }).catchError((error) {
      print('Exception received at catchError in deleteProduct');
      throw error;
    });
  }
  */

  Product findById(String id) {
    return _items.firstWhere((product) => id == product.id);
  }

  void removeItem(String id) {
    _items.removeWhere((product) => product.id == id);
    notifyListeners();
  }
}
