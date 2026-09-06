import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../theme/studio_theme.dart';
import 'login_screen.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/live_room_tab.dart';
import 'tabs/radio_tab.dart';
import 'tabs/games_chaty_tab.dart';
import 'tabs/system_tab.dart';

class MainNavigationScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService api;
  final LiveAudioService? audioService;

  const MainNavigationScreen({
    super.key,
    required this.storage,
    required this.api,
    this.audioService,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  List<RoomInfo> _rooms = [];
  String _activeRoomId = '';
  String _activeRoomName = 'Main Room';
  bool _isLoadingRooms = true;
  Timer? _roomPollTimer;
  late LiveAudioService _audioService;
  bool _ownsAudioService = false;

  @override
  void initState() {
    super.initState();
    if (widget.audioService != null) {
      _audioService = widget.audioService!;
    } else {
      _audioService = LiveAudioService();
      _ownsAudioService = true;
    }

    _activeRoomId = widget.storage.getActiveRoomId();
    _fetchRooms();
    _roomPollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchRooms());
  }

  @override
  void dispose() {
    _roomPollTimer?.cancel();
    if (_ownsAudioService) {
      _audioService.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchRooms() async {
    try {
      final fetched = await widget.api.getRooms();
      if (mounted) {
        setState(() {
          _rooms = fetched;
          _isLoadingRooms = false;
          if (_rooms.isNotEmpty) {
            final match = _rooms.where((r) => r.id == _activeRoomId).firstOrNull;
            if (match != null) {
              _activeRoomName = match.name;
            } else if (_activeRoomId.isEmpty) {
              _activeRoomId = _rooms.first.id;
              _activeRoomName = _rooms.first.name;
              widget.storage.setActiveRoomId(_activeRoomId);
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRooms = false);
    }
  }

  void _onRoomSelected(RoomInfo room) {
    setState(() {
      _activeRoomId = room.id;
      _activeRoomName = room.name;
    });
    widget.storage.setActiveRoomId(room.id);
  }

  void _showAddRoomDialog() {
    final idController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StudioTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.meeting_room_rounded, color: StudioTheme.accentSky),
            SizedBox(width: 8),
            Text('Add New Room', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Room Name',
                labelStyle: const TextStyle(color: StudioTheme.textMuted),
                hintText: 'e.g. VIP Lounge',
                hintStyle: const TextStyle(color: StudioTheme.textMuted),
                filled: true,
                fillColor: StudioTheme.cardDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Room ID',
                labelStyle: const TextStyle(color: StudioTheme.textMuted),
                hintText: 'e.g. 64239850162...',
                hintStyle: const TextStyle(color: StudioTheme.textMuted),
                filled: true,
                fillColor: StudioTheme.cardDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: StudioTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: StudioTheme.accentSky,
              foregroundColor: StudioTheme.bgDark,
            ),
            onPressed: () async {
              final id = idController.text.trim();
              final name = nameController.text.trim().isEmpty ? 'Custom Room' : nameController.text.trim();
              if (id.isNotEmpty) {
                Navigator.pop(ctx);
                final newRoom = RoomInfo(id: id, name: name);
                setState(() {
                  _rooms.add(newRoom);
                  _activeRoomId = id;
                  _activeRoomName = name;
                });
                widget.storage.setActiveRoomId(id);

                // Write new room to server config.yaml!
                final ok = await widget.api.addRoomToConfig(id, name);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Room "$name" added and saved to config.yaml!' : 'Room "$name" activated locally'),
                      backgroundColor: ok ? StudioTheme.accentEmerald : StudioTheme.accentYellow,
                    ),
                  );
                }
              }
            },
            child: const Text('Add & Switch', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StudioTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Disconnect Server?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Do you want to switch servers or log out from Highrise Studio?',
          style: TextStyle(color: StudioTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: StudioTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: StudioTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.storage.clearCredentials();
              await _audioService.stop();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(
                      storage: widget.storage,
                      api: widget.api,
                    ),
                  ),
                );
              }
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 74, // Extended downwards by several pixels for spacious, premium touch target
        backgroundColor: StudioTheme.surfaceDark,
        elevation: 0,
        titleSpacing: 14,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: StudioTheme.borderDark.withOpacity(0.6),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // App Branding & Pulsing Live Indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: StudioTheme.accentSky.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: StudioTheme.accentSky.withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(Icons.bolt, color: StudioTheme.accentSky, size: 20),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'HIGHRISE STUDIO',
                      style: TextStyle(
                        fontSize: isCompact ? 13 : 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: StudioTheme.accentEmerald,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: StudioTheme.accentEmerald.withOpacity(0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'FLEET CONNECTED',
                          style: TextStyle(
                            fontSize: isCompact ? 8.5 : 10,
                            color: StudioTheme.accentEmerald,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Multi-Room Switcher Dropdown (Responsive width constraint)
              PopupMenuButton<RoomInfo>(
                color: StudioTheme.surfaceDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: StudioTheme.borderDark),
                ),
                onSelected: _onRoomSelected,
                itemBuilder: (context) {
                  final items = _rooms.map((room) {
                    final isSelected = room.id == _activeRoomId;
                    return PopupMenuItem<RoomInfo>(
                      value: room,
                      child: Row(
                        children: [
                          Icon(
                            Icons.meeting_room,
                            size: 16,
                            color: isSelected ? StudioTheme.accentSky : StudioTheme.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              room.name,
                              style: TextStyle(
                                color: isSelected ? StudioTheme.accentSky : Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check, color: StudioTheme.accentSky, size: 16),
                        ],
                      ),
                    );
                  }).toList();

                  return [
                    ...items,
                    const PopupMenuDivider(),
                    PopupMenuItem<RoomInfo>(
                      onTap: () => Future.delayed(Duration.zero, _showAddRoomDialog),
                      child: const Row(
                        children: [
                          Icon(Icons.add, color: StudioTheme.accentSky, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Add New Room...',
                            style: TextStyle(color: StudioTheme.accentSky, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: StudioTheme.cardDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: StudioTheme.borderDark),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.meeting_room, color: StudioTheme.accentSky, size: 14),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: (screenWidth * 0.28).clamp(80.0, 150.0),
                        ),
                        child: Text(
                          _activeRoomName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: StudioTheme.textMuted, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 2),

              // Disconnect Server button
              IconButton(
                icon: const Icon(Icons.power_settings_new, color: StudioTheme.textMuted, size: 20),
                tooltip: 'Disconnect / Switch Server',
                onPressed: _confirmLogout,
              ),
            ],
          ),
        ),
      ),

      // IndexedStack preserves tabs state (3D canvas, live chat history, etc.)
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardTab(api: widget.api, activeRoomId: _activeRoomId),
          LiveRoomTab(api: widget.api, activeRoomId: _activeRoomId),
          RadioTab(
            apiService: widget.api,
            audioService: _audioService,
            roomId: _activeRoomId,
          ),
          GamesChatyTab(
            apiService: widget.api,
            roomId: _activeRoomId,
          ),
          SystemTab(apiService: widget.api),
        ],
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: StudioTheme.surfaceDark,
          border: Border(top: BorderSide(color: StudioTheme.borderDark, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) => setState(() => _currentIndex = idx),
          backgroundColor: StudioTheme.surfaceDark,
          selectedItemColor: StudioTheme.accentSky,
          unselectedItemColor: StudioTheme.textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 10,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Fleet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.view_in_ar_rounded),
              label: '3D Room',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.music_note_rounded),
              label: 'Jukebox',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_esports_rounded),
              label: 'Games',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.terminal_rounded),
              label: 'System',
            ),
          ],
        ),
      ),
    );
  }
}
