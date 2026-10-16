import 'dart:async';

import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:searchly/services/context_engine.dart';
import 'package:searchly/utils/app_cache_service.dart';

/// A smart, context-aware row of predicted app icons.
///
/// Unlike the static AppShortcutsWidget, this row dynamically updates
/// based on time of day, media state, and charging state from [ContextEngine].
class PredictiveAppRow extends StatefulWidget {
  const PredictiveAppRow({super.key});

  @override
  State<PredictiveAppRow> createState() => _PredictiveAppRowState();
}

class _PredictiveAppRowState extends State<PredictiveAppRow> {
  final _appCache = AppCacheService();
  final _engine = ContextEngine.instance;
  StreamSubscription<ContextState>? _sub;

  List<AppInfo> _predictedApps = [];
  List<AppInfo> _allApps = [];
  bool _appsLoaded = false;

  /// Heuristic mapping: time slot → list of package name substrings to match.
  /// We use substrings so "gmail" matches "com.google.android.gm", etc.
  static const _timeSlotHints = <TimeSlot, List<String>>{
    TimeSlot.morning: [
      'gmail', 'gm', 'mail', 'calendar', 'news', 'weather', 'keep', 'notes',
    ],
    TimeSlot.afternoon: [
      'messaging', 'sms', 'whatsapp', 'slack', 'teams', 'calendar', 'chrome',
      'browser', 'maps',
    ],
    TimeSlot.evening: [
      'youtube', 'instagram', 'whatsapp', 'spotify', 'uber', 'twitter',
      'netflix', 'reddit',
    ],
    TimeSlot.night: [
      'clock', 'deskclock', 'alarm', 'settings', 'youtube', 'spotify',
      'calculator', 'kindle',
    ],
  };

  static const _chargingHints = [
    'settings', 'photos', 'gallery', 'vending', 'play', 'youtube',
  ];

  static const _mediaHints = [
    'spotify', 'music', 'youtube', 'podcast', 'soundcloud', 'gaana',
    'jiosaavn', 'wynk',
  ];

  @override
  void initState() {
    super.initState();
    _loadAppsAndPredict();
    _sub = _engine.stream.listen((_) => _recalculate());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadAppsAndPredict() async {
    _allApps = await _appCache.getInstalledApps(withIcon: true);
    _appsLoaded = true;
    _recalculate();
  }

  void _recalculate() {
    if (!_appsLoaded || !mounted) return;

    final ctx = _engine.currentState;
    final hints = <String>[];

    // Media playing gets highest priority
    if (ctx.isMediaPlaying) {
      hints.addAll(_mediaHints);
    }

    // Charging adds its own hints
    if (ctx.isCharging) {
      hints.addAll(_chargingHints);
    }

    // Time-of-day is always included
    hints.addAll(_timeSlotHints[ctx.timeSlot] ?? []);

    // Score each installed app by how early its package name matches a hint
    final scored = <AppInfo, int>{};
    for (final app in _allApps) {
      if (app.icon == null) continue;
      final pkg = app.packageName.toLowerCase();
      final name = app.name.toLowerCase();
      for (int i = 0; i < hints.length; i++) {
        if (pkg.contains(hints[i]) || name.contains(hints[i])) {
          // Lower index = higher priority; keep the best score
          final score = scored[app];
          if (score == null || i < score) {
            scored[app] = i;
          }
          break; // one match per app is enough
        }
      }
    }

    // Sort by score (lowest = best match) and take top 5
    final sorted = scored.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    var result = sorted.take(5).map((e) => e.key).toList();

    // If we have fewer than 4 matches, pad with the first installed apps
    if (result.length < 4) {
      for (final app in _allApps) {
        if (result.length >= 5) break;
        if (app.icon != null && !result.contains(app)) {
          result.add(app);
        }
      }
    }

    setState(() => _predictedApps = result);
  }

  @override
  Widget build(BuildContext context) {
    if (_predictedApps.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _predictedApps.map((app) {
          return Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: Material(
                key: ValueKey(app.packageName),
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _appCache.launchAppSafely(context, app.packageName),
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: app.icon != null
                          ? Image.memory(
                              app.icon!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              cacheWidth: 88,
                              cacheHeight: 88,
                              filterQuality: FilterQuality.low,
                            )
                          : const Icon(Icons.apps, color: Colors.white54, size: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      app.name,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 9,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
