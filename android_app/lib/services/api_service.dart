import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'storage_service.dart';

class ApiService {
  final StorageService _storage;
  http.Client _client = http.Client();

  ApiService(this._storage);

  String get baseUrl => _normalizeUrl(_storage.getServerUrl());
  String get password => _storage.getAdminPassword();

  String _normalizeUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return '';
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (!u.endsWith('/api')) {
      u = '$u/api';
    }
    return u;
  }

  Map<String, String> _headers({bool jsonBody = true}) {
    final h = <String, String>{
      'Authorization': 'Bearer $password',
      'X-Admin-Token': password,
    };
    if (jsonBody) {
      h['Content-Type'] = 'application/json';
    }
    return h;
  }

  // Ping test
  Future<int> pingServer(String testUrl, String testPassword) async {
    final norm = _normalizeUrl(testUrl);
    final stopwatch = Stopwatch()..start();
    try {
      final res = await http.post(
        Uri.parse('$norm/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': testPassword}),
      ).timeout(const Duration(seconds: 4));
      stopwatch.stop();
      if (res.statusCode == 200 || res.statusCode == 401) {
        if (res.statusCode == 401) {
          throw Exception('Invalid admin password');
        }
        return stopwatch.elapsedMilliseconds;
      }
      throw Exception('Server returned ${res.statusCode}');
    } catch (e) {
      stopwatch.stop();
      rethrow;
    }
  }

  // Auth login
  Future<bool> login(String targetUrl, String targetPassword) async {
    final norm = _normalizeUrl(targetUrl);
    final res = await _client.post(
      Uri.parse('$norm/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': targetPassword}),
    ).timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      await _storage.setServerUrl(norm);
      await _storage.setAdminPassword(targetPassword);
      return true;
    } else if (res.statusCode == 401) {
      throw Exception('Invalid admin password');
    } else {
      throw Exception('Server returned ${res.statusCode}');
    }
  }

  // System Status
  Future<ServerStatus> getStatus() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/status'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return ServerStatus.fromJson(data);
    }
    throw Exception('Failed to fetch status: ${res.statusCode}');
  }

  // Multi-Room Listing
  Future<List<RoomInfo>> getRooms() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/rooms'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is List) {
        return data.map((r) => RoomInfo.fromJson(r as Map<String, dynamic>)).toList();
      } else if (data is Map && data['rooms'] is List) {
        return (data['rooms'] as List).map((r) => RoomInfo.fromJson(r as Map<String, dynamic>)).toList();
      }
      return [];
    }
    throw Exception('Failed to fetch rooms: ${res.statusCode}');
  }

  // Live Users & Positions in Room
  Future<List<LiveUser>> getLiveUsers(String roomId) async {
    final rid = roomId.isEmpty ? _storage.getActiveRoomId() : roomId;
    if (rid.isEmpty) return [];

    final res = await _client.get(
      Uri.parse('$baseUrl/rooms/$rid/users/live'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List raw = data is List ? data : (data['users'] as List? ?? []);
      return raw.map((u) => LiveUser.fromJson(u as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // Send Command or Chat into Room
  Future<bool> sendRoomCommand(String roomId, String command) async {
    final rid = roomId.isEmpty ? _storage.getActiveRoomId() : roomId;
    final res = await _client.post(
      Uri.parse('$baseUrl/rooms/$rid/command'),
      headers: _headers(),
      body: jsonEncode({'command': command}),
    ).timeout(const Duration(seconds: 5));

    return res.statusCode == 200;
  }

  // Radio Status
  Future<RadioState> getRadioStatus(String roomId) async {
    final rid = roomId.isEmpty ? _storage.getActiveRoomId() : roomId;
    try {
      final res = await _client.get(
        Uri.parse('$baseUrl/rooms/$rid/radio/np'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return RadioState.fromJson(data);
      }
    } catch (_) {}
    return RadioState();
  }

  // Radio Control
  Future<bool> controlRadio(String roomId, String action, [Map<String, dynamic>? params]) async {
    final rid = roomId.isEmpty ? _storage.getActiveRoomId() : roomId;
    final body = params ?? {};
    final res = await _client.post(
      Uri.parse('$baseUrl/rooms/$rid/radio/$action'),
      headers: _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 5));

    return res.statusCode == 200;
  }

  // Mini-Games Status
  Future<List<GameStatus>> getGamesStatus(String roomId) async {
    final rid = roomId.isEmpty ? _storage.getActiveRoomId() : roomId;
    try {
      final res = await _client.get(
        Uri.parse('$baseUrl/rooms/$rid/games'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List games = data is List ? data : (data['games'] as List? ?? []);
        return games.map((g) => GameStatus.fromJson(g as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [
      GameStatus(gameName: 'Police & Thief', isRunning: false),
      GameStatus(gameName: 'Word Chain', isRunning: false),
    ];
  }

  // Control Mini-Game
  Future<bool> controlGame(String roomId, String gameName, String action) async {
    final rid = roomId.isEmpty ? _storage.getActiveRoomId() : roomId;
    final cleanName = gameName.toLowerCase().replaceAll(' ', '_');
    final res = await _client.post(
      Uri.parse('$baseUrl/rooms/$rid/games/$cleanName/$action'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 5));

    return res.statusCode == 200;
  }

  // Chaty Bot Matchmaking Status
  Future<ChatyStatus> getChatyStatus(String roomId) async {
    final rid = roomId.isEmpty ? _storage.getActiveRoomId() : roomId;
    try {
      final res = await _client.get(
        Uri.parse('$baseUrl/rooms/$rid/chaty/status'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return ChatyStatus.fromJson(data);
      }
    } catch (_) {}
    return ChatyStatus();
  }

  // System Logs
  Future<List<LogEntry>> getLogs({String? level, int limit = 80}) async {
    final uri = Uri.parse('$baseUrl/logs').replace(queryParameters: {
      if (level != null && level != 'ALL') 'level': level,
      'limit': limit.toString(),
    });

    final res = await _client.get(uri, headers: _headers()).timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List logs = data is List ? data : (data['logs'] as List? ?? []);
      return logs.map((l) => LogEntry.fromJson(l as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // Raw YAML Config
  Future<String> getRawConfig() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/config/raw'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['content']?.toString() ?? res.body;
    }
    throw Exception('Failed to load config');
  }

  // Save Raw YAML Config
  Future<bool> saveRawConfig(String content) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/config/raw'),
      headers: _headers(),
      body: jsonEncode({'content': content}),
    ).timeout(const Duration(seconds: 8));

    return res.statusCode == 200;
  }

  // Append and persist a new room directly into server config.yaml
  Future<bool> addRoomToConfig(String roomId, String roomName, [List<int>? activeBots]) async {
    try {
      final bots = activeBots ?? [1, 2, 3, 4, 5, 6];
      String currentYaml = '';
      try {
        currentYaml = await getRawConfig();
      } catch (_) {}

      final newRoomYamlBlock = '''
  - id: "$roomId"
    name: "$roomName"
    enabled: true
    active_bots: [${bots.join(', ')}]
''';

      String updatedYaml;
      if (currentYaml.contains('rooms:')) {
        updatedYaml = currentYaml.replaceFirst('rooms:', 'rooms:$newRoomYamlBlock');
      } else {
        updatedYaml = '$currentYaml\nrooms:$newRoomYamlBlock';
      }

      return await saveRawConfig(updatedYaml);
    } catch (_) {
      return false;
    }
  }

  // Restart System
  Future<bool> restartSystem({bool hard = false}) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/system/restart'),
      headers: _headers(),
      body: jsonEncode({'mode': hard ? 'hard' : 'soft'}),
    ).timeout(const Duration(seconds: 8));

    return res.statusCode == 200;
  }
}
