import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExitDialog {
  static Future<bool> show(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari aplikasi ERP Gamamulti?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              SystemNavigator.pop(); // Menutup aplikasi
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0B4A2E)),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }
}
