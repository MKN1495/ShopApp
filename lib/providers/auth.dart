import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/http_exception.dart';

class Auth with ChangeNotifier {
  String _token;
  DateTime _expiryDate;
  String _userId;
  Timer _authTimer;

  bool get isAuth {
    return token != null;
  }

  // getter to check if the token is valid
  String get token {
    if (_token != null &&
        _expiryDate != null &&
        _expiryDate.isAfter(DateTime.now())) {
      // if expiryDate is after current time
      return _token;
    }
    return null;
  }

  String get userId {
    return _userId;
  }

  Future<void> _authenticate(
      String email, String password, String urlSegment) async {
    final url =
        'https://identitytoolkit.googleapis.com/v1/accounts:$urlSegment?key=AIzaSyA1-KCJyCU99h2sLlJppxG6GOMx_341Frg';

    try {
      final response = await http.post(
        url,
        body: json.encode({
          "email": email,
          "password": password,
          "returnSecureToken": true,
        }),
      );
      //print(json.decode(response.body));
      //print(response.statusCode);
      final responseData = json.decode(response.body);
      if (responseData['error'] != null) {
        throw HttpException(responseData['error']['message']);
      }

      _token = responseData['idToken'];
      _userId = responseData['localId'];
      _expiryDate = DateTime.now().add(
        Duration(
          seconds: int.parse(responseData['expiresIn']),
        ),
      );
      _autoLogout(); // Enable the timer to autoLogout based on token expiryTime
      print('notifyListeners()');
      notifyListeners();

      final prefs = await SharedPreferences
          .getInstance(); // SharedPreferences returns a Future
      final userData = json.encode(
        {
          'token': _token,
          'userId': _userId,
          'expiryDate': _expiryDate.toIso8601String(),
        },
      );
      prefs.setString('userData', userData);
    } catch (error) {
      throw error;
    }
  }

  Future<void> signup(String email, String password) async {
    return _authenticate(email, password, 'signUp');
  }

  Future<void> login(String email, String password) async {
    return _authenticate(email, password, 'signInWithPassword');
  }

  // Function for manual logout
  Future<void> logout() async {
    _token = null;
    _userId = null;
    _expiryDate = null;
    if (_authTimer != null) {
      _authTimer.cancel(); // cancel if any authTimer exists
      _authTimer = null; // set it to null
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('userData'); // removes only userData
    //prefs.clear();    // clears all the data which is related to this app
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) {
      return false;
    }

    final extractedUserData =
        json.decode(prefs.getString('userData')) as Map<String, Object>;

    final expiryDate = DateTime.parse(extractedUserData['expiryDate']);

    if (expiryDate.isBefore(DateTime.now())) {
      return false;
    }
    _token = extractedUserData['token'];
    _userId = extractedUserData['userId'];
    _expiryDate = expiryDate;
    notifyListeners();
    _autoLogout();
    return true;
  }

  // function to auto logout if token expires
  void _autoLogout() {
    // if there exist any timer, cancel the timer
    if (_authTimer != null) {
      _authTimer.cancel();
    }
    final timeToExpiry = _expiryDate
        .difference(DateTime.now())
        .inSeconds; // get the expiryTime in seconds
    // call the logout method when timer seconds value reach token expiry second value
    Timer(Duration(seconds: timeToExpiry), logout);
  }
}
