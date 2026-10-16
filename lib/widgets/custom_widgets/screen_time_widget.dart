import 'dart:async';
import 'package:flutter/material.dart';
import 'package:usage_stats/usage_stats.dart';

class ScreenTimeWidget extends StatefulWidget {
  const ScreenTimeWidget({super.key});

  @override
  State<ScreenTimeWidget> createState() => _ScreenTimeWidgetState();
}

class _ScreenTimeWidgetState extends State<ScreenTimeWidget>
    with WidgetsBindingObserver {
  List<double> usage = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<String> days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  String todayUsageString = "0h 0m";
  bool isLoading = true;
  String? errorMsg;
  Timer? _initialLoadTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialLoadTimer = Timer(
      const Duration(milliseconds: 400),
      _fetchUsageStats,
    );
  }

  @override
  void dispose() {
    _initialLoadTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchUsageStats();
    }
  }

  Future<void> _fetchUsageStats() async {
    try {
      bool isGranted = await UsageStats.checkUsagePermission() ?? false;
      if (!isGranted) {
        if (mounted) {
          setState(() {
            isLoading = false;
            errorMsg = "Permission required";
          });
        }
        return;
      }

      DateTime endDate = DateTime.now();
      List<String> dailyNames = [];
      double maxDailyMs = 1.0;
      int todayMs = 0;

      // Build date ranges using DST-safe calendar math
      List<DateTime> dayStarts = [];
      for (int i = 6; i >= 0; i--) {
        dayStarts.add(
          DateTime(
            endDate.year,
            endDate.month,
            endDate.day - i,
          ),
        );
      }

      final results = await Future.wait(
        dayStarts.map(
          (dayStart) => UsageStats.queryUsageStats(
            dayStart,
            DateTime(dayStart.year, dayStart.month, dayStart.day + 1),
          ),
        ),
      );

      List<double> dailyUsage = [];
      for (int i = 0; i < results.length; i++) {
        int totalMs = 0;
        for (var info in results[i]) {
          totalMs += int.tryParse(info.totalTimeInForeground ?? '0') ?? 0;
        }
        if (i == 6) todayMs = totalMs;
        if (totalMs > maxDailyMs) maxDailyMs = totalMs.toDouble();
        dailyUsage.add(totalMs.toDouble());

        const dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
        dailyNames.add(dayLabels[dayStarts[i].weekday - 1]);
      }

      for (int i = 0; i < dailyUsage.length; i++) {
        dailyUsage[i] = dailyUsage[i] / maxDailyMs;
      }

      int hours = (todayMs / (1000 * 60 * 60)).floor();
      int minutes = ((todayMs / (1000 * 60)) % 60).floor();

      if (mounted) {
        setState(() {
          usage = dailyUsage;
          days = dailyNames;
          todayUsageString = "${hours}h ${minutes}m";
          isLoading = false;
          errorMsg = null;
        });
      }
    } catch (e) {
      debugPrint("Usage stats error: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMsg = "Error loading stats";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (errorMsg != null) {
          await UsageStats.grantUsagePermission();
          _fetchUsageStats();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SCREEN TIME',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 12,
                letterSpacing: 2.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (errorMsg != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bar_chart, color: Color(0xFF888888), size: 28),
                      const SizedBox(height: 6),
                      Text(
                        errorMsg!,
                        style: const TextStyle(
                          color: Color(0xFF555555),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tap to grant access',
                        style: TextStyle(color: Color(0xFF999999), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              )
            else if (isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    todayUsageString.split('h')[0],
                    style: const TextStyle(
                      color: Color(0xFF222222),
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      height: 1.0,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4, left: 2, right: 6),
                    child: Text(
                      'h',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 16),
                    ),
                  ),
                  Text(
                    todayUsageString.split('h ')[1].replaceAll('m', ''),
                    style: const TextStyle(
                      color: Color(0xFF222222),
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      height: 1.0,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4, left: 2),
                    child: Text(
                      'm',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    bool isToday = index == 6;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 14,
                          height: 40 * (usage[index] == 0 ? 0.1 : usage[index]),
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF222222)
                                : const Color(0xFFE5E5E5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          days[index],
                          style: TextStyle(
                            color: isToday
                                ? const Color(0xFF222222)
                                : const Color(0xFFAAAAAA),
                            fontSize: 10,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
