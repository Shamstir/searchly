import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:searchly/screens/app_drawer_screen.dart';
import 'package:searchly/screens/settings_screen.dart';
import 'package:searchly/services/calculator_service.dart';
import 'package:searchly/utils/app_cache_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final _focusNode = FocusNode();
  final _appCache = AppCacheService();

  bool _isLaunching = false;
  String? _mathResult;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (CalculatorService.isLikelyMath(text)) {
      final res = CalculatorService.evaluate(text);
      if (mounted) setState(() => _mathResult = res);
    } else {
      if (_mathResult != null && mounted) {
        setState(() => _mathResult = null);
      }
    }
  }

  Future<void> _onSubmitted(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _isLaunching) return;

    setState(() => _isLaunching = true);

    try {
      final lower = trimmed.toLowerCase();

      // Math result execution
      if (_mathResult != null) {
        Clipboard.setData(ClipboardData(text: _mathResult!));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Result $_mathResult copied to clipboard!'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Bang Web Searches (!g, !yt, !w, !d, !b)
      if (lower.startsWith('!')) {
        await _handleBangSearch(trimmed);
        return;
      }

      // Call command
      if (lower.startsWith('call ')) {
        await _handleCallCommand(trimmed.substring(5).trim());
        return;
      }

      // SMS / Message command
      if (lower.startsWith('msg ') || lower.startsWith('sms ')) {
        final prefixLen = lower.startsWith('msg ') ? 4 : 4;
        final content = trimmed.substring(prefixLen).trim();
        await _handleSmsCommand(content);
        return;
      }

      // Alarm command
      if (lower.startsWith('alarm ')) {
        await _handleAlarmCommand(trimmed.substring(6).trim());
        return;
      }

      // Timer command
      if (lower.startsWith('timer ')) {
        await _handleTimerCommand(trimmed.substring(6).trim());
        return;
      }

      // WhatsApp command
      if (lower.startsWith('wm ') || lower.startsWith('wa ')) {
        final prefixLen = lower.startsWith('wm ') ? 3 : 3;
        final content = trimmed.substring(prefixLen).trim();
        await _handleWhatsappCommand(content);
        return;
      }

      // Quick Todo creation
      if (lower.startsWith('todo ') || lower.startsWith('task ') || lower.startsWith('note ')) {
        final task = trimmed.substring(lower.indexOf(' ') + 1).trim();
        await _handleQuickTodo(task);
        return;
      }

      // Direct URL Navigation
      if (lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          (lower.contains('.') && !lower.contains(' ') && lower.length > 4)) {
        var urlStr = trimmed;
        if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
          urlStr = 'https://$urlStr';
        }
        final url = Uri.parse(urlStr);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // App search or Web Fallback
      await _handleAppOrWebSearch(trimmed);
    } catch (e) {
      debugPrint('Command execution error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Command execution failed')),
        );
      }
    } finally {
      if (mounted) {
        _controller.clear();
        setState(() {
          _isLaunching = false;
          _mathResult = null;
        });
      }
    }
  }

  Future<void> _handleCallCommand(String name) async {
    if (await Permission.contacts.request().isGranted) {
      final contacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});
      var matches = contacts.where((c) => (c.displayName ?? '').toLowerCase().contains(name)).toList();
      if (matches.isNotEmpty && matches.first.phones.isNotEmpty) {
        final phone = matches.first.phones.first.number;
        final intent = AndroidIntent(
          action: 'android.intent.action.DIAL',
          data: 'tel:$phone',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
      }
    }
  }

  Future<void> _handleSmsCommand(String input) async {
    final parts = input.split(' ');
    final recipient = parts.isNotEmpty ? parts[0] : '';
    final message = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    String phoneNumber = recipient;
    if (await Permission.contacts.isGranted) {
      final contacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});
      final matches = contacts.where((c) => (c.displayName ?? '').toLowerCase().contains(recipient.toLowerCase())).toList();
      if (matches.isNotEmpty && matches.first.phones.isNotEmpty) {
        phoneNumber = matches.first.phones.first.number;
      }
    }

    final intent = AndroidIntent(
      action: 'android.intent.action.SENDTO',
      data: 'smsto:$phoneNumber',
      arguments: {
        'sms_body': message,
        'android.intent.extra.TEXT': message,
      },
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  Future<void> _handleAlarmCommand(String timeStr) async {
    int hour = 0;
    int minute = 0;

    var s = timeStr.replaceAll(' ', '').toLowerCase();
    bool isPm = s.contains('pm');
    s = s.replaceAll('am', '').replaceAll('pm', '');

    if (s.contains(':')) {
      final parts = s.split(':');
      hour = int.tryParse(parts[0]) ?? 0;
      minute = int.tryParse(parts[1]) ?? 0;
    } else {
      hour = int.tryParse(s) ?? 0;
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

  Future<void> _handleTimerCommand(String durationStr) async {
    int seconds = 0;
    final s = durationStr.toLowerCase().replaceAll(' ', '');
    if (s.endsWith('m') || s.endsWith('min')) {
      final num = int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 5;
      seconds = num * 60;
    } else if (s.endsWith('s') || s.endsWith('sec')) {
      seconds = int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 30;
    } else {
      final num = int.tryParse(s) ?? 5;
      seconds = num * 60;
    }

    final intent = AndroidIntent(
      action: 'android.intent.action.SET_TIMER',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.LENGTH': seconds,
        'android.intent.extra.alarm.MESSAGE': 'Searchly Timer',
        'android.intent.extra.alarm.SKIP_UI': false,
      },
    );
    await intent.launch();
  }

  Future<void> _handleWhatsappCommand(String content) async {
    // If format is "wa [number] [message]" or "wa [message]"
    final parts = content.split(' ');
    String? phone;
    String message = content;

    if (parts.isNotEmpty && RegExp(r'^\+?[0-9]{7,15}$').hasMatch(parts[0])) {
      phone = parts[0];
      message = parts.sublist(1).join(' ');
    }

    Uri uri;
    if (phone != null) {
      uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    } else {
      uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final fallback = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleQuickTodo(String task) async {
    if (task.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList('todos_v2') ?? [];
    saved.add(jsonEncode({'task': task, 'done': false}));
    await prefs.setStringList('todos_v2', saved);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to tasks: "$task"')),
      );
    }
  }

  Future<void> _handleBangSearch(String query) async {
    final trimmed = query.trim();
    final firstSpace = trimmed.indexOf(' ');
    String bang = trimmed;
    String searchTerms = '';

    if (firstSpace != -1) {
      bang = trimmed.substring(0, firstSpace).toLowerCase();
      searchTerms = trimmed.substring(firstSpace + 1).trim();
    }

    final encoded = Uri.encodeComponent(searchTerms);
    String urlStr;

    switch (bang) {
      case '!yt':
      case '!youtube':
        urlStr = 'https://www.youtube.com/results?search_query=$encoded';
        break;
      case '!w':
      case '!wiki':
      case '!wikipedia':
        urlStr = 'https://en.wikipedia.org/wiki/Special:Search?search=$encoded';
        break;
      case '!d':
      case '!ddg':
      case '!duck':
        urlStr = 'https://duckduckgo.com/?q=$encoded';
        break;
      case '!b':
      case '!bing':
        urlStr = 'https://www.bing.com/search?q=$encoded';
        break;
      case '!brave':
        urlStr = 'https://search.brave.com/search?q=$encoded';
        break;
      case '!g':
      case '!google':
      default:
        urlStr = 'https://www.google.com/search?q=$encoded';
        break;
    }

    final url = Uri.parse(urlStr);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleAppOrWebSearch(String query) async {
    final lower = query.toLowerCase().trim();
    final apps = await _appCache.getInstalledApps(withIcon: false);

    // 1. Exact match
    final exact = apps.where((a) => a.name.toLowerCase() == lower).toList();
    if (exact.isNotEmpty) {
      if (!mounted) return;
      await _appCache.launchAppSafely(context, exact.first.packageName);
      return;
    }

    // 2. Prefix match
    final prefixMatches = apps.where((a) {
      final n = a.name.toLowerCase();
      return n.startsWith(lower);
    }).toList();

    if (prefixMatches.length == 1) {
      if (!mounted) return;
      await _appCache.launchAppSafely(context, prefixMatches.first.packageName);
      return;
    }

    // 3. Substring / contains match
    final containsMatches = apps.where((a) {
      final n = a.name.toLowerCase();
      return n.contains(lower);
    }).toList();

    if (containsMatches.length == 1) {
      if (!mounted) return;
      await _appCache.launchAppSafely(context, containsMatches.first.packageName);
      return;
    }

    // 4. Fuzzy match (Typo tolerance) - Only for queries of length >= 4 to avoid false positives on short words
    if (lower.length >= 4) {
      AppInfo? bestMatch;
      int bestScore = 999;
      for (final app in apps) {
        final appLower = app.name.toLowerCase();
        // Mathematical optimization: if length difference > 2, Levenshtein distance is strictly > 2
        if ((lower.length - appLower.length).abs() > 2) continue;

        final dist = _levenshtein(lower, appLower);
        final ratio = dist / lower.length;
        if (dist <= 2 && ratio <= 0.35 && dist < bestScore) {
          bestScore = dist;
          bestMatch = app;
          if (dist == 1) break; // Early exit on very close match
        }
      }

      if (bestMatch != null) {
        if (!mounted) return;
        await _appCache.launchAppSafely(context, bestMatch.packageName);
        return;
      }
    }

    // 5. Web Fallback Search
    await _launchWebSearch(query);
  }

  Future<void> _launchWebSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final engine = prefs.getString('setting_search_engine') ?? 'Google';

    String urlStr;
    final encoded = Uri.encodeComponent(query);

    switch (engine) {
      case 'DuckDuckGo':
        urlStr = 'https://duckduckgo.com/?q=$encoded';
        break;
      case 'Bing':
        urlStr = 'https://www.bing.com/search?q=$encoded';
        break;
      case 'Brave':
        urlStr = 'https://search.brave.com/search?q=$encoded';
        break;
      case 'YouTube':
        urlStr = 'https://www.youtube.com/results?search_query=$encoded';
        break;
      case 'Wikipedia':
        urlStr = 'https://en.wikipedia.org/wiki/Special:Search?search=$encoded';
        break;
      case 'Google':
      default:
        urlStr = 'https://www.google.com/search?q=$encoded';
        break;
    }

    final url = Uri.parse(urlStr);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i <= t.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((curr, next) => curr < next ? curr : next);
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }

  void _openAppDrawer() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AppDrawerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
            ),
            child: child,
          );
        },
      ),
    );
  }

  void _openSettings() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Math result bubble
        if (_mathResult != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '= $_mathResult',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const Text(
                  'Tap enter to copy',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),

        // Search Bar container
        Material(
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
                    focusNode: _focusNode,
                    onSubmitted: _onSubmitted,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(color: Color(0xFF222222), fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Search apps, "alarm 7am", math...',
                      hintStyle: TextStyle(color: Color(0xFF9A9A9A), fontSize: 14),
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
                else ...[
                  IconButton(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_outlined, color: Color(0xFF777777)),
                    tooltip: 'Settings',
                  ),
                  IconButton(
                    onPressed: _openAppDrawer,
                    icon: const Icon(Icons.keyboard_arrow_up, color: Color(0xFF777777)),
                    tooltip: 'Open drawer',
                  ),
                ],
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
