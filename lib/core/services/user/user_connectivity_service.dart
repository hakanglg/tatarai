import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class UserConnectivityService {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  void listen(void Function(bool hasConnection) onChanged) {
    _subscription = _connectivity.onConnectivityChanged.listen((resultList) {
      final hasConnection = resultList.any((r) => r != ConnectivityResult.none);
      onChanged(hasConnection);
    });
  }

  Future<bool> checkConnection() async {
    final resultList = await _connectivity.checkConnectivity();
    return resultList != ConnectivityResult.none;
  }

  void dispose() {
    _subscription?.cancel();
  }
}
