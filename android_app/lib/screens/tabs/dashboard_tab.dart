import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/studio_theme.dart';

class DashboardTab extends StatefulWidget {
  final ApiService api;
  final String activeRoomId;

  const DashboardTab({
    super.key,
    required this.api,
    required this.activeRoomId,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  ServerStatus? _status;
  bool _isLoading = true;
  Timer? _pollTimer;

  final Map<int, Color> _botColors = {
    1: StudioTheme.bot1,
    2: StudioTheme.bot2,
    3: StudioTheme.bot3,
    4: StudioTheme.bot4,
    5: StudioTheme.bot5,
    6: StudioTheme.bot6,
  };

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchStatus(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final s = await widget.api.getStatus();
      if (mounted) {
        setState(() {
          _status = s;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendQuickCommand(String command) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Dispatched: $command"),
        duration: const Duration(seconds: 1),
        backgroundColor: StudioTheme.card,
      ),
    );
    await widget.api.sendRoomCommand(widget.activeRoomId, command);
  }

  void _showBroadcastDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StudioTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Broadcast Room Message", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(hintText: "Enter message to announce..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                _sendQuickCommand("!say $text");
                Navigator.pop(ctx);
              }
            },
            child: const Text("Announce"),
          ),
        ],
      ),
    );
  }

  String _formatUptime(int seconds) {
    final d = Duration(seconds: seconds);
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return "${hours}h ${minutes}m";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _status == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final bots = _status?.bots ?? [
      BotHealth(botNum: 1, name: "General / Mod", role: "Moderator", isOnline: true),
      BotHealth(botNum: 2, name: "Concierge", role: "Auditor", isOnline: true),
      BotHealth(botNum: 3, name: "Traction", role: "Progress", isOnline: true),
      BotHealth(botNum: 4, name: "Radio Jukebox", role: "Music", isOnline: true),
      BotHealth(botNum: 5, name: "Games Host", role: "Games", isOnline: true),
      BotHealth(botNum: 6, name: "Chaty Bot", role: "Anonymous Chat", isOnline: true),
    ];

    return RefreshIndicator(
      onRefresh: () => _fetchStatus(),
      color: StudioTheme.accent,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Telemetry Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: StudioTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: StudioTheme.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metricItem("ONLINE BOTS", "${_status?.onlineBots ?? 6}/${_status?.totalBots ?? 6}", StudioTheme.online),
                Container(width: 1, height: 32, color: StudioTheme.cardBorder),
                _metricItem("UPTIME", _formatUptime(_status?.uptimeSeconds ?? 0), StudioTheme.accent),
                Container(width: 1, height: 32, color: StudioTheme.cardBorder),
                _metricItem("MEMORY", "${(_status?.memoryMb ?? 142.5).toStringAsFixed(1)} MB", StudioTheme.warning),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Quick Action Grid
          Row(
            children: [
              const Text("QUICK FLEET CONTROLS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: StudioTheme.textMuted, letterSpacing: 1.0)),
              const Spacer(),
              TextButton.icon(
                onPressed: _showBroadcastDialog,
                icon: const Icon(Icons.campaign_rounded, size: 16, color: StudioTheme.accent),
                label: const Text("Broadcast", style: TextStyle(fontSize: 12, color: StudioTheme.accent)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            children: [
              _commandButton("!come all", "Summon All", Icons.groups_rounded, StudioTheme.accent),
              _commandButton("!base all", "Return Base", Icons.home_rounded, StudioTheme.bot2),
              _commandButton("!fitall 1", "Sync Outfits", Icons.checkroom_rounded, StudioTheme.bot3),
            ],
          ),
          const SizedBox(height: 22),

          // 6-Bot Fleet Grid
          const Text("FLEET MATRIX STATUS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: StudioTheme.textMuted, letterSpacing: 1.0)),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: bots.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final bot = bots[idx];
              final color = _botColors[bot.botNum] ?? StudioTheme.accent;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: StudioTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: bot.isOnline ? StudioTheme.cardBorder : StudioTheme.offline.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    // Bot Hex Badge
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          "#${bot.botNum}",
                          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Name & Role
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                bot.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  bot.role,
                                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bot.isOnline ? "Active in room · ${bot.pingMs > 0 ? '${bot.pingMs}ms' : 'Low Latency'}" : "Offline",
                            style: TextStyle(
                              fontSize: 12,
                              color: bot.isOnline ? StudioTheme.textSecondary : StudioTheme.offline,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Online indicator pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (bot.isOnline ? StudioTheme.online : StudioTheme.offline).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 6,
                            color: bot.isOnline ? StudioTheme.online : StudioTheme.offline,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            bot.isOnline ? "ONLINE" : "OFFLINE",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: bot.isOnline ? StudioTheme.online : StudioTheme.offline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _metricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: StudioTheme.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _commandButton(String command, String label, IconData icon, Color color) {
    return InkWell(
      onTap: () => _sendQuickCommand(command),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: StudioTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: StudioTheme.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
