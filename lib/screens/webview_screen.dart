import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
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

  // Request Izin Kamera, Lokasi, dan Storage
  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.location,
      Permission.locationWhenInUse,
    ].request();

    if (await Permission.storage.request().isDenied) {
      await Permission.photos.request();
    }
  }

  // Fungsi mengunduh/membuka link cetak via Browser HP
  Future<void> _launchDownloadUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      // Menggunakan LaunchMode.externalApplication agar langsung membuka browser HP (Chrome/Browser Bawaan)
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Fallback jika browser eksternal tidak merespon
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka/mengunduh file: $e')),
        );
      }
    }
  }

  void _initWebView() {
    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _requestPermissions();
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();

            // Tangkap request cetak/export/download file
            if (url.contains('print') ||
                url.contains('action=excel') ||
                url.contains('action=pdf') ||
                url.contains('export') ||
                url.contains('download') ||
                url.endsWith('.xlsx') ||
                url.endsWith('.xls') ||
                url.endsWith('.pdf')) {
              // Paksa ubah HTTPS ke HTTP agar tidak terjadi ERR_NAME_NOT_RESOLVED
              String fixUrl = request.url;
              if (fixUrl.startsWith('https://')) {
                fixUrl = fixUrl.replaceFirst('https://', 'http://');
              }

              // Buka lewat Browser HP
              _launchDownloadUrl(fixUrl);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('http://erp.gamamulti.com/'));

    // Konfigurasi Khusus Android
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;

      // Izinkan Geolocation (GPS)
      androidController.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          await _requestPermissions();
          return const GeolocationPermissionsResponse(
            allow: true,
            retain: true,
          );
        },
      );

      // Izinkan Akses Kamera & Upload File
      androidController.setOnPlatformPermissionRequest((request) {
        request.grant();
      });
    }

    _webViewController = controller;
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
