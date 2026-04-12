import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _kToken = 'admin_token';
  static const _kUserId = 'admin_user_id';
  static const _kRole = 'admin_role';
  static const _kName = 'admin_name';

  static Future<void> save({
    required String token,
    required String userId,
    required String role,
    required String name,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
    await p.setString(_kUserId, userId);
    await p.setString(_kRole, role);
    await p.setString(_kName, name);
  }

  static Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString(_kToken);

  static Future<String?> getUserId() async =>
      (await SharedPreferences.getInstance()).getString(_kUserId);

  static Future<String?> getRole() async =>
      (await SharedPreferences.getInstance()).getString(_kRole);

  static Future<String?> getName() async =>
      (await SharedPreferences.getInstance()).getString(_kName);

  static Future<bool> isLoggedIn() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kUserId);
    await p.remove(_kRole);
    await p.remove(_kName);
  }
}
