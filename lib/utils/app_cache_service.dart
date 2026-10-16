import 'dart:async';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
/// Singleton service that caches installed apps to avoid duplicate
/// heavy loading across multiple widgets (search bar, app drawer, shortcuts).
class AppCacheService extends ChangeNotifier {
  static final AppCacheService _instance = AppCacheService._internal();
  factory AppCacheService() => _instance;
  
  AppCacheService._internal() {
    _packageChangeSub = packageEventChannel.receiveBroadcastStream().listen((event) {
      debugPrint("Package change detected: $event");
      invalidate();
      notifyListeners();
    });
  }

  static const platform = MethodChannel('searchly/launcher');
  static const packageEventChannel = EventChannel('searchly/package_changes');
  StreamSubscription? _packageChangeSub;

  List<AppInfo>? _cachedAppsWithIcons;
  List<AppInfo>? _cachedAppsWithoutIcons;
  DateTime? _lastFetchWithIconsTime;
  DateTime? _lastFetchWithoutIconsTime;
  Completer<List<AppInfo>>? _fetchCompleter;
  bool? _fetchWithIcon;

  /// Returns cached apps, or fetches fresh if cache is stale (> 5 minutes old).
  /// Uses a Completer to coalesce concurrent callers into a single fetch.
  Future<List<AppInfo>> getInstalledApps({
    bool withIcon = true,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final cachedApps = withIcon
        ? _cachedAppsWithIcons
        : _cachedAppsWithoutIcons;
    final lastFetchTime = withIcon
        ? _lastFetchWithIconsTime
        : _lastFetchWithoutIconsTime;
    final cacheValid =
        cachedApps != null &&
        lastFetchTime != null &&
        now.difference(lastFetchTime).inMinutes < 5 &&
        !forceRefresh;

    if (cacheValid) return cachedApps;

    // If a fetch is already in progress, wait for it instead of starting another
    if (_fetchCompleter != null && _fetchWithIcon == withIcon) {
      return _fetchCompleter!.future;
    } else if (_fetchCompleter != null) {
      await _fetchCompleter!.future;
      return getInstalledApps(withIcon: withIcon, forceRefresh: forceRefresh);
    }

    _fetchCompleter = Completer<List<AppInfo>>();
    _fetchWithIcon = withIcon;
    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        excludeNonLaunchableApps: true,
        withIcon: withIcon,
      );
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (withIcon) {
        _cachedAppsWithIcons = apps;
        _lastFetchWithIconsTime = DateTime.now();
      } else {
        _cachedAppsWithoutIcons = apps;
        _lastFetchWithoutIconsTime = DateTime.now();
      }
      _fetchCompleter!.complete(apps);
    } catch (e) {
      _fetchCompleter!.complete(cachedApps ?? <AppInfo>[]);
      _fetchCompleter = null;
      _fetchWithIcon = null;
      return cachedApps ?? [];
    }

    final result = withIcon
        ? _cachedAppsWithIcons ?? <AppInfo>[]
        : _cachedAppsWithoutIcons ?? <AppInfo>[];
    _fetchCompleter = null;
    _fetchWithIcon = null;
    return result;
  }

  /// Get info for a single app (uses cache if available).
  Future<AppInfo?> getAppInfo(String packageName) async {
    if (_cachedAppsWithIcons != null) {
      try {
        return _cachedAppsWithIcons!.firstWhere(
          (a) => a.packageName == packageName,
        );
      } catch (_) {
        // Not in cache, fall through to direct lookup
      }
    }
    return InstalledApps.getAppInfo(packageName);
  }

  Map<String, String>? _cachedCategories;

  /// Fetches system categorized apps from Android PackageManager (API 26+)
  Future<Map<String, String>> getAppCategories() async {
    if (_cachedCategories != null) return _cachedCategories!;
    try {
      final res = await platform.invokeMethod<Map>('getAppCategories');
      if (res != null) {
        _cachedCategories = res.map((k, v) => MapEntry(k.toString(), v.toString()));
        return _cachedCategories!;
      }
    } catch (e) {
      debugPrint("Error fetching app categories: $e");
    }
    return _cachedCategories ?? {};
  }

  /// Invalidate cache (e.g., after app install/uninstall).
  void invalidate() {
    _cachedAppsWithIcons = null;
    _cachedAppsWithoutIcons = null;
    _cachedCategories = null;
    _fetchWithIcon = null;
    _lastFetchWithIconsTime = null;
    _lastFetchWithoutIconsTime = null;
  }

  /// Launch an app explicitly with FLAG_ACTIVITY_NEW_TASK
  Future<void> launchAppSafely(BuildContext context, String packageName) async {
    try {
      final success = await platform.invokeMethod<bool>(
        'launchAppExplicitly', 
        {'package_name': packageName}
      );
      if (success != true) {
        throw Exception('App not found or could not be launched');
      }
    } catch (e) {
      debugPrint("Failed to launch app safely: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App could not be launched')),
        );
      }
    }
  }

  @override
  void dispose() {
    _packageChangeSub?.cancel();
    super.dispose();
  }
}
