import 'package:web/web.dart' as web;

Future<String?> appStorageGetString(String key) async {
  return web.window.localStorage.getItem(key);
}

Future<void> appStorageSetString(String key, String value) async {
  web.window.localStorage.setItem(key, value);
}

Future<void> appStorageRemove(String key) async {
  web.window.localStorage.removeItem(key);
}
