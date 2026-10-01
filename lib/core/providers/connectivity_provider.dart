// lib/core/providers/connectivity_provider.dart

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

class NetworkStatusNotifier extends StateNotifier<bool> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _periodicCheck;
  bool _isChecking = false;

  NetworkStatusNotifier() : super(true) {
    _init();
  }

  Future<void> _init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      await _evaluateInternet(results);
    } catch (_) {}

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _evaluateInternet(results);
    });

    _periodicCheck = Timer.periodic(const Duration(seconds: 10), (_) {
      checkConnection();
    });
  }

  Future<void> checkConnection() async {
    if (_isChecking) return;
    try {
      final results = await _connectivity.checkConnectivity();
      await _evaluateInternet(results);
    } catch (_) {}
  }

  Future<void> _evaluateInternet(List<ConnectivityResult> results) async {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      if (mounted && state != false) state = false;
      return;
    }

    _isChecking = true;
    try {
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      final hasInternet = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
      if (mounted && state != hasInternet) {
        state = hasInternet;
      }
    } catch (_) {
      try {
        final rawLookup = await InternetAddress.lookup('1.1.1.1')
            .timeout(const Duration(seconds: 2));
        final hasRaw = rawLookup.isNotEmpty && rawLookup[0].rawAddress.isNotEmpty;
        if (mounted && state != hasRaw) {
          state = hasRaw;
        }
      } catch (_) {
        if (mounted && state != false) {
          state = false;
        }
      }
    } finally {
      _isChecking = false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _periodicCheck?.cancel();
    super.dispose();
  }
}

final isOnlineProvider = StateNotifierProvider<NetworkStatusNotifier, bool>((ref) {
  return NetworkStatusNotifier();
});
