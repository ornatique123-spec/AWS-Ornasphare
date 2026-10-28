import 'package:flutter/cupertino.dart';

class HomeRefreshProvider extends ChangeNotifier {
  int _refreshKey = 0;

  int get refreshKey => _refreshKey;

  void refreshHome() {
    _refreshKey++;
    notifyListeners();
  }
}