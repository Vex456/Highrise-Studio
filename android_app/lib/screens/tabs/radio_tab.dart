import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/audio_service.dart';
import '../../theme/studio_theme.dart';

class RadioTab extends StatefulWidget {
  final ApiService apiService;
  final LiveAudioService audioService;
  final String roomId;

  const RadioTab({
    super.key,
    required this.apiService,
    required this.audioService,
    required this.roomId,
  });

  @override
  State<RadioTab> createState() => _RadioTabState();
}

class _RadioTabState extends State<RadioTab> with SingleTickerProviderStateMixin {
  RadioState _radioState = RadioState();
  bool _isLoading = true;
  Timer? _pollTimer;
  late AnimationController _rotationController;
  final TextEditingController _songInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _fetchRadio();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchRadio());
  }

  @override
  void didUpdateWidget(covariant RadioTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _fetchRadio();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _rotationController.dispose();
    _songInputController.dispose();
    super.dispose();
  }

  Future<void> _fetchRadio() async {
    try {
      final state = await widget.apiService.getRadioStatus(widget.roomId);
      if (mounted) {
        setState(() {
          _radioState = state;
          _isLoading = false;
        });
        if (state.isPlaying) {
          if (!_rotationController.isAnimating) {
            _rotationController.repeat();
          }
        } else {
          _rotationController.stop();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _sendControl(String action, [Map<String, dynamic>? params]) async {
    final ok = await widget.apiService.controlRadio(widget.roomId, action, params);
    if (ok) {
      await _fetchRadio();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to execute radio action: $action'),
            backgroundColor: StudioTheme.accentRed,
          ),
        );
      }
    }
  }

  void _showAddTrackDialog() {
    _songInputController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StudioTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.queue_music, color: StudioTheme.accentSky),
            SizedBox(width: 8),
            Text('Queue Song / Stream', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter YouTube URL, audio stream link, or song search title:',
              style: TextStyle(color: StudioTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _songInputController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'https://youtu.be/... or song name',
                hintStyle: const TextStyle(color: StudioTheme.textMuted),
                filled: true,
                fillColor: StudioTheme.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
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
            onPressed: () {
              final query = _songInputController.text.trim();
              if (query.isNotEmpty) {
                Navigator.pop(ctx);
                _sendControl('queue', {'query': query});
              }
            },
            child: const Text('Add to Queue', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: StudioTheme.accentSky));
    }

    final track = _radioState.currentTrack;
    final totalSec = (track?.durationSeconds ?? 0) > 0 ? track!.durationSeconds : 180;
    final elapsedSec = _radioState.elapsedSeconds.clamp(0, totalSec);
    final progress = elapsedSec / totalSec;

    return RefreshIndicator(
      onRefresh: _fetchRadio,
      color: StudioTheme.accentSky,
      backgroundColor: StudioTheme.surfaceDark,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Local Stream In-Ear Player Card
            _buildLocalPlayerCard(),

            const SizedBox(height: 16),

            // Main Now Playing Player Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: StudioTheme.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: StudioTheme.borderDark),
                boxShadow: [
                  BoxShadow(
                    color: StudioTheme.accentSky.withOpacity(0.05),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Animated Vinyl / Cassette Art
                  RotationTransition(
                    turns: _rotationController,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            StudioTheme.surfaceDark,
                            StudioTheme.bgDark,
                            StudioTheme.accentSky.withOpacity(0.4),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _radioState.isPlaying
                                ? StudioTheme.accentSky.withOpacity(0.3)
                                : Colors.transparent,
                            blurRadius: 18,
                            spreadRadius: 4,
                          ),
                        ],
                        border: Border.all(
                          color: _radioState.isPlaying ? StudioTheme.accentSky : StudioTheme.borderDark,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: StudioTheme.cardDark,
                          ),
                          child: const Icon(Icons.music_note, color: StudioTheme.accentSky, size: 24),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Track Info
                  Text(
                    track?.title ?? 'No Track Playing',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track?.artist ?? 'Queue is currently empty',
                    style: const TextStyle(
                      color: StudioTheme.textMuted,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (track != null && track.addedBy.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: StudioTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: StudioTheme.borderDark),
                      ),
                      child: Text(
                        'Requested by: ${track.addedBy}',
                        style: const TextStyle(color: StudioTheme.accentYellow, fontSize: 11),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Scrubber Bar
                  Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          activeTrackColor: StudioTheme.accentSky,
                          inactiveTrackColor: StudioTheme.surfaceDark,
                          thumbColor: StudioTheme.accentSky,
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (val) {
                            final seekSec = (val * totalSec).toInt();
                            _sendControl('seek', {'seconds': seekSec});
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(elapsedSec),
                              style: const TextStyle(color: StudioTheme.textMuted, fontSize: 12),
                            ),
                            Text(
                              _formatDuration(totalSec),
                              style: const TextStyle(color: StudioTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Player Transport Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.stop_rounded, color: StudioTheme.accentRed, size: 28),
                        onPressed: () => _sendControl('stop'),
                        tooltip: 'Stop Radio',
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: StudioTheme.accentSky,
                          boxShadow: [
                            BoxShadow(
                              color: StudioTheme.accentSky.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: IconButton(
                          iconSize: 36,
                          icon: Icon(
                            _radioState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: StudioTheme.bgDark,
                          ),
                          onPressed: () => _sendControl(_radioState.isPlaying ? 'pause' : 'resume'),
                          tooltip: _radioState.isPlaying ? 'Pause' : 'Play',
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 30),
                        onPressed: () => _sendControl('skip'),
                        tooltip: 'Skip Track',
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Room Volume Slider
                  Row(
                    children: [
                      const Icon(Icons.volume_down, color: StudioTheme.textMuted, size: 18),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                            activeTrackColor: StudioTheme.accentPurple,
                            inactiveTrackColor: StudioTheme.surfaceDark,
                            thumbColor: StudioTheme.accentPurple,
                          ),
                          child: Slider(
                            value: _radioState.volume.clamp(0.0, 1.0),
                            onChanged: (val) {
                              setState(() {
                                _radioState = RadioState(
                                  isPlaying: _radioState.isPlaying,
                                  currentTrack: _radioState.currentTrack,
                                  elapsedSeconds: _radioState.elapsedSeconds,
                                  queue: _radioState.queue,
                                  streamUrl: _radioState.streamUrl,
                                  volume: val,
                                );
                              });
                              _sendControl('volume', {'volume': val});
                            },
                          ),
                        ),
                      ),
                      const Icon(Icons.volume_up, color: StudioTheme.textMuted, size: 18),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Queue Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.queue_music, color: StudioTheme.accentSky, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Queue (${_radioState.queue.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_radioState.queue.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _sendControl('clear'),
                        icon: const Icon(Icons.delete_sweep, color: StudioTheme.accentRed, size: 16),
                        label: const Text('Clear', style: TextStyle(color: StudioTheme.accentRed, fontSize: 13)),
                      ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StudioTheme.surfaceDark,
                        foregroundColor: StudioTheme.accentSky,
                        side: const BorderSide(color: StudioTheme.accentSky, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: _showAddTrackDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Song', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Queue List
            if (_radioState.queue.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: StudioTheme.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: StudioTheme.borderDark),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.playlist_remove, color: StudioTheme.textMuted, size: 40),
                    SizedBox(height: 8),
                    Text(
                      'No tracks in queue',
                      style: TextStyle(color: StudioTheme.textMuted, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap "Add Song" to queue up music for the room',
                      style: TextStyle(color: StudioTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _radioState.queue.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _radioState.queue[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: StudioTheme.cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: StudioTheme.borderDark),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: StudioTheme.surfaceDark,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: StudioTheme.accentSky,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${item.artist}  •  ${_formatDuration(item.durationSeconds)}  •  by ${item.addedBy}',
                        style: const TextStyle(color: StudioTheme.textMuted, fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: StudioTheme.textMuted, size: 18),
                        onPressed: () => _sendControl('remove', {'index': index}),
                        tooltip: 'Remove from Queue',
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // Local phone stream player banner
  Widget _buildLocalPlayerCard() {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.audioService.isPlayingNotifier,
      builder: (context, isStreamingLocally, _) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isStreamingLocally
                ? StudioTheme.accentEmerald.withOpacity(0.12)
                : StudioTheme.cardDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isStreamingLocally
                  ? StudioTheme.accentEmerald.withOpacity(0.5)
                  : StudioTheme.borderDark,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isStreamingLocally
                      ? StudioTheme.accentEmerald
                      : StudioTheme.surfaceDark,
                ),
                child: Icon(
                  isStreamingLocally ? Icons.headphones_rounded : Icons.headset_off_rounded,
                  color: isStreamingLocally ? StudioTheme.bgDark : StudioTheme.textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isStreamingLocally ? 'Streaming to Phone (In-Ear)' : 'Listen In-App',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      isStreamingLocally
                          ? 'Streaming live room audio through device speakers'
                          : 'Play bot room music live directly on this device',
                      style: const TextStyle(color: StudioTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isStreamingLocally
                      ? StudioTheme.accentEmerald
                      : StudioTheme.surfaceDark,
                  foregroundColor: isStreamingLocally
                      ? StudioTheme.bgDark
                      : StudioTheme.accentSky,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final stream = _radioState.streamUrl;
                  if (stream.isNotEmpty) {
                    widget.audioService.togglePlay(stream);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No stream URL configured for this room radio'),
                        backgroundColor: StudioTheme.accentYellow,
                      ),
                    );
                  }
                },
                child: Text(
                  isStreamingLocally ? 'Mute' : 'Listen',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
