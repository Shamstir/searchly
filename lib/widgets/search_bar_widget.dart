import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:searchly/screens/app_drawer_screen.dart';

class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  List<AppInfo>? _installedAppsCache;

  @override
  void initState() {
    super.initState();
    _preloadApps();
  }

  Future<void> _preloadApps() async {
    try {
      _installedAppsCache = await InstalledApps.getInstalledApps(excludeSystemApps: false, withIcon: true);
    } catch (e) {
      debugPrint("Failed to load apps: $e");
    }
  }

  void _onSubmitted(String query) async {
    if (query.trim().isEmpty) return;
    
    List<AppInfo> apps = _installedAppsCache ?? [];
    if (apps.isEmpty) {
      apps = await InstalledApps.getInstalledApps(excludeSystemApps: false, withIcon: true);
      _installedAppsCache = apps;
    }

    String lowerQuery = query.toLowerCase().trim();
    List<AppInfo> matches = apps.where((app) {
      return app.name.toLowerCase().contains(lowerQuery);
    }).toList();

    if (matches.length == 1) {
      // Only 1 app matches
      InstalledApps.startApp(matches.first.packageName);
      _controller.clear();
    } else if (matches.isNotEmpty) {
      // Check for an exact match if there are multiple substring matches
      var exactMatch = matches.where((app) => app.name.toLowerCase() == lowerQuery).toList();
      if (exactMatch.length == 1) {
        InstalledApps.startApp(exactMatch.first.packageName);
        _controller.clear();
      } else {
        // Did not match exactly 1 app. Do nothing as requested.
      }
    }
  }

  void _openAppDrawer() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AppDrawerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCirc,
            )),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _openAppDrawer,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: TextField(
          controller: _controller,
          onSubmitted: _onSubmitted,
          style: const TextStyle(color: Color(0xFF333333), fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search or long press...',
            hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
            prefixIcon: const Icon(Icons.search, color: Color(0xFFBBBBBB)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ),
    );
  }
}
