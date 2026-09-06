import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/studio_theme.dart';

class VirtualRoomCanvas extends StatelessWidget {
  final List<LiveUser> users;
  final List<RoomChatMessage> recentChats;
  final Function(LiveUser) onUserTapped;
  final LiveUser? selectedUser;
  final int roomWidth;
  final int roomDepth;

  const VirtualRoomCanvas({
    super.key,
    required this.users,
    required this.recentChats,
    required this.onUserTapped,
    this.selectedUser,
    this.roomWidth = 18,
    this.roomDepth = 18,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: const Color(0xFF070A12), // Deep Void
        child: InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(200),
          minScale: 0.5,
          maxScale: 2.5,
          constrained: false,
          child: GestureDetector(
            onTapUp: (details) {
              _handleTap(details.localPosition);
            },
            child: CustomPaint(
              size: const Size(1000, 800),
              painter: _RoomIsometricPainter(
                users: users,
                recentChats: recentChats,
                selectedUser: selectedUser,
                roomWidth: roomWidth,
                roomDepth: roomDepth,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(Offset localPos) {
    const originX = 500.0;
    const originY = 220.0;
    const tileW = 26.0;
    const tileH = 15.0;
    const heightScale = 14.0;

    LiveUser? closestUser;
    double minDistance = 30.0; // 30px hit radius

    for (final user in users) {
      final iso = _projectIso(
        user.position.x,
        user.position.y,
        user.position.z,
        originX,
        originY,
        tileW,
        tileH,
        heightScale,
      );

      final dist = (iso - localPos).distance;
      if (dist < minDistance) {
        minDistance = dist;
        closestUser = user;
      }
    }

    if (closestUser != null) {
      onUserTapped(closestUser);
    }
  }

  static Offset _projectIso(
    double x,
    double y,
    double z,
    double originX,
    double originY,
    double tileW,
    double tileH,
    double heightScale,
  ) {
    final screenX = originX + (x - z) * tileW;
    final screenY = originY + (x + z) * tileH - (y * heightScale);
    return Offset(screenX, screenY);
  }
}

class _RoomIsometricPainter extends CustomPainter {
  final List<LiveUser> users;
  final List<RoomChatMessage> recentChats;
  final LiveUser? selectedUser;
  final int roomWidth;
  final int roomDepth;

  _RoomIsometricPainter({
    required this.users,
    required this.recentChats,
    this.selectedUser,
    required this.roomWidth,
    required this.roomDepth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const originX = 500.0;
    const originY = 220.0;
    const tileW = 26.0;
    const tileH = 15.0;
    const heightScale = 14.0;

    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final tileFillPaint = Paint()
      ..color = const Color(0xFF0F172A).withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final wallPaint = Paint()
      ..color = const Color(0xFF131C2E)
      ..style = PaintingStyle.fill;

    // 1. Draw 3D Room Base & Walls
    _drawWalls(canvas, originX, originY, tileW, tileH, wallPaint);

    // 2. Draw Isometric Floor Grid
    for (int x = 0; x < roomWidth; x++) {
      for (int z = 0; z < roomDepth; z++) {
        final p0 = VirtualRoomCanvas._projectIso(x.toDouble(), 0, z.toDouble(), originX, originY, tileW, tileH, heightScale);
        final p1 = VirtualRoomCanvas._projectIso((x + 1).toDouble(), 0, z.toDouble(), originX, originY, tileW, tileH, heightScale);
        final p2 = VirtualRoomCanvas._projectIso((x + 1).toDouble(), 0, (z + 1).toDouble(), originX, originY, tileW, tileH, heightScale);
        final p3 = VirtualRoomCanvas._projectIso(x.toDouble(), 0, (z + 1).toDouble(), originX, originY, tileW, tileH, heightScale);

        final path = Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close();

        canvas.drawPath(path, tileFillPaint);
        canvas.drawPath(path, gridPaint);
      }
    }

    // 3. Sort Users by Isometric Depth so foreground avatars occlude background ones
    final sortedUsers = List<LiveUser>.from(users)
      ..sort((a, b) {
        final depthA = a.position.x + a.position.z + a.position.y * 0.1;
        final depthB = b.position.x + b.position.z + b.position.y * 0.1;
        return depthA.compareTo(depthB);
      });

    // 4. Draw Users and Bots
    for (final user in sortedUsers) {
      final pos = VirtualRoomCanvas._projectIso(
        user.position.x,
        user.position.y,
        user.position.z,
        originX,
        originY,
        tileW,
        tileH,
        heightScale,
      );

      _drawAvatar(canvas, user, pos);
    }

    // 5. Draw Speech Bubbles above Users who recently chatted
    final now = DateTime.now();
    for (final user in sortedUsers) {
      final userChats = recentChats.where((c) =>
          c.senderName.toLowerCase() == user.username.toLowerCase() &&
          now.difference(c.timestamp).inSeconds < 8);

      if (userChats.isNotEmpty) {
        final lastMsg = userChats.last;
        final pos = VirtualRoomCanvas._projectIso(
          user.position.x,
          user.position.y,
          user.position.z,
          originX,
          originY,
          tileW,
          tileH,
          heightScale,
        );

        _drawSpeechBubble(canvas, lastMsg.message, pos);
      }
    }
  }

  void _drawWalls(Canvas canvas, double ox, double oy, double tw, double th, Paint paint) {
    // Back Left Wall
    final pTopBack = VirtualRoomCanvas._projectIso(0, 5, 0, ox, oy, tw, th, 14.0);
    final pBottomBack = VirtualRoomCanvas._projectIso(0, 0, 0, ox, oy, tw, th, 14.0);
    final pTopLeft = VirtualRoomCanvas._projectIso(0, 5, roomDepth.toDouble(), ox, oy, tw, th, 14.0);
    final pBottomLeft = VirtualRoomCanvas._projectIso(0, 0, roomDepth.toDouble(), ox, oy, tw, th, 14.0);

    final leftWall = Path()
      ..moveTo(pBottomLeft.dx, pBottomLeft.dy)
      ..lineTo(pTopLeft.dx, pTopLeft.dy)
      ..lineTo(pTopBack.dx, pTopBack.dy)
      ..lineTo(pBottomBack.dx, pBottomBack.dy)
      ..close();
    canvas.drawPath(leftWall, paint);

    // Back Right Wall
    final pTopRight = VirtualRoomCanvas._projectIso(roomWidth.toDouble(), 5, 0, ox, oy, tw, th, 14.0);
    final pBottomRight = VirtualRoomCanvas._projectIso(roomWidth.toDouble(), 0, 0, ox, oy, tw, th, 14.0);

    final rightWall = Path()
      ..moveTo(pBottomBack.dx, pBottomBack.dy)
      ..lineTo(pTopBack.dx, pTopBack.dy)
      ..lineTo(pTopRight.dx, pTopRight.dy)
      ..lineTo(pBottomRight.dx, pBottomRight.dy)
      ..close();
    canvas.drawPath(rightWall, Paint()..color = const Color(0xFF172136));
  }

  void _drawAvatar(Canvas canvas, LiveUser user, Offset pos) {
    final isSelected = selectedUser?.id == user.id;
    final isBot = user.isBot;

    // Ground Shadow
    final shadowPaint = Paint()..color = Colors.black45;
    canvas.drawOval(
      Rect.fromCenter(center: pos.translate(0, 4), width: 18, height: 9),
      shadowPaint,
    );

    // Color Determination
    Color avatarColor = StudioTheme.accent;
    if (isBot) {
      if (user.username.contains('1')) avatarColor = StudioTheme.bot1;
      else if (user.username.contains('2')) avatarColor = StudioTheme.bot2;
      else if (user.username.contains('3')) avatarColor = StudioTheme.bot3;
      else if (user.username.contains('4')) avatarColor = StudioTheme.bot4;
      else if (user.username.contains('5')) avatarColor = StudioTheme.bot5;
      else if (user.username.contains('6')) avatarColor = StudioTheme.bot6;
      else avatarColor = StudioTheme.online;
    } else if (user.isModerator) {
      avatarColor = const Color(0xFF38BDF8); // Mod Cyan
    } else if (user.isDesigner) {
      avatarColor = const Color(0xFFA855F7); // Designer Purple
    } else if (user.role.toLowerCase() == 'vip') {
      avatarColor = const Color(0xFFF59E0B); // VIP Gold
    }

    // Selected Halo
    if (isSelected) {
      final haloPaint = Paint()
        ..color = avatarColor.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(pos.translate(0, -12), 16, haloPaint);
    }

    // Main Avatar Body
    final bodyPaint = Paint()..color = avatarColor;
    canvas.drawCircle(pos.translate(0, -12), 10, bodyPaint);

    // Inner Core
    final corePaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawCircle(pos.translate(0, -12), 6, corePaint);

    // Facing Direction Pointer
    final facing = user.position.facing;
    double angle = 0;
    if (facing == 'FrontRight') angle = math.pi / 4;
    else if (facing == 'FrontLeft') angle = 3 * math.pi / 4;
    else if (facing == 'BackLeft') angle = 5 * math.pi / 4;
    else if (facing == 'BackRight') angle = 7 * math.pi / 4;

    final dirOffset = Offset(
      pos.dx + math.cos(angle) * 7,
      pos.dy - 12 + math.sin(angle) * 7,
    );
    canvas.drawCircle(dirOffset, 2.5, Paint()..color = avatarColor);

    // Name Label Pill
    _drawTextLabel(canvas, user.username, pos.translate(0, -28), avatarColor);
  }

  void _drawTextLabel(Canvas canvas, String text, Offset center, Color textColor) {
    final textSpan = TextSpan(
      text: text.length > 12 ? '${text.substring(0, 10)}..' : text,
      style: TextStyle(
        color: textColor,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        backgroundColor: Colors.black.withOpacity(0.7),
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final drawPos = center.translate(-textPainter.width / 2, -textPainter.height / 2);
    textPainter.paint(canvas, drawPos);
  }

  void _drawSpeechBubble(Canvas canvas, String message, Offset avatarPos) {
    final cleanMsg = message.length > 32 ? '${message.substring(0, 30)}..' : message;
    final textSpan = TextSpan(
      text: cleanMsg,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 160);

    const bubblePadding = 6.0;
    final bubbleW = textPainter.width + bubblePadding * 2;
    final bubbleH = textPainter.height + bubblePadding * 2;
    final bubbleTopLeft = avatarPos.translate(-bubbleW / 2, -45 - bubbleH);

    // Bubble Background
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bubbleTopLeft.dx, bubbleTopLeft.dy, bubbleW, bubbleH),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0xFF1E293B).withOpacity(0.95),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = StudioTheme.accent.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Speech Tail
    final tailPath = Path()
      ..moveTo(avatarPos.dx - 4, bubbleTopLeft.dy + bubbleH)
      ..lineTo(avatarPos.dx, bubbleTopLeft.dy + bubbleH + 5)
      ..lineTo(avatarPos.dx + 4, bubbleTopLeft.dy + bubbleH)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = const Color(0xFF1E293B));

    // Paint message text
    textPainter.paint(
      canvas,
      bubbleTopLeft.translate(bubblePadding, bubblePadding),
    );
  }

  @override
  bool shouldRepaint(covariant _RoomIsometricPainter oldDelegate) => true;
}
