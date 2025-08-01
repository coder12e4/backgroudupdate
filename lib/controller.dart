import 'dart:convert';
import 'dart:developer';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;

const String locationTaskKey = "backgroundLocationTask";

class LocationController extends GetxController {
  Future<void> requestPermissions() async {
    await Permission.locationWhenInUse.request();
    await Permission.locationAlways.request();

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    }
  }

  Future<void> initializeWorkManager() async {
    bool isInDebug = false;
    assert(isInDebug = true);

    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: isInDebug,
    );
  }

  void startBackgroundTask() {
    Workmanager().registerPeriodicTask(
      locationTaskKey,
      locationTaskKey,
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(seconds: 5),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    log("✅ Background task started");
  }

  void stopBackgroundTask() {
    Workmanager().cancelByUniqueName(locationTaskKey);
    log("🛑 Background task stopped");
  }
}

void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == locationTaskKey) {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          log("❌ Location permission not granted in background");
          return Future.value(false);
        }

        if (!await Geolocator.isLocationServiceEnabled()) {
          log("❌ Location services disabled in background");
          return Future.value(false);
        }

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

     /*   final response = await http.post(
          Uri.parse("https://your-api.com/location"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'lat': position.latitude,
            'lng': position.longitude,
          }),
        );

        log("📡 Sent location: ${position.latitude}, ${position.longitude}, status: ${response.statusCode}");
     */   return Future.value(true);
      } catch (e) {
        log("❌ Failed to send location: $e");
        return Future.value(false);
      }
    }
    return Future.value(false);
  });
}
