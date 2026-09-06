import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/studio_theme.dart';
import '../../widgets/virtual_room_canvas.dart';

class LiveRoomTab extends StatefulWidget {
  final ApiService api;
  final String activeRoomId;

  const LiveRoomTab({
    super.key,
    required this.api,
    required this.activeRoomId,
  });

  @override
  State<LiveRoomTab> createState() => _LiveRoomTabState();
}

class _LiveRoomTabState extends State<LiveRoomTab> {
  List<LiveUser> _users = [];
  final List<RoomChatMessage> _chats = [];
  LiveUser? _selectedUser;
  bool _isLoading = true;
  bool _is3DView = true;
  Timer? _pollTimer;

  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchLiveRoom();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchLiveRoom(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveRoom({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final u = await widget.api.getLiveUsers(widget.activeRoomId);
      if (mounted) {
        setState(() {
          _users = u;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendRoomChat() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;

    _chatInputController.clear();
    final newMsg = RoomChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'admin_studio',
      senderName: 'Bot 1 (Mod)',
      message: text,
      timestamp: DateTime.now(),
      isBot: true,
    );

    setState(() {
      _chats.add(newMsg);
    });

    _scrollChatToBottom();
    await widget.api.sendRoomCommand(widget.activeRoomId, "!say $text");
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openModerationSheet(LiveUser user) {
    setState(() => _selectedUser = user);

    showModalBottomSheet(
      context: context,
      backgroundColor: StudioTheme.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & User Info
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: StudioTheme.accent.withOpacity(0.2),
                    radius: 20,
                    child: Text(
                      user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: StudioTheme.accent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        Text(
                          "Pos: (${user.position.x.toStringAsFixed(1)}, ${user.position.y.toStringAsFixed(1)}, ${user.position.z.toStringAsFixed(1)}) · Role: ${user.role}",
                          style: const TextStyle(fontSize: 11, color: StudioTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: StudioTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: StudioTheme.cardBorder, height: 24),

              // Teleport Controls
              const Text("TELEPORTATION & POSITIONING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: StudioTheme.textMuted, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.api.sendRoomCommand(widget.activeRoomId, "!summon @${user.username}");
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.call_made_rounded, size: 16),
                      label: const Text("Summon Here"),
                      style: ElevatedButton.styleFrom(backgroundColor: StudioTheme.surface, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.api.sendRoomCommand(widget.activeRoomId, "!tele @${user.username} ${user.position.x} ${user.position.y} ${user.position.z}");
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.pin_drop_rounded, size: 16),
                      label: const Text("Goto Player"),
                      style: ElevatedButton.styleFrom(backgroundColor: StudioTheme.surface, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Highrise RPC Room Privileges
              const Text("OFFICIAL HIGHRISE PRIVILEGES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: StudioTheme.textMuted, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final cmd = user.isModerator ? "!rmod @${user.username}" : "!mod @${user.username}";
                        widget.api.sendRoomCommand(widget.activeRoomId, cmd);
                        Navigator.pop(ctx);
                      },
                      icon: Icon(Icons.shield_rounded, size: 16, color: user.isModerator ? StudioTheme.offline : StudioTheme.accent),
                      label: Text(user.isModerator ? "Revoke Mod" : "Grant Mod"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: user.isModerator ? StudioTheme.offline : StudioTheme.accent,
                        side: BorderSide(color: user.isModerator ? StudioTheme.offline : StudioTheme.accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final cmd = user.isDesigner ? "!rdesigner @${user.username}" : "!designer @${user.username}";
                        widget.api.sendRoomCommand(widget.activeRoomId, cmd);
                        Navigator.pop(ctx);
                      },
                      icon: Icon(Icons.brush_rounded, size: 16, color: user.isDesigner ? StudioTheme.offline : StudioTheme.bot4),
                      label: Text(user.isDesigner ? "Revoke Designer" : "Grant Designer"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: user.isDesigner ? StudioTheme.offline : StudioTheme.bot4,
                        side: BorderSide(color: user.isDesigner ? StudioTheme.offline : StudioTheme.bot4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Moderation Actions
              const Text("ROOM MODERATION ACTIONS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: StudioTheme.textMuted, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.api.sendRoomCommand(widget.activeRoomId, "!mute @${user.username} 300");
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.volume_off_rounded, size: 16),
                      label: const Text("Mute 5m"),
                      style: ElevatedButton.styleFrom(backgroundColor: StudioTheme.warning, foregroundColor: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.api.sendRoomCommand(widget.activeRoomId, "!kick @${user.username} Admin Action");
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.no_meeting_room_rounded, size: 16),
                      label: const Text("Kick"),
                      style: ElevatedButton.styleFrom(backgroundColor: StudioTheme.offline, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.api.sendRoomCommand(widget.activeRoomId, "!ban @${user.username} Admin Ban");
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.gavel_rounded, size: 16),
                      label: const Text("Ban"),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF991B1B), foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Mode Switcher Bar (3D Radar vs Player List)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: StudioTheme.surface,
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: StudioTheme.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: StudioTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    _viewToggleItem("3D Room Radar", Icons.view_in_ar_rounded, _is3DView, () => setState(() => _is3DView = true)),
                    _viewToggleItem("Player List", Icons.format_list_bulleted_rounded, !_is3DView, () => setState(() => _is3DView = false)),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: StudioTheme.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, size: 14, color: StudioTheme.accent),
                    const SizedBox(width: 6),
                    Text(
                      "${_users.length} Live Players",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: StudioTheme.accent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Main Content Area
        Expanded(
          child: _is3DView
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: VirtualRoomCanvas(
                    users: _users,
                    recentChats: _chats,
                    selectedUser: _selectedUser,
                    onUserTapped: _openModerationSheet,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final u = _users[idx];
                    return InkWell(
                      onTap: () => _openModerationSheet(u),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: StudioTheme.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: StudioTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: StudioTheme.accent.withOpacity(0.2),
                              child: Text(
                                u.username.isNotEmpty ? u.username[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: StudioTheme.accent),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.username, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                                  Text("(${u.position.x.toStringAsFixed(1)}, ${u.position.y.toStringAsFixed(1)}, ${u.position.z.toStringAsFixed(1)})", style: const TextStyle(fontSize: 11, color: StudioTheme.textMuted)),
                                ],
                              ),
                            ),
                            if (u.isModerator)
                              _badge("MOD", StudioTheme.accent),
                            if (u.isDesigner)
                              _badge("DESIGNER", StudioTheme.bot4),
                            const SizedBox(width: 8),
                            const Icon(Icons.more_vert, size: 16, color: StudioTheme.textMuted),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Bottom Live Room Chat Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: StudioTheme.surface,
            border: Border(top: BorderSide(color: StudioTheme.cardBorder)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Chat messages preview
              if (_chats.isNotEmpty)
                Container(
                  height: 48,
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListView.builder(
                    controller: _chatScrollController,
                    itemCount: _chats.length,
                    itemBuilder: (context, idx) {
                      final c = _chats[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 11),
                            children: [
                              TextSpan(
                                text: "${c.senderName}: ",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: c.isBot ? StudioTheme.accent : StudioTheme.textSecondary,
                                ),
                              ),
                              TextSpan(text: c.message, style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Chat Input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatInputController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Chat in room as Bot...",
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                        fillColor: StudioTheme.card,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send_rounded, size: 18, color: StudioTheme.accent),
                          onPressed: _sendRoomChat,
                        ),
                      ),
                      onSubmitted: (_) => _sendRoomChat(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _viewToggleItem(String title, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? StudioTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF0F172A) : StudioTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? const Color(0xFF0F172A) : StudioTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
