class RoomInfo {
  final String id;
  final String name;
  final String? streamUrl;
  final List<String> activeBots;

  RoomInfo({
    required this.id,
    required this.name,
    this.streamUrl,
    this.activeBots = const [],
  });

  factory RoomInfo.fromJson(Map<String, dynamic> json) {
    return RoomInfo(
      id: json['id']?.toString() ?? json['room_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['room_name']?.toString() ?? 'Room',
      streamUrl: json['stream_url']?.toString(),
      activeBots: (json['active_bots'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class Position3D {
  final double x;
  final double y;
  final double z;
  final String facing;

  Position3D({
    required this.x,
    required this.y,
    required this.z,
    this.facing = 'FrontRight',
  });

  factory Position3D.fromJson(Map<String, dynamic> json) {
    return Position3D(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      z: (json['z'] as num?)?.toDouble() ?? 0.0,
      facing: json['facing']?.toString() ?? 'FrontRight',
    );
  }
}

class LiveUser {
  final String id;
  final String username;
  final String displayName;
  final Position3D position;
  final String role;
  final bool isModerator;
  final bool isDesigner;
  final bool isBot;

  LiveUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.position,
    this.role = 'Member',
    this.isModerator = false,
    this.isDesigner = false,
    this.isBot = false,
  });

  factory LiveUser.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> posJson = {};
    if (json['position'] is Map<String, dynamic>) {
      posJson = json['position'] as Map<String, dynamic>;
    } else if (json['pos'] is Map<String, dynamic>) {
      posJson = json['pos'] as Map<String, dynamic>;
    } else {
      posJson = {
        'x': json['x'],
        'y': json['y'],
        'z': json['z'],
        'facing': json['facing'],
      };
    }

    final uname = json['username']?.toString() ?? json['name']?.toString() ?? 'User';
    final isBotUser = uname.toLowerCase().contains('bot') || uname.startsWith('!');

    return LiveUser(
      id: json['id']?.toString() ?? json['user_id']?.toString() ?? '',
      username: uname,
      displayName: json['display_name']?.toString() ?? uname,
      position: Position3D.fromJson(posJson),
      role: json['role']?.toString() ?? 'Member',
      isModerator: json['moderator'] == true || json['is_moderator'] == true,
      isDesigner: json['designer'] == true || json['is_designer'] == true,
      isBot: json['is_bot'] == true || isBotUser,
    );
  }
}

class RoomChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isBot;
  final Position3D? speakerPosition;

  RoomChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    this.isBot = false,
    this.speakerPosition,
  });

  factory RoomChatMessage.fromJson(Map<String, dynamic> json) {
    return RoomChatMessage(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: json['user_id']?.toString() ?? '',
      senderName: json['username']?.toString() ?? 'Unknown',
      message: json['message']?.toString() ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now() 
          : DateTime.now(),
      isBot: json['is_bot'] == true,
      speakerPosition: json['position'] != null ? Position3D.fromJson(json['position']) : null,
    );
  }
}

class BotHealth {
  final int botNum;
  final String name;
  final String role;
  final bool isOnline;
  final int pingMs;
  final double memoryMb;
  final String currentRoom;

  BotHealth({
    required this.botNum,
    required this.name,
    required this.role,
    required this.isOnline,
    this.pingMs = 0,
    this.memoryMb = 0.0,
    this.currentRoom = '',
  });

  factory BotHealth.fromJson(Map<String, dynamic> json) {
    return BotHealth(
      botNum: (json['bot_num'] as num?)?.toInt() ?? 1,
      name: json['name']?.toString() ?? 'Bot',
      role: json['role']?.toString() ?? 'General',
      isOnline: json['online'] == true || json['status'] == 'online',
      pingMs: (json['ping_ms'] as num?)?.toInt() ?? 0,
      memoryMb: (json['memory_mb'] as num?)?.toDouble() ?? 0.0,
      currentRoom: json['room']?.toString() ?? '',
    );
  }
}

class ServerStatus {
  final int uptimeSeconds;
  final double cpuPercent;
  final double memoryMb;
  final int totalBots;
  final int onlineBots;
  final List<BotHealth> bots;

  ServerStatus({
    required this.uptimeSeconds,
    this.cpuPercent = 0.0,
    this.memoryMb = 0.0,
    this.totalBots = 6,
    this.onlineBots = 0,
    this.bots = const [],
  });

  factory ServerStatus.fromJson(Map<String, dynamic> json) {
    final rawBots = json['bots'] as List<dynamic>? ?? [];
    final botsList = rawBots.map((b) => BotHealth.fromJson(b as Map<String, dynamic>)).toList();
    final onlineCount = botsList.where((b) => b.isOnline).length;

    return ServerStatus(
      uptimeSeconds: (json['uptime_seconds'] as num?)?.toInt() ?? 0,
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0.0,
      memoryMb: (json['memory_mb'] as num?)?.toDouble() ?? 0.0,
      totalBots: botsList.isNotEmpty ? botsList.length : 6,
      onlineBots: json['online_bots'] != null ? (json['online_bots'] as num).toInt() : onlineCount,
      bots: botsList,
    );
  }
}

class SongTrack {
  final String title;
  final String artist;
  final int durationSeconds;
  final String? url;
  final String addedBy;

  SongTrack({
    required this.title,
    this.artist = 'Unknown Artist',
    this.durationSeconds = 0,
    this.url,
    this.addedBy = 'System',
  });

  factory SongTrack.fromJson(Map<String, dynamic> json) {
    return SongTrack(
      title: json['title']?.toString() ?? 'Unknown Title',
      artist: json['artist']?.toString() ?? 'Unknown Artist',
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
      url: json['url']?.toString(),
      addedBy: json['added_by']?.toString() ?? 'System',
    );
  }
}

class RadioState {
  final bool isPlaying;
  final SongTrack? currentTrack;
  final int elapsedSeconds;
  final List<SongTrack> queue;
  final String streamUrl;
  final double volume;

  RadioState({
    this.isPlaying = false,
    this.currentTrack,
    this.elapsedSeconds = 0,
    this.queue = const [],
    this.streamUrl = '',
    this.volume = 1.0,
  });

  factory RadioState.fromJson(Map<String, dynamic> json) {
    final rawQueue = json['queue'] as List<dynamic>? ?? [];
    return RadioState(
      isPlaying: json['is_playing'] == true || json['status'] == 'playing',
      currentTrack: json['current_track'] != null ? SongTrack.fromJson(json['current_track']) : null,
      elapsedSeconds: (json['elapsed_seconds'] as num?)?.toInt() ?? 0,
      queue: rawQueue.map((t) => SongTrack.fromJson(t as Map<String, dynamic>)).toList(),
      streamUrl: json['stream_url']?.toString() ?? '',
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class GameStatus {
  final String gameName;
  final bool isRunning;
  final int playersCount;
  final Map<String, dynamic> stateDetails;

  GameStatus({
    required this.gameName,
    this.isRunning = false,
    this.playersCount = 0,
    this.stateDetails = const {},
  });

  factory GameStatus.fromJson(Map<String, dynamic> json) {
    return GameStatus(
      gameName: json['game_name']?.toString() ?? 'Unknown Game',
      isRunning: json['is_running'] == true || json['status'] == 'active',
      playersCount: (json['players_count'] as num?)?.toInt() ?? 0,
      stateDetails: json['details'] as Map<String, dynamic>? ?? {},
    );
  }
}

class ChatyStatus {
  final int queuedCount;
  final int activeSessionsCount;
  final int totalMatchesToday;

  ChatyStatus({
    this.queuedCount = 0,
    this.activeSessionsCount = 0,
    this.totalMatchesToday = 0,
  });

  factory ChatyStatus.fromJson(Map<String, dynamic> json) {
    return ChatyStatus(
      queuedCount: (json['queued_users'] as num?)?.toInt() ?? 0,
      activeSessionsCount: (json['active_sessions'] as num?)?.toInt() ?? 0,
      totalMatchesToday: (json['total_matches'] as num?)?.toInt() ?? 0,
    );
  }
}

class LogEntry {
  final DateTime timestamp;
  final String level;
  final String message;
  final String logger;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.logger = 'System',
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: json['timestamp'] != null 
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      level: json['level']?.toString().toUpperCase() ?? 'INFO',
      message: json['message']?.toString() ?? '',
      logger: json['logger']?.toString() ?? 'System',
    );
  }
}

class ServerProfile {
  final String id;
  final String name;
  final String url;
  final String password;

  ServerProfile({
    required this.id,
    required this.name,
    required this.url,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'password': password,
  };

  factory ServerProfile.fromJson(Map<String, dynamic> json) {
    return ServerProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Wispbyte Server',
      url: json['url']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
    );
  }
}
