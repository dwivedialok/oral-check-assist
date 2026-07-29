import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';

/// Service for managing local notifications (screening reminders)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz_data.initializeTimeZones();

    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined settings
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    debugPrint('✅ [NotificationService] Initialized');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
      '📱 [NotificationService] Notification tapped: ${response.payload}',
    );
    // Handle navigation based on payload
    // This could be handled by the main app through a stream or callback
  }

  /// Request notification permissions (iOS)
  Future<bool> requestPermissions() async {
    final result = await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return result ?? false;
  }

  /// Schedule a screening reminder. Pass [l10n] for localized channel name/description; if null, English is used.
  Future<void> scheduleScreeningReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    AppLocalizations? l10n,
  }) async {
    await _ensureInitialized();
    l10n ??= AppLocalizationsEn();
    final androidDetails = AndroidNotificationDetails(
      'screening_reminders',
      l10n.screeningRemindersChannel,
      channelDescription: l10n.screeningRemindersDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'screening_reminder',
    );

    debugPrint(
      '📅 [NotificationService] Scheduled reminder for: $scheduledDate',
    );
  }

  /// Schedule default 3-month screening reminder. Pass [l10n] for localized strings; if null, English is used.
  Future<void> scheduleThreeMonthReminder([AppLocalizations? l10n]) async {
    l10n ??= AppLocalizationsEn();
    final reminderDate = DateTime.now().add(const Duration(days: 90));
    await scheduleScreeningReminder(
      id: 1,
      title: l10n.timeForOralScreening,
      body: l10n.threeMonthReminderBody,
      scheduledDate: reminderDate,
      l10n: l10n,
    );
  }

  /// Cancel a specific reminder
  Future<void> cancelReminder(int id) async {
    await _ensureInitialized();
    await _notifications.cancel(id);
    debugPrint('🗑️ [NotificationService] Cancelled reminder: $id');
  }

  /// Cancel all reminders
  Future<void> cancelAllReminders() async {
    await _ensureInitialized();
    await _notifications.cancelAll();
    debugPrint('🗑️ [NotificationService] Cancelled all reminders');
  }

  /// Show an immediate notification (for testing). Pass [l10n] for localized body; if null, English is used.
  Future<void> showTestNotification([AppLocalizations? l10n]) async {
    await _ensureInitialized();
    l10n ??= AppLocalizationsEn();
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'For testing notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      'Test Notification',
      l10n.testNotificationBody,
      details,
    );
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    await _ensureInitialized();
    return await _notifications.pendingNotificationRequests();
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}
