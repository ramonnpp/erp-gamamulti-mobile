import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);

    // Minta Izin Notifikasi (Android 13+)
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // Atur semua jadwal presensi
    await scheduleAllPresensi();
  }

  static Future<void> scheduleAllPresensi() async {
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
  }

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

    // Cari hari terdekat berikutnya
    while (scheduledDate.weekday != targetWeekday ||
        scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final Duration delay = scheduledDate.difference(now);

    // Munculkan notifikasi saat waktu tercapai
    Future.delayed(delay, () async {
      await _showImmediateNotification(id: id, title: title, body: body);
    });
  }

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
