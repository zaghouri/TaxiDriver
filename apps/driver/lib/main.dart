import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'src/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Port between the UI isolate and the foreground-service isolate (location backup).
  FlutterForegroundTask.initCommunicationPort();
  runApp(const DriverApp());
}
