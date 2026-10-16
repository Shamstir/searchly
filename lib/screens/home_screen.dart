import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_media_controller/flutter_media_controller.dart';
import 'package:searchly/screens/app_drawer_screen.dart';
import 'package:searchly/services/context_engine.dart';
import 'package:searchly/widgets/custom_widget_container.dart';
import 'package:searchly/widgets/custom_widgets/app_shortcuts_widget.dart';
import 'package:searchly/widgets/custom_widgets/clock_widget.dart';
import 'package:searchly/widgets/custom_widgets/image_gallery_widget.dart';
import 'package:searchly/widgets/custom_widgets/music_player_widget.dart';
import 'package:searchly/widgets/custom_widgets/predictive_app_row.dart';
import 'package:searchly/widgets/custom_widgets/screen_time_widget.dart';
import 'package:searchly/widgets/custom_widgets/system_control_widget.dart';
import 'package:searchly/widgets/custom_widgets/todo_list_widget.dart';
import 'package:searchly/widgets/custom_widgets/weather_widget.dart';
import 'package:searchly/widgets/search_bar_widget.dart';

import '../utils/app_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Uint8List? _cachedBgArtBytes;
  String _lastBgThumbnail = '';
  bool _deferredWidgetsReady = false;

  final _contextEngine = ContextEngine.instance;
  StreamSubscription<ContextState>? _contextSub;
  ContextState _context = ContextState.initial();

  void _onAppCacheChanged() {
    if (mounted) setState(() {});
  }

  bool _dynamicBgEnabled = true;

  static const _launcherChannel = MethodChannel('searchly/launcher');

  final Map<String, Size> _customSizes = {};

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _dynamicBgEnabled = prefs.getBool('setting_dynamic_bg') ?? true;
        final sizesJson = prefs.getString('widget_sizes_v1');
        if (sizesJson != null) {
          try {
            final decoded = jsonDecode(sizesJson) as Map<String, dynamic>;
            _customSizes.clear();
            decoded.forEach((k, v) {
              if (v is List && v.length >= 2) {
                _customSizes[k] = Size((v[0] as num).toDouble(), (v[1] as num).toDouble());
              }
            });
          } catch (_) {}
        } else {
          _customSizes.clear();
        }
      });
    }
  }

  Future<void> _saveWidgetSize(String key, double w, double h) async {
    _customSizes[key] = Size(w, h);
    final prefs = await SharedPreferences.getInstance();
    final map = _customSizes.map((k, v) => MapEntry(k, [v.width, v.height]));
    await prefs.setString('widget_sizes_v1', jsonEncode(map));
  }

  Future<dynamic> _handlePlatformCall(MethodCall call) async {
    if (call.method == 'onHomePressed') {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _launcherChannel.setMethodCallHandler(_handlePlatformCall);
    _loadSettings();
    _contextEngine.start();
    _context = _contextEngine.currentState;
    _contextSub = _contextEngine.stream.listen((state) {
      if (mounted) setState(() => _context = state);
    });
    AppCacheService().addListener(_onAppCacheChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _deferredWidgetsReady = true);
      }
    });
  }

  @override
  void dispose() {
    _contextEngine.stop();
    _contextSub?.cancel();
    AppCacheService().removeListener(_onAppCacheChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _contextEngine.start();
      _loadSettings();
    } else if (state == AppLifecycleState.paused) {
      _contextEngine.stop();
    }
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
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
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

  static Uint8List? _decodeBase64Background(String base64Str) {
    try {
      final clean = base64Str.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  void _handleMediaUpdate(MediaInfo? info) async {
    if (!mounted) return;

    // Notify the ContextEngine about media playback state
    final isPlaying = info?.isPlaying ?? false;
    _contextEngine.updateMediaPlaying(isPlaying);

    final newThumb = info?.thumbnailUrl ?? '';
    if (newThumb == _lastBgThumbnail) return;

    _lastBgThumbnail = newThumb;
    if (newThumb.isEmpty) {
      if (mounted) setState(() => _cachedBgArtBytes = null);
      return;
    }

    try {
      final decoded = await compute(_decodeBase64Background, newThumb);
      if (mounted && _lastBgThumbnail == newThumb) {
        setState(() => _cachedBgArtBytes = decoded);
      }
    } catch (e) {
      if (mounted) setState(() => _cachedBgArtBytes = null);
    }
  }

  List<Widget> _buildWidgets(double screenWidth) {
    final fullWidth = screenWidth > 40 ? screenWidth - 40 : 0.0;
    final halfWidth = screenWidth > 64 ? (screenWidth - 64) / 2 : 0.0;

    // --- Define all widgets as named entries with persisted or default sizes ---
    final clock = CustomWidgetContainer(
      key: const ValueKey('clock'),
      initialWidth: _customSizes['clock']?.width ?? fullWidth,
      initialHeight: _customSizes['clock']?.height ?? 120,
      onUpdate: (w, h) => _saveWidgetSize('clock', w, h),
      isNight: false,
      child: const RepaintBoundary(child: ClockWidget()),
    );
    final weather = CustomWidgetContainer(
      key: const ValueKey('weather'),
      initialWidth: _customSizes['weather']?.width ?? fullWidth,
      initialHeight: _customSizes['weather']?.height ?? 180,
      onUpdate: (w, h) => _saveWidgetSize('weather', w, h),
      isNight: false,
      child: const RepaintBoundary(child: WeatherWidget()),
    );
    final music = CustomWidgetContainer(
      key: const ValueKey('music'),
      initialWidth: _customSizes['music']?.width ?? halfWidth,
      initialHeight: _customSizes['music']?.height ?? 270,
      onUpdate: (w, h) => _saveWidgetSize('music', w, h),
      isNight: _context.isNight,
      child: _deferredWidgetsReady
          ? RepaintBoundary(child: MusicPlayerWidget(onMediaUpdate: _handleMediaUpdate))
          : const _WidgetPlaceholder(
              icon: Icons.music_note,
              title: 'NOW PLAYING',
            ),
    );
    final gallery = CustomWidgetContainer(
      key: const ValueKey('gallery'),
      initialWidth: _customSizes['gallery']?.width ?? halfWidth,
      initialHeight: _customSizes['gallery']?.height ?? 270,
      onUpdate: (w, h) => _saveWidgetSize('gallery', w, h),
      isNight: _context.isNight,
      child: _deferredWidgetsReady
          ? const RepaintBoundary(child: ImageGalleryWidget())
          : const _WidgetPlaceholder(
              icon: Icons.photo_library_outlined,
              title: 'GALLERY',
            ),
    );
    final systemControls = CustomWidgetContainer(
      key: const ValueKey('system'),
      initialWidth: _customSizes['system']?.width ?? fullWidth,
      initialHeight: _customSizes['system']?.height ?? 180,
      onUpdate: (w, h) => _saveWidgetSize('system', w, h),
      isNight: _context.isNight,
      child: const SystemControlWidget(),
    );
    final todo = CustomWidgetContainer(
      key: const ValueKey('todo'),
      initialWidth: _customSizes['todo']?.width ?? halfWidth,
      initialHeight: _customSizes['todo']?.height ?? 220,
      onUpdate: (w, h) => _saveWidgetSize('todo', w, h),
      isNight: _context.isNight,
      child: const TodoListWidget(),
    );
    final screenTime = CustomWidgetContainer(
      key: const ValueKey('screenTime'),
      initialWidth: _customSizes['screenTime']?.width ?? halfWidth,
      initialHeight: _customSizes['screenTime']?.height ?? 220,
      onUpdate: (w, h) => _saveWidgetSize('screenTime', w, h),
      isNight: _context.isNight,
      child: _deferredWidgetsReady
          ? const ScreenTimeWidget()
          : const _WidgetPlaceholder(
              icon: Icons.bar_chart,
              title: 'SCREEN TIME',
            ),
    );
    final appShortcuts = CustomWidgetContainer(
      key: const ValueKey('apps'),
      initialWidth: _customSizes['apps']?.width ?? fullWidth,
      initialHeight: _customSizes['apps']?.height ?? 140,
      onUpdate: (w, h) => _saveWidgetSize('apps', w, h),
      isNight: _context.isNight,
      child: _deferredWidgetsReady
          ? const AppShortcutsWidget()
          : const _WidgetPlaceholder(icon: Icons.apps, title: 'APPS'),
    );

    // --- Context-aware reordering ---
    if (_context.isMediaPlaying) {
      // Music is playing → promote music widget right after clock
      return [clock, music, gallery, weather, systemControls, todo, screenTime, appShortcuts];
    }

    if (_context.isNight) {
      // Night → promote system controls (brightness) and demote gallery
      return [clock, weather, systemControls, gallery, music, todo, screenTime, appShortcuts];
    }

    if (_context.timeSlot == TimeSlot.morning) {
      // Morning → promote todo and weather
      return [clock, weather, todo, screenTime, music, gallery, systemControls, appShortcuts];
    }

    // Default order
    return [clock, weather, music, gallery, systemControls, todo, screenTime, appShortcuts];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hasArt = _cachedBgArtBytes != null && _dynamicBgEnabled;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -300) {
            _openAppDrawer();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasArt)
              Positioned.fill(
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        _cachedBgArtBytes!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        cacheWidth: 360,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(),
                      ),
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          color: const Color(0xFF121212).withValues(alpha: 0.40),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SafeArea(
              child: Stack(
                children: [
                  RepaintBoundary(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics()),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(
                        top: 16,
                        bottom: 180,
                        left: 12,
                        right: 12,
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _buildWidgets(screenWidth),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16, top: 40),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF121212).withValues(alpha: 0.6),
                            const Color(0xFF121212).withValues(alpha: 0.95),
                            const Color(0xFF121212),
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PredictiveAppRow(),
                          const SizedBox(height: 10),
                          const SearchBarWidget(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _WidgetPlaceholder extends StatelessWidget {
  const _WidgetPlaceholder({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFAAAAAA), size: 30),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
