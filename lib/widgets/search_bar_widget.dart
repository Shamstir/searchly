import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:searchly/screens/app_drawer_screen.dart';
import 'package:searchly/utils/app_cache_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:permission_handler/permission_handler.dart';

class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final _controller = TextEditingController();
  final _appCache = AppCacheService();
  bool _isLaunching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSubmitted(String query) async {
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty || _isLaunching) return;

    setState(() => _isLaunching = true);

    try {
      if (lowerQuery.startsWith('call ')) {
        await _handleCallCommand(lowerQuery.substring(5).trim());
        return;
      }

      if (lowerQuery.startsWith('alarm ')) {
        await _handleAlarmCommand(lowerQuery.substring(6).trim());
        return;
      }

      if (lowerQuery.startsWith('wm ')) {
        await _handleWhatsappCommand(lowerQuery.substring(3).trim());
        return;
      }

      await _handleAppSearch(lowerQuery);
    } catch (e) {
      debugPrint('Command execution failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Command execution failed')),
        );
      }
    } finally {
      if (mounted) {
        _controller.clear();
        setState(() => _isLaunching = false);
      }
    }
  }

  Future<void> _handleCallCommand(String name) async {
    if (await Permission.contacts.request().isGranted) {
      final contacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});
      
      var matches = contacts.where((c) => (c.displayName ?? '').toLowerCase().contains(name)).toList();
      if (matches.isNotEmpty) {
        final contact = matches.first;
        if (contact.phones.isNotEmpty) {
          final phone = contact.phones.first.number;
          final intent = AndroidIntent(
            action: 'android.intent.action.DIAL',
            data: 'tel:$phone',
            flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
          );
          await intent.launch();
        }
      }
    }
  }

  Future<void> _handleAlarmCommand(String timeStr) async {
    int hour = 0;
    int minute = 0;
    
    timeStr = timeStr.replaceAll(' ', '').toLowerCase();
    bool isPm = timeStr.contains('pm');
    timeStr = timeStr.replaceAll('am', '').replaceAll('pm', '');
    
    if (timeStr.contains(':')) {
      final parts = timeStr.split(':');
      hour = int.tryParse(parts[0]) ?? 0;
      minute = int.tryParse(parts[1]) ?? 0;
    } else {
      hour = int.tryParse(timeStr) ?? 0;
    }
    
    if (isPm && hour < 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;
    
    final intent = AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.HOUR': hour,
        'android.intent.extra.alarm.MINUTES': minute,
        'android.intent.extra.alarm.SKIP_UI': true,
        'android.intent.extra.alarm.MESSAGE': 'Searchly Alarm',
      },
    );
    await intent.launch();
  }

  Future<void> _handleWhatsappCommand(String message) async {
    final url = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      final webUrl = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
      await launchUrl(webUrl);
    }
  }

  Future<void> _handleAppSearch(String lowerQuery) async {
    final apps = await _appCache.getInstalledApps(withIcon: false);
    if (!mounted) return;

    final exactMatches = apps
        .where((app) => app.name.toLowerCase() == lowerQuery)
        .toList();
    final partialMatches = apps
        .where((app) => app.name.toLowerCase().contains(lowerQuery))
        .toList();
        
    final AppInfo? target = exactMatches.isNotEmpty
        ? exactMatches.first
        : partialMatches.isNotEmpty
        ? partialMatches.first
        : null;

    if (target == null) {
      _openAppDrawer();
      return;
    }

    await _appCache.launchAppSafely(context, target.packageName);
  }

  void _openAppDrawer() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AppDrawerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.0, 1.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.fastOutSlowIn,
                  ),
                ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE8E8E8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 26,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 6),
            IconButton(
              onPressed: _openAppDrawer,
              icon: const Icon(Icons.apps, color: Color(0xFF222222)),
              tooltip: 'All apps',
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: _onSubmitted,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Color(0xFF222222), fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search or command...',
                  hintStyle: TextStyle(color: Color(0xFF9A9A9A)),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
            if (_isLaunching)
              const Padding(
                padding: EdgeInsets.only(right: 18),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF222222),
                  ),
                ),
              )
            else
              IconButton(
                onPressed: _openAppDrawer,
                icon: const Icon(
                  Icons.keyboard_arrow_up,
                  color: Color(0xFF777777),
                ),
                tooltip: 'Open drawer',
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
