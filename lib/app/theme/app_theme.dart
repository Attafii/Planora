import 'package:flutter/material.dart';

import 'account_theme.dart';

export 'account_theme.dart';

abstract final class AppTheme {
  static ThemeData get light => PlanifyTheme.build(Brightness.light);
}
