import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';

/// Represents a time-of-day slot for context-aware behavior.
enum TimeSlot { morning, afternoon, evening, night }

/// Immutable snapshot of the device's current context.
class ContextState {
  final TimeSlot timeSlot;
  final bool isMediaPlaying;
  final int batteryLevel;
  final bool isCharging;
  final DateTime timestamp;

  const ContextState({
    required this.timeSlot,
    required this.isMediaPlaying,
    required this.batteryLevel,
    required this.isCharging,
    required this.timestamp,
  });

  /// Default state used before the first poll completes.
  factory ContextState.initial() {
    return ContextState(
      timeSlot: _timeSlotFromHour(DateTime.now().hour),
      isMediaPlaying: false,
      batteryLevel: 100,
      isCharging: false,
      timestamp: DateTime.now(),
    );
  }

  static TimeSlot _timeSlotFromHour(int hour) {
    if (hour >= 5 && hour < 12) return TimeSlot.morning;
    if (hour >= 12 && hour < 17) return TimeSlot.afternoon;
    if (hour >= 17 && hour < 21) return TimeSlot.evening;
    return TimeSlot.night;
  }

  bool get isNight => timeSlot == TimeSlot.night;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContextState &&
          runtimeType == other.runtimeType &&
          timeSlot == other.timeSlot &&
          isMediaPlaying == other.isMediaPlaying &&
          batteryLevel == other.batteryLevel &&
          isCharging == other.isCharging;

  @override
  int get hashCode => Object.hash(timeSlot, isMediaPlaying, batteryLevel, isCharging);
}

/// Singleton service that monitors device state and emits [ContextState] changes.
///
/// The engine polls every 30 seconds and only emits when state actually changes.
/// Consumers can listen via [stream] or read [currentState] synchronously.
class ContextEngine {
  ContextEngine._();
  static final ContextEngine instance = ContextEngine._();

  final Battery _battery = Battery();
  Timer? _pollTimer;
  bool _isMediaPlaying = false;

  ContextState _currentState = ContextState.initial();
  ContextState get currentState => _currentState;

  final _controller = StreamController<ContextState>.broadcast();
  Stream<ContextState> get stream => _controller.stream;

  /// Start polling. Safe to call multiple times (idempotent).
  void start() {
    if (_pollTimer != null) return;
    _poll(); // immediate first poll
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
  }

  /// Stop polling and clean up resources.
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _controller.close();
  }

  /// Called by the MusicPlayerWidget or HomeScreen when media state changes.
  void updateMediaPlaying(bool playing) {
    if (_isMediaPlaying == playing) return;
    _isMediaPlaying = playing;
    _poll(); // immediately re-evaluate context
  }

  Future<void> _poll() async {
    try {
      final now = DateTime.now();
      final timeSlot = ContextState._timeSlotFromHour(now.hour);

      int batteryLevel = 100;
      bool isCharging = false;

      try {
        batteryLevel = await _battery.batteryLevel;
        final batteryState = await _battery.batteryState;
        isCharging = batteryState == BatteryState.charging ||
            batteryState == BatteryState.full;
      } catch (e) {
        debugPrint('ContextEngine: battery read failed: $e');
      }

      final newState = ContextState(
        timeSlot: timeSlot,
        isMediaPlaying: _isMediaPlaying,
        batteryLevel: batteryLevel,
        isCharging: isCharging,
        timestamp: now,
      );

      if (newState != _currentState) {
        _currentState = newState;
        _controller.add(newState);
      }
    } catch (e) {
      debugPrint('ContextEngine: poll error: $e');
    }
  }
}
