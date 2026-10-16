import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:searchly/utils/app_cache_service.dart';

class AppShortcutsWidget extends StatefulWidget {
  const AppShortcutsWidget({super.key});

  @override
  State<AppShortcutsWidget> createState() => _AppShortcutsWidgetState();
}

class _AppShortcutsWidgetState extends State<AppShortcutsWidget> {
  List<AppInfo> shortcuts = [];
  bool _isLoading = true;
  final _appCache = AppCacheService();
  bool _loadStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loadStarted) return;
      _loadStarted = true;
      _loadShortcuts();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadShortcuts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? savedPackages = prefs.getStringList('app_shortcuts_v1');

      List<AppInfo> newShortcuts = [];
      if (savedPackages != null && savedPackages.isNotEmpty) {
        // Parallelize app info loading
        final results = await Future.wait(
          savedPackages.map((pkg) => _appCache.getAppInfo(pkg)),
        );
        newShortcuts = results
            .where((app) => app != null && app.icon != null)
            .cast<AppInfo>()
            .toList();
      } else {
        // Default to first 5 apps with icons
        List<AppInfo> installedApps = await _appCache.getInstalledApps();
        newShortcuts = installedApps
            .where((app) => app.icon != null)
            .take(5)
            .toList();
        await prefs.setStringList(
          'app_shortcuts_v1',
          newShortcuts.map((e) => e.packageName).toList(),
        );
      }

      if (mounted) {
        setState(() {
          shortcuts = newShortcuts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading shortcuts: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'app_shortcuts_v1',
      shortcuts.map((e) => e.packageName).toList(),
    );
  }

  void _removeApp(int index) {
    setState(() {
      shortcuts.removeAt(index);
    });
    _saveShortcuts();
  }

  void _showAddDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Add App', style: TextStyle(color: Colors.black)),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<AppInfo>>(
              future: _appCache.getInstalledApps(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  );
                }
                List<AppInfo> apps = snapshot.data!
                    .where((app) => app.icon != null)
                    .toList();
                apps.sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Image.memory(
                        apps[index].icon!,
                        width: 32,
                        height: 32,
                      ),
                      title: Text(
                        apps[index].name,
                        style: const TextStyle(color: Colors.black),
                      ),
                      onTap: () {
                        setState(() {
                          shortcuts.add(apps[index]);
                        });
                        _saveShortcuts();
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.black),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'APPS',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 12,
              letterSpacing: 2.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              addAutomaticKeepAlives: false,
              itemCount: shortcuts.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                if (index == shortcuts.length) {
                  return GestureDetector(
                    onTap: _showAddDialog,
                    child: SizedBox(
                      width: 56,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFEFEFEF),
                              ),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Color(0xFF888888),
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Add',
                            style: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                AppInfo app = shortcuts[index];
                return GestureDetector(
                  onTap: () {
                    _appCache.launchAppSafely(context, app.packageName);
                  },
                  onLongPress: () {
                    _removeApp(index);
                  },
                  child: SizedBox(
                    width: 56,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFEFEFEF)),
                          ),
                          child: Image.memory(
                            app.icon!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          app.name,
                          style: const TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
