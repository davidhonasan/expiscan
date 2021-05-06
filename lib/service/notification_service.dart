import 'package:expiscan/constants/constants.dart';
import 'package:expiscan/service/database_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService._() {
    pluginInit();
  }

  static const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('icon');
  // final IOSInitializationSettings initializationSettingsIOS =
  //     IOSInitializationSettings(
  //         onDidReceiveLocalNotification: onDidReceiveLocalNotification);
  //   Future onDidReceiveLocalNotification(
  // int id, String? title, String? body, String? payload) async {}

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    // iOS: initializationSettingsIOS,
  );

  Future<void> pluginInit() async {
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: onSelectNotification);
  }

  Future onSelectNotification(String? payload) async {
    if (payload != null) {
      print(payload);
    }
  }

  Future<void> showNotification(
      {required int id,
      String? title,
      String? body,
      String? payload,
      bool groupSummary = false}) async {
    var androidChannelSpecifics = AndroidNotificationDetails(
        '0', 'Reminders', "Show notification when a food is going to expire.",
        importance: Importance.max, // Android 8.0+
        priority: Priority.high, // Android 7.1 below
        playSound: true,
        groupKey: 'Reminders',
        setAsGroupSummary: groupSummary);
    // var iosChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics =
        NotificationDetails(android: androidChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> scheduledNotification(
      {required int id,
      String? productName,
      String? payload,
      required DateTime scheduledDate,
      bool groupSummary = false}) async {
    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    String titleToday = '⚠️ $productName expires today!';
    String title3Days = '😲 $productName expires in 3 days';
    String title7Days = '🥺 $productName expires in 7 days';
    String bodyToday = 'Don\'t forget to consume them today! 👌';
    String body3Days = 'It\'s going to expire soon. 😮';
    String body7Days = 'A reminder so you won\'t forget 😉';

// Android Channel Specifics
    var acsToday = AndroidNotificationDetails('today', 'Today Reminders',
        "Show notification when a food is going to expire.",
        importance: Importance.max, // Android 8.0+
        priority: Priority.high, // Android 7.1 below
        playSound: true,
        groupKey: 'Reminders');
    var acs3Days = AndroidNotificationDetails(
        'three_days',
        'Expire in 3 Days Reminders',
        "Show notification when a food is going to expire.",
        importance: Importance.defaultImportance, // Android 8.0+
        priority: Priority.defaultPriority, // Android 7.1 below
        playSound: true,
        groupKey: 'Reminders');
    var acs7Days = AndroidNotificationDetails(
        'seven_days',
        'Expire in 7 Reminders',
        "Show notification when a food is going to expire.",
        importance: Importance.low, // Android 8.0+
        priority: Priority.low, // Android 7.1 below
        playSound: false,
        groupKey: 'Reminders');
    // var iosChannelSpecifics = IOSNotificationDetails();

    // Platform Channel Specifics
    var pcsToday = NotificationDetails(android: acsToday);
    var pcs3Days = NotificationDetails(android: acs3Days);
    var pcs7Days = NotificationDetails(android: acs7Days);

    // Expire Today
    await flutterLocalNotificationsPlugin.zonedSchedule(
        id + 100000, titleToday, bodyToday, tzScheduledDate, pcsToday,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        androidAllowWhileIdle: true);

    // Expire in 3 days
    if (tzScheduledDate.difference(DateTime.now()).inDays >= 3) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
          id + 300000,
          title3Days,
          body3Days,
          tzScheduledDate.subtract(Duration(days: 3)),
          pcs3Days,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.wallClockTime,
          androidAllowWhileIdle: true);
    }

    // Expire in 7 days
    if (tzScheduledDate.difference(DateTime.now()).inDays >= 7) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
          id + 700000,
          title7Days,
          body7Days,
          tzScheduledDate.subtract(Duration(days: 7)),
          pcs7Days,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.wallClockTime,
          androidAllowWhileIdle: true);
    }
  }

  void cancelNotificationForFood(Food food) async {
    await flutterLocalNotificationsPlugin.cancel(food.id!);
  }

  void cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  void getAllNotifications() async {
    List<PendingNotificationRequest> notificationsList =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    for (var notification in notificationsList) {
      print(notification.id);
      print(notification.title);
      print(notification.body);
    }
  }
}

Future<void> initTz() async {
  final String currentTimeZone = await FlutterNativeTimezone.getLocalTimezone();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation(currentTimeZone));
}

final notificationService = NotificationService._();

Future<void> initNotificationService() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('notificationService') ?? false) {
    List foodList = await ExpiscanDB.getEntries(foodTableName);

    // sort foodlist
    foodList.sort((a, b) {
      return a.expiryDate!.compareTo(b.expiryDate!) as int;
    });
    // remove
    foodList.removeWhere((food) {
      return food.expiryDate.isBefore(DateTime.now());
    });

    for (Food food in foodList) {
      notificationService.scheduledNotification(
          id: food.id!,
          productName: food.name,
          scheduledDate: food.expiryDate,
          groupSummary: true);
    }
  } else {
    notificationService.cancelAllNotifications();
  }
}
