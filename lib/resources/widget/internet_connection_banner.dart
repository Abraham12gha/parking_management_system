import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class InternetConnectionBanner extends StatefulWidget {
  final Widget child;

  const InternetConnectionBanner({
    super.key,
    required this.child,
  });

  @override
  State<InternetConnectionBanner> createState() => _InternetConnectionBannerState();
}

class _InternetConnectionBannerState extends State<InternetConnectionBanner> {
  late StreamSubscription<List<ConnectivityResult>>
  _connectivitySubscription;

  bool _isOffline = false;
  bool _showRestoredMessage = false;

  Timer? _restoredMessageTimer;

  @override
  void initState() {
    super.initState();

    _checkConnection();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(
              (List<ConnectivityResult> results) {
            _updateConnectionStatus(results);
          },
        );
  }

  Future<void> _checkConnection() async {
    final results = await Connectivity().checkConnectivity();

    _updateConnectionStatus(results);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection = results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.ethernet) || results.contains(ConnectivityResult.mobile);

    if (!mounted) return;
    if (_isOffline && hasConnection) {
      _showRestoredMessageForTwoSeconds();
    }
    setState(() {
      _isOffline = !hasConnection;
    });
  }

  void _showRestoredMessageForTwoSeconds() {
    _restoredMessageTimer?.cancel();

    setState(() {
      _showRestoredMessage = true;
    });

    _restoredMessageTimer = Timer(
      const Duration(seconds: 2),
          () {
        if (!mounted) return;

        setState(() {
          _showRestoredMessage = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _restoredMessageTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isOffline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 7,
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              border: Border(
                bottom: BorderSide(
                  color: Colors.red.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 18,
                  color: Colors.red.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'No internet connection',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),

        if (_showRestoredMessage)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 7,
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              border: Border(
                bottom: BorderSide(
                  color: Colors.green.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_rounded,
                  size: 18,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Internet has restored',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: widget.child,
        ),
      ],
    );
  }
}