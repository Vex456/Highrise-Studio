import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/studio_theme.dart';

class GamesChatyTab extends StatefulWidget {
  final ApiService apiService;
  final String roomId;

  const GamesChatyTab({
    super.key,
    required this.apiService,
    required this.roomId,
  });

  @override
  State<GamesChatyTab> createState() => _GamesChatyTabState();
}

class _GamesChatyTabState extends State<GamesChatyTab> {
  List<GameStatus> _games = [];
  ChatyStatus _chaty = ChatyStatus();
  bool _isLoading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchData());
  }

  @override
  void didUpdateWidget(covariant GamesChatyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _fetchData();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final gamesFuture = widget.apiService.getGamesStatus(widget.roomId);
      final chatyFuture = widget.apiService.getChatyStatus(widget.roomId);
      final res = await Future.wait([gamesFuture, chatyFuture]);

      if (mounted) {
        setState(() {
          _games = res[0] as List<GameStatus>;
          _chaty = res[1] as ChatyStatus;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleGame(String gameName, bool start) async {
    final action = start ? 'start' : 'stop';
    final ok = await widget.apiService.controlGame(widget.roomId, gameName, action);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$gameName ${start ? "started" : "stopped"} successfully'),
          backgroundColor: start ? StudioTheme.accentEmerald : StudioTheme.accentYellow,
        ),
      );
      _fetchData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to $action $gameName'),
          backgroundColor: StudioTheme.accentRed,
        ),
      );
    }
  }

  Future<void> _sendRoomCommand(String cmd) async {
    final ok = await widget.apiService.sendRoomCommand(widget.roomId, cmd);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent: $cmd'),
          backgroundColor: StudioTheme.accentSky,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: StudioTheme.accentSky));
    }

    final policeThief = _games.firstWhere(
      (g) => g.gameName.toLowerCase().contains('police'),
      orElse: () => GameStatus(gameName: 'Police & Thief', isRunning: false),
    );

    final wordChain = _games.firstWhere(
      (g) => g.gameName.toLowerCase().contains('word'),
      orElse: () => GameStatus(gameName: 'Word Chain', isRunning: false),
    );

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: StudioTheme.accentSky,
      backgroundColor: StudioTheme.surfaceDark,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.sports_esports, color: StudioTheme.accentPink, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Room Interactive Games',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: StudioTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: StudioTheme.borderDark),
                  ),
                  child: Text(
                    'Room: ${widget.roomId.isEmpty ? "Default" : widget.roomId}',
                    style: const TextStyle(color: StudioTheme.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Game 1: Police & Thief
            _buildPoliceThiefCard(policeThief),

            const SizedBox(height: 16),

            // Game 2: Word Chain
            _buildWordChainCard(wordChain),

            const SizedBox(height: 24),

            // Chaty 1-on-1 Blind Matchmaker Section
            Row(
              children: [
                const Icon(Icons.forum, color: StudioTheme.accentPurple, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Chaty 1-on-1 Blind Dating',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _buildChatyCard(),
          ],
        ),
      ),
    );
  }

  // Police & Thief Card
  Widget _buildPoliceThiefCard(GameStatus game) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: StudioTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: game.isRunning ? StudioTheme.accentSky.withOpacity(0.5) : StudioTheme.borderDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: StudioTheme.surfaceDark,
                ),
                child: const Icon(Icons.local_police, color: StudioTheme.accentSky, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Police & Thief',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      game.isRunning
                          ? 'Game active • ${game.playersCount} players currently in room'
                          : 'Inactive • Standby in room',
                      style: TextStyle(
                        color: game.isRunning ? StudioTheme.accentEmerald : StudioTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: game.isRunning,
                activeColor: StudioTheme.accentSky,
                activeTrackColor: StudioTheme.accentSky.withOpacity(0.4),
                inactiveTrackColor: StudioTheme.surfaceDark,
                onChanged: (val) => _toggleGame('Police & Thief', val),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Details grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StudioTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Cops', game.stateDetails['cops']?.toString() ?? '1', StudioTheme.accentSky),
                _buildStatDivider(),
                _buildStatItem('Robbers', game.stateDetails['robbers']?.toString() ?? 'Free', StudioTheme.accentYellow),
                _buildStatDivider(),
                _buildStatItem('Jailed', game.stateDetails['jailed']?.toString() ?? '0', StudioTheme.accentRed),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: StudioTheme.accentSky,
                    side: const BorderSide(color: StudioTheme.accentSky),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _sendRoomCommand('!police join'),
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Join As Cop', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: StudioTheme.accentYellow,
                    side: const BorderSide(color: StudioTheme.accentYellow),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _sendRoomCommand('!police start'),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Start Round', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Word Chain Card
  Widget _buildWordChainCard(GameStatus game) {
    final currentLetter = game.stateDetails['letter']?.toString() ?? 'A';
    final round = game.stateDetails['round']?.toString() ?? '0';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: StudioTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: game.isRunning ? StudioTheme.accentPink.withOpacity(0.5) : StudioTheme.borderDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: StudioTheme.surfaceDark,
                ),
                child: const Icon(Icons.spellcheck, color: StudioTheme.accentPink, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Word Chain (Shiritori)',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      game.isRunning
                          ? 'Active • Round $round • Target Letter: "$currentLetter"'
                          : 'Inactive • Standby in room',
                      style: TextStyle(
                        color: game.isRunning ? StudioTheme.accentEmerald : StudioTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: game.isRunning,
                activeColor: StudioTheme.accentPink,
                activeTrackColor: StudioTheme.accentPink.withOpacity(0.4),
                inactiveTrackColor: StudioTheme.surfaceDark,
                onChanged: (val) => _toggleGame('Word Chain', val),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StudioTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Target Letter', currentLetter.toUpperCase(), StudioTheme.accentPink),
                _buildStatDivider(),
                _buildStatItem('Chain Count', round, StudioTheme.accentSky),
                _buildStatDivider(),
                _buildStatItem('Turn Time', '15s', StudioTheme.accentYellow),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: StudioTheme.accentPink,
                    side: const BorderSide(color: StudioTheme.accentPink),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _sendRoomCommand('!word start'),
                  icon: const Icon(Icons.play_circle_outline, size: 16),
                  label: const Text('Start Chain', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: StudioTheme.textMuted,
                    side: const BorderSide(color: StudioTheme.borderDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _sendRoomCommand('!word skip'),
                  icon: const Icon(Icons.skip_next, size: 16),
                  label: const Text('Skip Turn', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Chaty Card
  Widget _buildChatyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: StudioTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StudioTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Anonymous Blind 1-on-1 Matching',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Bot matches two users anonymously in private teleport booths or whisper channels.',
            style: TextStyle(color: StudioTheme.textMuted, fontSize: 12),
          ),

          const SizedBox(height: 16),

          // Telemetry Row
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Waiting Queue',
                  '${_chaty.queuedCount}',
                  Icons.hourglass_top,
                  StudioTheme.accentYellow,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  'Active Pairs',
                  '${_chaty.activeSessionsCount}',
                  Icons.favorite,
                  StudioTheme.accentPink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  'Total Matches',
                  '${_chaty.totalMatchesToday}',
                  Icons.done_all,
                  StudioTheme.accentEmerald,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StudioTheme.accentPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _sendRoomCommand('!chaty announce'),
                  icon: const Icon(Icons.campaign, size: 18),
                  label: const Text('Announce In Room', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: StudioTheme.surfaceDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _sendRoomCommand('!chaty flush'),
                icon: const Icon(Icons.refresh, color: StudioTheme.textMuted),
                tooltip: 'Flush Waiting Queue',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: StudioTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StudioTheme.borderDark),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: StudioTheme.textMuted, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: StudioTheme.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 24, width: 1, color: StudioTheme.borderDark);
  }
}
