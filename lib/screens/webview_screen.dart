import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../widgets/exit_dialog.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _webViewController;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _checkInitialConnectivity();
    _listenConnectivity();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('http://erp.gamamulti.com/'));
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectionStatus(results);
  }

  void _listenConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      _updateConnectionStatus(results);
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final isConnected = results.any(
      (result) => result != ConnectivityResult.none,
    );
    if (!isConnected && _hasInternet) {
      _showNoInternetSnackBar();
    }
    setState(() {
      _hasInternet = isConnected;
    });
  }

  void _showNoInternetSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tidak ada koneksi internet! Periksa kembali jaringan Anda.',
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (await _webViewController.canGoBack()) {
          _webViewController.goBack();
        } else {
          if (context.mounted) {
            await ExitDialog.show(context);
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: _hasInternet
              ? WebViewWidget(controller: _webViewController)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Tidak Ada Koneksi Internet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await _checkInitialConnectivity();
                          if (_hasInternet) {
                            _webViewController.reload();
                          }
                        },
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
