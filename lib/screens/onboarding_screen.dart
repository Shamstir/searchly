import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:flutter_media_controller/flutter_media_controller.dart';
import 'package:searchly/screens/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _contactsGranted = false;
  bool _usageGranted = false;
  bool _isDefaultLauncher = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    _contactsGranted = await Permission.contacts.isGranted;
    try {
      _usageGranted = await UsageStats.checkUsagePermission() ?? false;
      const platform = MethodChannel('searchly/launcher');
      _isDefaultLauncher = await platform.invokeMethod<bool>('isDefaultLauncher') ?? false;
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0D0F),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SEARCHLY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3.0,
                      fontSize: 14,
                    ),
                  ),
                  if (_currentPage < 2)
                    TextButton(
                      onPressed: _finishOnboarding,
                      child: const Text(
                        'Skip',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildSlide(
                    icon: Icons.dashboard_customize_outlined,
                    title: 'A Smarter\nHomescreen',
                    description:
                        'Adaptive translucent widgets that automatically re-order based on the time of day, battery state, and active media playback.',
                  ),
                  _buildSlide(
                    icon: Icons.terminal_rounded,
                    title: 'Universal\nCommand Bar',
                    description:
                        'Launch apps, dial contacts, calculate formulas, and set alarms seamlessly with a lightning-fast natural command bar.',
                  ),
                  _buildPermissionSlide(),
                ],
              ),
            ),

            // Bottom Navigation
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicators
                  Row(
                    children: List.generate(3, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Colors.white
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Next / Start Button
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < 2) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _finishOnboarding();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                    ),
                    child: Text(
                      _currentPage == 2 ? 'Get Started' : 'Next',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Icon(icon, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 36),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w300,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 16,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Permissions\n& Setup',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w300,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Grant access to unlock full functionality:',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 20),
          _buildPermissionRow(
            icon: Icons.home_outlined,
            title: 'Set Default Launcher',
            desc: 'Replaces system homescreen',
            isDone: _isDefaultLauncher,
            onTap: () async {
              const platform = MethodChannel('searchly/launcher');
              await platform.invokeMethod('requestDefaultLauncher');
              await Future.delayed(const Duration(seconds: 1));
              _checkPermissions();
            },
          ),
          const SizedBox(height: 12),
          _buildPermissionRow(
            icon: Icons.contacts_outlined,
            title: 'Contacts Access',
            desc: 'Enables "call John" search commands',
            isDone: _contactsGranted,
            onTap: () async {
              await Permission.contacts.request();
              _checkPermissions();
            },
          ),
          const SizedBox(height: 12),
          _buildPermissionRow(
            icon: Icons.bar_chart_outlined,
            title: 'Usage Statistics',
            desc: 'Powers the daily Screen Time widget',
            isDone: _usageGranted,
            onTap: () async {
              await UsageStats.grantUsagePermission();
              _checkPermissions();
            },
          ),
          const SizedBox(height: 12),
          _buildPermissionRow(
            icon: Icons.music_note_outlined,
            title: 'Media Listener',
            desc: 'Powers dynamic album art blur',
            isDone: false,
            onTap: () async {
              await FlutterMediaController.requestPermissions();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDone,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDone ? Colors.green : Colors.white12,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isDone ? 'Done' : 'Grant',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
