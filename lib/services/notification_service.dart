import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Inisialisasi service notifikasi & pemanggilan izin
  static Future<void> init() async {
    try {
      // 1. Minta izin notifikasi secara eksplisit via permission_handler (Android 13+)
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      // 2. Inisialisasi konfigurasi notifikasi Android
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _notificationsPlugin.initialize(initializationSettings);

      // 3. Minta izin alarm presisi (khusus jadwal tepat waktu)
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        await androidPlugin.requestExactAlarmsPermission();
      }

      // 4. Set ulang semua jadwal presensi
      await scheduleAllPresensi();
    } catch (e) {
      debugPrint('Error pada NotificationService.init(): $e');
    }
  }

  /// Menjadwalkan notifikasi presensi berulang
  static Future<void> scheduleAllPresensi() async {
    try {
      await _notificationsPlugin.cancelAll();

      // === SENIN S/D KAMIS ===
      for (int day = DateTime.monday; day <= DateTime.thursday; day++) {
        // Masuk (07:50)
        await _scheduleNotificationForDay(
          id: day * 10 + 1,
          title: '⏰ Pengingat Presensi Masuk',
          body: 'Jangan lupa presensi masuk hari ini sebelum jam 08:00!',
          targetWeekday: day,
          hour: 7,
          minute: 50,
        );

        // Pulang (16:30)
        await _scheduleNotificationForDay(
          id: day * 10 + 2,
          title: '🔔 Pengingat Presensi Pulang',
          body: 'Sudah jam 16:30, jangan lupa presensi pulang ya!',
          targetWeekday: day,
          hour: 16,
          minute: 30,
        );
      }

      // === JUMAT KHUSUS ===
      // Masuk Jumat (07:20)
      await _scheduleNotificationForDay(
        id: 51,
        title: '⏰ Pengingat Presensi Masuk (Jumat)',
        body: 'Jumat Semangat! Jangan lupa presensi masuk sebelum jam 07:30!',
        targetWeekday: DateTime.friday,
        hour: 7,
        minute: 20,
      );

      // Pulang Jumat (16:00)
      await _scheduleNotificationForDay(
        id: 52,
        title: '🔔 Pengingat Presensi Pulang (Jumat)',
        body:
            'Sudah jam 16:00, selamat berakhir pekan! Jangan lupa presensi pulang.',
        targetWeekday: DateTime.friday,
        hour: 16,
        minute: 0,
      );
    } catch (e) {
      debugPrint('Error pada scheduleAllPresensi(): $e');
    }
  }

  /// Menghitung selisih waktu terdekat berdasarkan hari & jam
  static Future<void> _scheduleNotificationForDay({
    required int id,
    required String title,
    required String body,
    required int targetWeekday,
    required int hour,
    required int minute,
  }) async {
    final now = DateTime.now();
    DateTime scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Cari hari terdekat berikutnya jika jam hari ini sudah lewat
    while (scheduledDate.weekday != targetWeekday ||
        scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final Duration delay = scheduledDate.difference(now);

    // Eksekusi notifikasi saat waktu tercapai
    Timer(delay, () async {
      await _showImmediateNotification(id: id, title: title, body: body);
    });
  }

  /// Menampilkan notifikasi banner
  static Future<void> _showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'erp_presensi_channel',
          'Notifikasi Presensi ERP',
          channelDescription: 'Pengingat Waktu Absensi Karyawan',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(id, title, body, notificationDetails);
  }
}
