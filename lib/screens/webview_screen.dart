import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initWebView();
    _checkInitialConnectivity();
    _listenConnectivity();
  }

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

  Future<void> _launchDownloadUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
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

  // Dialog Opsi Pilihan Sumber File (Kamera vs Galeri/Dokumen)
  Future<String?> _showSourceSelectionDialog() async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Ambil Foto dari Kamera'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.folder, color: Colors.amber),
                title: const Text('Pilih Berkas / Galeri'),
                onTap: () => Navigator.pop(context, 'file'),
              ),
            ],
          ),
        );
      },
    );
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

            if (url.contains('print') ||
                url.contains('action=excel') ||
                url.contains('action=pdf') ||
                url.contains('export') ||
                url.contains('download') ||
                url.endsWith('.xlsx') ||
                url.endsWith('.xls') ||
                url.endsWith('.pdf')) {
              String fixUrl = request.url;
              if (fixUrl.startsWith('https://')) {
                fixUrl = fixUrl.replaceFirst('https://', 'http://');
              }

              _launchDownloadUrl(fixUrl);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('http://erp.gamamulti.com/'));

    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;

      androidController.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          await _requestPermissions();
          return const GeolocationPermissionsResponse(
            allow: true,
            retain: true,
          );
        },
      );

      androidController.setOnPlatformPermissionRequest((request) {
        request.grant();
      });

      // Pilihan Dinamis: Kamera Langsung / File Manager
      androidController.setOnShowFileSelector((
        FileSelectorParams params,
      ) async {
        try {
          final selectedSource = await _showSourceSelectionDialog();

          if (selectedSource == 'camera') {
            final XFile? photo = await _imagePicker.pickImage(
              source: ImageSource.camera,
              imageQuality: 85,
            );
            if (photo != null) {
              return [Uri.file(photo.path).toString()];
            }
          } else if (selectedSource == 'file') {
            final files = await FilePicker.pickFiles(type: FileType.any);

            if (files.isNotEmpty) {
              return files
                  .where((file) => file.path != null)
                  .map((file) => Uri.file(file.path!).toString())
                  .toList();
            }
          }
        } catch (e) {
          debugPrint('Error picking file: $e');
        }
        return [];
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
