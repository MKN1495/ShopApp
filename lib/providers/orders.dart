import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import './cart.dart';

class OrderItem {
  final String id;
  final double amount;
  final List<CartItem> products;
  final DateTime dateTime;

  OrderItem({
    @required this.id,
    @required this.amount,
    @required this.products,
    @required this.dateTime,
  });
}

class Orders with ChangeNotifier {
  List<OrderItem> _orders = [];

  List<OrderItem> get orders {
    return [..._orders];
  }

  final String authToken;
  final String userId;
  Orders(this.authToken, this.userId, this._orders);

  Future<void> fetchAndSetOrders() async {
    final url =
        'https://shopapp-719ca.firebaseio.com/orders/$userId.json?auth=$authToken'; // fetching orders based on userId
    try {
      final response = await http.get(url);
      //print(json.decode(response.body));

      final extractedData = json.decode(response.body) as Map<String, dynamic>;
      if (extractedData == null) {
        return;
      }

      final List<OrderItem> loadedOrders = [];

      extractedData.forEach(
        (orderId, orderData) {
          loadedOrders.add(
            OrderItem(
              id: orderId,
              amount: orderData['amount'],
              dateTime: DateTime.parse(orderData['dateTime']),
              products: (orderData['products'] as List<dynamic>)
                  .map(
                    (item) => CartItem(
                      id: item['id'],
                      title: item['title'],
                      price: item['price'],
                      quantity: item['quantity'],
                    ),
                  )
                  .toList(),
            ),
          );
        },
      );
      _orders = loadedOrders.reversed.toList();
      notifyListeners();
    } catch (error) {
      throw '$error';
    }
  }

  Future<void> addOrder(List<CartItem> cartProducts, double total) async {
    final url =
        'https://shopapp-719ca.firebaseio.com/orders/$userId.json?auth=$authToken'; // storing orders based on userId
    final timeStamp = DateTime.now();
    try {
      final response = await http.post(
        url,
        body: json.encode(
          {
            'amount': total,
            'dateTime': timeStamp
                .toIso8601String(), // uniform string representation of date, because we can't send datetime object
            'products':
                cartProducts // products is a list of cartItem. cartItem is a object. we can't have objects in json file. we need to map all the objects to map
                    .map(
                      (cp) => {
                        'id': cp.id,
                        'title': cp.title,
                        'price': cp.price,
                        'quantity': cp.quantity,
                      },
                    )
                    .toList(),
          },
        ),
      );

      _orders.insert(
        0,
        OrderItem(
          id: json.decode(response.body)['name'],
          amount: total,
          products: cartProducts,
          dateTime: timeStamp,
        ),
      );
      notifyListeners();
    } catch (error) {}
  }
}
