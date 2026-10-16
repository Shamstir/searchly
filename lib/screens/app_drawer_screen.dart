import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:searchly/utils/app_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class AppDrawerScreen extends StatefulWidget {
  const AppDrawerScreen({super.key});

  @override
  State<AppDrawerScreen> createState() => _AppDrawerScreenState();
}

class _AppDrawerScreenState extends State<AppDrawerScreen> {
  final _appCache = AppCacheService();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  List<AppInfo> _allApps = [];
  List<AppInfo> _filteredApps = [];
  Set<String> _hiddenPackages = {};
  String _selectedCategory = 'All';
  bool _isLoading = true;

  final List<String> _categories = [
    'All',
    'Social',
    'Media',
    'Work',
    'Tools',
    'Games',
  ];

  static const _alphabet = [
    '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I',
    'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S',
    'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, String> _nativeCategories = {};

  Future<void> _loadApps() async {
    final prefs = await SharedPreferences.getInstance();
    _hiddenPackages = (prefs.getStringList('hidden_apps_v1') ?? []).toSet();

    _nativeCategories = await _appCache.getAppCategories();

    final installed = await _appCache.getInstalledApps(withIcon: false);
    if (!mounted) return;
    setState(() {
      _allApps = installed.where((a) => !_hiddenPackages.contains(a.packageName)).toList();
      _filteredApps = _applyFilters(_allApps);
      _isLoading = false;
    });

    final appsWithIcons = await _appCache.getInstalledApps(withIcon: true);
    if (!mounted) return;
    setState(() {
      _allApps = appsWithIcons.where((a) => !_hiddenPackages.contains(a.packageName)).toList();
      _filteredApps = _applyFilters(_allApps);
    });
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() {
          _filteredApps = _applyFilters(_allApps);
        });
      }
    });
  }

  List<AppInfo> _applyFilters(List<AppInfo> source) {
    var result = source;

    // Search text filter
    final query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      result = result.where((app) => app.name.toLowerCase().contains(query)).toList();
    }

    // Category filter
    if (_selectedCategory != 'All') {
      result = result.where((app) => _matchesCategory(app, _selectedCategory)).toList();
    }

    return result;
  }

  bool _matchesCategory(AppInfo app, String category) {
    // 1. Check native system category if available
    final nativeCat = _nativeCategories[app.packageName];
    if (nativeCat != null && nativeCat == category) {
      return true;
    }

    final pkg = app.packageName.toLowerCase();
    final name = app.name.toLowerCase();

    switch (category) {
      case 'Social':
        return pkg.contains('whatsapp') ||
            pkg.contains('instagram') ||
            pkg.contains('twitter') ||
            pkg.contains('facebook') ||
            pkg.contains('snapchat') ||
            pkg.contains('telegram') ||
            pkg.contains('discord') ||
            pkg.contains('reddit') ||
            pkg.contains('signal') ||
            pkg.contains('threads') ||
            pkg.contains('tiktok') ||
            pkg.contains('linkedin') ||
            name.contains('message') ||
            name.contains('chat') ||
            name.contains('social');
      case 'Media':
        return pkg.contains('youtube') ||
            pkg.contains('spotify') ||
            pkg.contains('music') ||
            pkg.contains('netflix') ||
            pkg.contains('prime') ||
            pkg.contains('gallery') ||
            pkg.contains('camera') ||
            pkg.contains('photo') ||
            pkg.contains('video') ||
            pkg.contains('sound') ||
            pkg.contains('vlc') ||
            pkg.contains('podcast') ||
            pkg.contains('audiomack') ||
            pkg.contains('soundcloud') ||
            pkg.contains('deezer') ||
            pkg.contains('twitch') ||
            name.contains('music') ||
            name.contains('player') ||
            name.contains('video') ||
            name.contains('camera');
      case 'Work':
        return pkg.contains('gmail') ||
            pkg.contains('slack') ||
            pkg.contains('teams') ||
            pkg.contains('zoom') ||
            pkg.contains('docs') ||
            pkg.contains('drive') ||
            pkg.contains('excel') ||
            pkg.contains('notes') ||
            pkg.contains('keep') ||
            pkg.contains('calendar') ||
            pkg.contains('notion') ||
            pkg.contains('obsidian') ||
            pkg.contains('trello') ||
            pkg.contains('jira') ||
            pkg.contains('meet') ||
            pkg.contains('word') ||
            pkg.contains('pdf') ||
            pkg.contains('sheet') ||
            pkg.contains('office') ||
            name.contains('mail') ||
            name.contains('doc') ||
            name.contains('note') ||
            name.contains('calendar');
      case 'Tools':
        return pkg.contains('calc') ||
            pkg.contains('clock') ||
            pkg.contains('settings') ||
            pkg.contains('file') ||
            pkg.contains('manager') ||
            pkg.contains('browser') ||
            pkg.contains('chrome') ||
            pkg.contains('firefox') ||
            pkg.contains('brave') ||
            pkg.contains('opera') ||
            pkg.contains('termux') ||
            pkg.contains('vpn') ||
            pkg.contains('scanner') ||
            pkg.contains('map') ||
            pkg.contains('weather') ||
            name.contains('tool') ||
            name.contains('browser') ||
            name.contains('cleaner') ||
            name.contains('compass');
      case 'Games':
        return pkg.contains('game') ||
            pkg.contains('play') ||
            pkg.contains('unity') ||
            pkg.contains('epic') ||
            pkg.contains('supercell') ||
            pkg.contains('steam') ||
            pkg.contains('roblox') ||
            pkg.contains('minecraft') ||
            pkg.contains('pubg') ||
            pkg.contains('riot') ||
            name.contains('game') ||
            name.contains('quest') ||
            name.contains('racer') ||
            name.contains('arcade');
      default:
        return true;
    }
  }

  Future<void> _launch(AppInfo app) async {
    await _appCache.launchAppSafely(context, app.packageName);
    if (mounted) Navigator.pop(context);
  }

  void _scrollToLetter(String letter) {
    HapticFeedback.selectionClick();
    if (_filteredApps.isEmpty) return;

    int targetIndex = -1;
    if (letter == '#') {
      targetIndex = 0;
    } else {
      targetIndex = _filteredApps.indexWhere(
        (app) => app.name.toUpperCase().startsWith(letter),
      );
    }

    if (targetIndex != -1) {
      final cols = _crossAxisCount;
      final row = targetIndex ~/ cols;
      const rowHeight = 96.0;
      final offset = (row * rowHeight).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(offset);
    }
  }

  void _showAppContextMenu(AppInfo app) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18191C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      if (app.icon != null)
                        Container(
                          width: 44,
                          height: 44,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Image.memory(app.icon!, fit: BoxFit.contain),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              app.packageName,
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 20),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.white70),
                  title: const Text('App Info', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    final intent = AndroidIntent(
                      action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
                      data: 'package:${app.packageName}',
                      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
                    );
                    intent.launch();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.push_pin_outlined, color: Colors.white70),
                  title: const Text('Pin to Dashboard Shortcuts', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    List<String> list = prefs.getStringList('app_shortcuts_v1') ?? [];
                    if (!list.contains(app.packageName)) {
                      list.add(app.packageName);
                      await prefs.setStringList('app_shortcuts_v1', list);
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Pinned "${app.name}" to dashboard')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.visibility_off_outlined, color: Colors.white70),
                  title: const Text('Hide App from Drawer', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    _hiddenPackages.add(app.packageName);
                    await prefs.setStringList('hidden_apps_v1', _hiddenPackages.toList());
                    if (context.mounted) {
                      Navigator.pop(context);
                      _loadApps();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hidden "${app.name}"')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.shop_outlined, color: Colors.white70),
                  title: const Text('View on Google Play Store', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(context);
                    final url = Uri.parse('market://details?id=${app.packageName}');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    } else {
                      final webUrl = Uri.parse('https://play.google.com/store/apps/details?id=${app.packageName}');
                      await launchUrl(webUrl);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Uninstall App', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    final intent = AndroidIntent(
                      action: 'android.intent.action.DELETE',
                      data: 'package:${app.packageName}',
                      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
                    );
                    intent.launch();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int get _crossAxisCount {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 720) return 6;
    if (width >= 520) return 5;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Top Search row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                          tooltip: 'Close',
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onSubmitted: (val) {
                                if (_filteredApps.isNotEmpty) _launch(_filteredApps.first);
                              },
                              textInputAction: TextInputAction.search,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Search installed apps...',
                                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                                prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: _searchController.clear,
                                        icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                                      ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Category filter chips
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedCategory = cat;
                              _filteredApps = _applyFilters(_allApps);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // App count indicator
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 36, 6),
                    child: Row(
                      children: [
                        Text(
                          '${_filteredApps.length} APPS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Long-press for options',
                          style: TextStyle(color: Colors.white24, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  // App Grid
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : _filteredApps.isEmpty
                            ? const Center(
                                child: Text('No apps found', style: TextStyle(color: Colors.white54, fontSize: 15)),
                              )
                            : GridView.builder(
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: const EdgeInsets.fromLTRB(16, 4, 36, 28),
                                cacheExtent: 900,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _crossAxisCount,
                                  childAspectRatio: 0.70,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: _filteredApps.length,
                                itemBuilder: (context, index) {
                                  final app = _filteredApps[index];
                                  return _DrawerAppTile(
                                    app: app,
                                    onTap: () => _launch(app),
                                    onLongPress: () => _showAppContextMenu(app),
                                  );
                                },
                              ),
                  ),
                ],
              ),

              // A-Z Vertical Index Sidebar
              Positioned(
                right: 4,
                top: 100,
                bottom: 20,
                child: Center(
                  child: Container(
                    width: 20,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _alphabet.map((letter) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _scrollToLetter(letter),
                          child: Text(
                            letter,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerAppTile extends StatelessWidget {
  const _DrawerAppTile({
    required this.app,
    required this.onTap,
    required this.onLongPress,
  });

  final AppInfo app;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (app.icon != null)
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Image.memory(
                    app.icon!,
                    gaplessPlayback: true,
                    cacheWidth: 116,
                    cacheHeight: 116,
                    filterQuality: FilterQuality.low,
                  ),
                )
              else
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.apps, size: 28, color: Colors.white70),
                ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  app.name,
                  style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
