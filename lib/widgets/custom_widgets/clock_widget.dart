import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class ClockWidget extends StatefulWidget {
  const ClockWidget({super.key});

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  Timer? _timer;
  late DateTime _now;
  bool _is24h = true;

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _loadFormat();
    final secondsUntilNextMinute = 60 - _now.second;
    _timer = Timer(Duration(seconds: secondsUntilNextMinute), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    });
  }

  Future<void> _loadFormat() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _is24h = prefs.getBool('setting_clock_24h') ?? true;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  void _openClock() {
    final intent = AndroidIntent(
      action: 'android.intent.action.SHOW_ALARMS',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    intent.launch();
  }

  void _openCalendar() {
    final intent = AndroidIntent(
      action: 'android.intent.action.VIEW',
      data: 'content://com.android.calendar/time/${_now.millisecondsSinceEpoch}',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    intent.launch();
  }

  @override
  Widget build(BuildContext context) {
    int hour = _now.hour;
    String period = '';
    if (!_is24h) {
      period = hour >= 12 ? ' PM' : ' AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
    }

    final timeString = _is24h
        ? '${_pad(hour)}:${_pad(_now.minute)}'
        : '$hour:${_pad(_now.minute)}$period';
    final dayName = _weekdays[_now.weekday - 1];
    final dateString = '${_now.day} ${_months[_now.month - 1]}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Time display -> Open Clock on tap
          GestureDetector(
            onTap: _openClock,
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  timeString,
                  style: GoogleFonts.inter(
                    fontSize: _is24h ? 52 : 44,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Date display -> Open Calendar on tap
          GestureDetector(
            onTap: _openCalendar,
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dayName.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                    letterSpacing: 2.0,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dateString,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
