import 'package:flutter/foundation.dart';

class Constants {
  static const String title = "RGB Light Control";
  static final String apiRoot = kReleaseMode ? "${Uri.base}api" : "http://localhost:11647/api";
}
