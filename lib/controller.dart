import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

class ServiceController extends GetxController {
  final isRunning = false.obs;
  final service = FlutterBackgroundService();

  @override
  void onInit() {
    super.onInit();
    _setup();
  }

  Future<void> _setup() async {
    await _requestPermissions();
    await _initializeService();
    isRunning.value = await service.isRunning();
  }

  Future<void> _requestPermissions() async {
    await Permission.locationWhenInUse.request();
    await Permission.locationAlways.request();
    if (Platform.isAndroid) {
      //await Permission.foregroundService.request();
      await Permission.notification.request();
    }
  }

  Future<void> _initializeService() async {
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'bg_service_channel',
        initialNotificationTitle: 'Tracking Location',
        initialNotificationContent: 'Service is running',
        foregroundServiceNotificationId: 888,
        onStart: _onStart,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  void startService() async {
    await service.startService();
    isRunning.value = true;
  }

  void stopService() {
    service.invoke("stop");
    isRunning.value = false;
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'bg_service_channel',
    'Background Service',
    description: 'Used for background location tracking',
    importance: Importance.defaultImportance,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Location Service Running",
      content: DateTime.now().toString(),
    );
  }

  final timer = Timer.periodic(const Duration(seconds: 15), (timer) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final response = await http.post(
        Uri.parse("https://your-api.com/location"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      log("📍 ${DateTime.now()}: ${position.latitude}, ${position.longitude} | status: ${response.statusCode}");
    } catch (e) {
      log("❌ Error fetching/sending location: $e");
    }
  });

  service.on('stop').listen((event) {
    timer.cancel();
    service.stopSelf();
  });
}
