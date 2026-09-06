import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class StorageService {
  static const String _keyServerUrl = 'server_url';
  static const String _keyAdminPassword = 'admin_password';
  static const String _keyActiveRoomId = 'active_room_id';
  static const String _keyProfiles = 'server_profiles';
  static const String _keyAutoConnect = 'auto_connect';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  String getServerUrl() {
    return _prefs.getString(_keyServerUrl) ?? '';
  }

  Future<void> setServerUrl(String url) async {
    await _prefs.setString(_keyServerUrl, url.trim());
  }

  String getAdminPassword() {
    return _prefs.getString(_keyAdminPassword) ?? '';
  }

  Future<void> setAdminPassword(String password) async {
    await _prefs.setString(_keyAdminPassword, password.trim());
  }

  String getActiveRoomId() {
    return _prefs.getString(_keyActiveRoomId) ?? '';
  }

  Future<void> setActiveRoomId(String roomId) async {
    await _prefs.setString(_keyActiveRoomId, roomId.trim());
  }

  bool getAutoConnect() {
    return _prefs.getBool(_keyAutoConnect) ?? true;
  }

  Future<void> setAutoConnect(bool value) async {
    await _prefs.setBool(_keyAutoConnect, value);
  }

  List<ServerProfile> getProfiles() {
    final raw = _prefs.getStringList(_keyProfiles) ?? [];
    return raw.map((str) {
      try {
        return ServerProfile.fromJson(jsonDecode(str) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<ServerProfile>().toList();
  }

  Future<void> saveProfile(ServerProfile profile) async {
    final profiles = getProfiles();
    profiles.removeWhere((p) => p.id == profile.id || p.url == profile.url);
    profiles.insert(0, profile);
    final strList = profiles.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_keyProfiles, strList);
  }

  Future<void> deleteProfile(String profileId) async {
    final profiles = getProfiles();
    profiles.removeWhere((p) => p.id == profileId);
    final strList = profiles.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_keyProfiles, strList);
  }

  Future<void> clearCredentials() async {
    await _prefs.remove(_keyServerUrl);
    await _prefs.remove(_keyAdminPassword);
  }

  bool hasCredentials() {
    return getServerUrl().isNotEmpty && getAdminPassword().isNotEmpty;
  }
}
