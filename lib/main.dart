import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app/app.dart';
import 'core/services/app_session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final session = AppSession();
  runApp(PlanifyApp(session: session));
  session.restore();
}
