import 'package:shared_preferences/shared_preferences.dart';

Future<String?> appStorageGetString(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

Future<void> appStorageSetString(String key, String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

Future<void> appStorageRemove(String key) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(key);
}
