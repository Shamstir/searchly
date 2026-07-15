import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:searchly/utils/app_cache_service.dart';

class AppDrawerScreen extends StatefulWidget {
  const AppDrawerScreen({super.key});

  @override
  State<AppDrawerScreen> createState() => _AppDrawerScreenState();
}

class _AppDrawerScreenState extends State<AppDrawerScreen> {
  final _appCache = AppCacheService();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  List<AppInfo> _apps = [];
  List<AppInfo> _filteredApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final installedApps = await _appCache.getInstalledApps(withIcon: false);
    if (!mounted) return;
    setState(() {
      _apps = installedApps;
      _filteredApps = installedApps;
      _isLoading = false;
    });

    final appsWithIcons = await _appCache.getInstalledApps(withIcon: true);
    if (!mounted) return;
    setState(() {
      _apps = appsWithIcons;
      _filteredApps = _filterApps(_searchController.text);
    });
  }

  void _onSearchChanged() {
    setState(() {
      _filteredApps = _filterApps(_searchController.text);
    });
  }

  List<AppInfo> _filterApps(String value) {
    final query = value.toLowerCase().trim();
    return query.isEmpty
        ? _apps
        : _apps.where((app) => app.name.toLowerCase().contains(query)).toList();
  }

  Future<void> _launch(AppInfo app) async {
    await _appCache.launchAppSafely(context, app.packageName);
    if (mounted) Navigator.pop(context);
  }

  void _submitSearch(String value) {
    if (_filteredApps.isNotEmpty) {
      _launch(_filteredApps.first);
    }
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
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          }
        },
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white70,
                      ),
                      tooltip: 'Close',
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onSubmitted: _submitSearch,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search apps',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.48),
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.white70,
                            ),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: _searchController.clear,
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white54,
                                    ),
                                    tooltip: 'Clear',
                                  ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Row(
                  children: [
                    Text(
                      '${_filteredApps.length} apps',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Swipe down to close',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.30),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _filteredApps.isEmpty
                    ? const Center(
                        child: Text(
                          'No apps found',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      )
                    : GridView.builder(
                        physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics()),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                        cacheExtent: 900,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _crossAxisCount,
                          childAspectRatio: 0.68,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 18,
                        ),
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          return _DrawerAppTile(
                            app: app,
                            onTap: () => _launch(app),
                          );
                        },
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
  const _DrawerAppTile({required this.app, required this.onTap});

  final AppInfo app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (app.icon != null)
                Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
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
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.apps,
                    size: 30,
                    color: Colors.white70,
                  ),
                ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  app.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.12,
                  ),
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
