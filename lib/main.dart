import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  await initializeService();
  runApp(const MyApp());
}


Future<void> _requestPermissions() async {
  await Permission.locationWhenInUse.request();
  await Permission.locationAlways.request();

  // Android 14+ requirement
 // await Permission.foregroundService.request();

  // Android 13+ for notifications
  await Permission.notification.request();
}



Future<void> initializeService() async {
  final service = FlutterBackgroundService();

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
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
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
        }),
      );

      log("📡 Sent: ${position.latitude}, ${position.longitude}, status: ${response.statusCode}");
    } catch (e) {
      log("❌ Background location failure: $e");
    }
  });

  service.on('stop').listen((event) {
    timer.cancel();
    service.stopSelf();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: LocationPage());
  }
}

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});
  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  bool isRunning = false;
  final service = FlutterBackgroundService();

  @override
  void initState() {
    super.initState();
    service.isRunning().then((value) => setState(() => isRunning = value));
  }

  void _startService() {
    service.startService();
    setState(() => isRunning = true);
  }

  void _stopService() {
    service.invoke("stop");
    setState(() => isRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Background Location Service")),
      body: Center(
        child: ElevatedButton(
          onPressed: isRunning ? _stopService : _startService,
          child: Text(isRunning ? "Stop Service" : "Start Service"),
        ),
      ),
    );
  }
}
