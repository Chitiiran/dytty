import 'package:flutter/material.dart';

import 'package:dytty/app.dart';
import 'package:dytty/services/notification/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const DyttyApp());
}
