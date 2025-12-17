import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SPUtil {
  static SharedPreferences? prefs;

  static Future<void> initSharedPreferences() async {
    // WidgetsFlutterBinding.ensureInitialized();
    prefs = await SharedPreferences.getInstance();
  }


  static bool getBool(String key, {required bool defaultValue}) {
    return prefs?.getBool(key) ?? defaultValue;
  }

  static void setBool(String key, bool value) {
    prefs?.setBool(key, value);
  }

  static int getInt(String key, int defaultValue) {
    return prefs?.getInt(key) ?? defaultValue;
  }

  static void setInt(String key, int value) {
    prefs?.setInt(key, value);
  }

  static String? getString(String key, {required String? defaultValue}) {
    return prefs?.getString(key) ?? defaultValue;
  }

  static void setString(String key, String value) {
    prefs?.setString(key, value);
  }

  static void remove(String key) {
    prefs?.remove(key);
  }
}
