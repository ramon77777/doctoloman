import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/appointments/domain/appointment.dart';

class LocalNotificationsService {
  LocalNotificationsService._();

  static final LocalNotificationsService instance =
      LocalNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const _channelId = 'appointment_reminders';
  static const _channelName = 'Rappels de rendez-vous';
  static const _channelDescription =
      'Notifications locales pour les rappels de rendez-vous';

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      // Fallback silencieux
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
    );

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> syncAppointments(List<Appointment> appointments) async {
    await init();

    for (final appointment in appointments) {
      await _syncSingleAppointment(appointment);
    }
  }

  Future<void> syncAppointment(Appointment appointment) async {
    await init();
    await _syncSingleAppointment(appointment);
  }

  Future<void> cancelAppointmentReminder(String appointmentId) async {
    await init();
    await _plugin.cancel(
      id: _notificationIdForAppointment(appointmentId),
    );
  }

  Future<void> _syncSingleAppointment(Appointment appointment) async {
    final notificationId = _notificationIdForAppointment(appointment.id);

    await _plugin.cancel(id: notificationId);

    if (appointment.isCancelledLike) {
      return;
    }

    if (!appointment.isUpcoming) {
      return;
    }

    final reminderAt = _computeReminderTime(appointment.scheduledAt);
    if (reminderAt == null) {
      return;
    }

    if (!reminderAt.isAfter(DateTime.now())) {
      return;
    }

    final scheduledDate = tz.TZDateTime.from(reminderAt, tz.local);

    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Rappel de rendez-vous',
      body: _buildReminderBody(appointment),
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: appointment.id,
    );
  }

  DateTime? _computeReminderTime(DateTime scheduledAt) {
    final now = DateTime.now();
    final diff = scheduledAt.difference(now);

    if (diff <= const Duration(minutes: 45)) {
      return null;
    }

    if (diff >= const Duration(hours: 26)) {
      final previousDay = scheduledAt.subtract(const Duration(days: 1));
      return DateTime(
        previousDay.year,
        previousDay.month,
        previousDay.day,
        18,
        0,
      );
    }

    if (diff >= const Duration(hours: 3)) {
      return scheduledAt.subtract(const Duration(hours: 2));
    }

    return scheduledAt.subtract(const Duration(minutes: 30));
  }

  String _buildReminderBody(Appointment appointment) {
    return '${appointment.practitionerName} • '
        '${_formatDate(appointment.day)} à ${appointment.slot}';
  }

  int _notificationIdForAppointment(String appointmentId) {
    final digits = appointmentId.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      final value = int.tryParse(digits);
      if (value != null) {
        return value % 2147483647;
      }
    }

    return appointmentId.hashCode.abs() % 2147483647;
  }

  String _formatDate(DateTime d) {
    const months = [
      'janv',
      'févr',
      'mars',
      'avr',
      'mai',
      'juin',
      'juil',
      'août',
      'sept',
      'oct',
      'nov',
      'déc',
    ];
    final m = months[max(0, d.month - 1)];
    return '${d.day} $m ${d.year}';
  }
}