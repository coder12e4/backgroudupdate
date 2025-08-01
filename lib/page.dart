import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controller.dart';

class LocationPage extends StatelessWidget {
  final controller = Get.find<ServiceController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Background Location Service")),
      body: Center(
        child: Obx(() => ElevatedButton(
          onPressed:
          controller.isRunning.value ? controller.stopService : controller.startService,
          child: Text(controller.isRunning.value ? "Stop Service" : "Start Service"),
        )),
      ),
    );
  }
}
