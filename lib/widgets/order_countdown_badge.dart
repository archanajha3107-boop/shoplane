import 'package:flutter/material.dart';

class OrderCountdownBadge extends StatefulWidget {
  final DateTime createdAt;

  const OrderCountdownBadge({super.key, required this.createdAt});

  @override
  State<OrderCountdownBadge> createState() => _OrderCountdownBadgeState();
}

class _OrderCountdownBadgeState extends State<OrderCountdownBadge> {
  late DateTime _createdTime;
  Duration _remaining = Duration.zero;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _createdTime = widget.createdAt;
    _updateCountdown();
    // Update every second
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _updateCountdown());
      }
      return mounted;
    });
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final fiveMinutesAgo = _createdTime.add(const Duration(minutes: 5));
    _remaining = fiveMinutesAgo.difference(now);

    if (_remaining.isNegative) {
      _expired = true;
      _remaining = Duration.zero;
    } else {
      _expired = false;
    }
  }

  String _formatTime(Duration d) {
    if (d.inSeconds <= 0) return '0s';
    if (d.inMinutes > 0) {
      final secs = d.inSeconds % 60;
      return '${d.inMinutes}:${secs.toString().padLeft(2, '0')}';
    }
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    if (_expired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '⏰ EXPIRED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      );
    }

    // Change color based on remaining time
    final isWarning = _remaining.inSeconds < 60;
    final bgColor = isWarning
        ? const Color(0xFFE85A2B).withValues(alpha: 0.1)
        : const Color(0xFF0F7B6C).withValues(alpha: 0.1);
    final textColor =
        isWarning ? const Color(0xFFE85A2B) : const Color(0xFF0F7B6C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '⏱️ ${_formatTime(_remaining)}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
