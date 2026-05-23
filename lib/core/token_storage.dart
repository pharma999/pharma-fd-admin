import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _tokenKey = 'provider_token';
  static const _userIdKey = 'provider_user_id';
  static const _roleKey = 'provider_role';
  static const _nameKey = 'provider_name';
  static const _nurseIdKey = 'provider_nurse_id';
  static const _providerTypeKey = 'provider_type';
  static const _approvalStatusKey = 'provider_approval_status';
  static const _phoneKey = 'provider_phone';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<void> saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey);
  }

  static Future<void> saveNurseId(String nurseId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nurseIdKey, nurseId);
  }

  static Future<String?> getNurseId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nurseIdKey);
  }

  static Future<void> saveProviderType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerTypeKey, type);
  }

  static Future<String?> getProviderType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_providerTypeKey);
  }

  static Future<void> saveApprovalStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_approvalStatusKey, status);
  }

  static Future<String?> getApprovalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_approvalStatusKey);
  }

  static Future<void> savePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, phone);
  }

  static Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_nurseIdKey);
    await prefs.remove(_providerTypeKey);
    await prefs.remove(_approvalStatusKey);
    await prefs.remove(_phoneKey);
  }

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
