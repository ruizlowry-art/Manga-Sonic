import 'package:hive/hive.dart';

class SettingsDB {
  static const String settingsBoxName = 'app_settings';
  static const String aeroBallXKey = 'aero_ball_x';
  static const String aeroBallYKey = 'aero_ball_y';

  static Future<void> init() async {
    await Hive.openBox(settingsBoxName);
  }

  static double? getAeroBallX() {
    return Hive.box(settingsBoxName).get(aeroBallXKey);
  }

  static double? getAeroBallY() {
    return Hive.box(settingsBoxName).get(aeroBallYKey);
  }

  static Future<void> saveAeroBallPosition(double x, double y) async {
    final box = Hive.box(settingsBoxName);
    await box.put(aeroBallXKey, x);
    await box.put(aeroBallYKey, y);
  }
}
