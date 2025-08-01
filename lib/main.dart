import 'package:backgroudupdate/page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(ServiceController()); // Inject controller before runApp
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Background Location',
      home: LocationPage(),
    );
  }
}
