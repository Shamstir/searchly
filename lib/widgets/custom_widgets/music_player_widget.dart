import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_media_controller/flutter_media_controller.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class MusicPlayerWidget extends StatefulWidget {
  final Function(MediaInfo?)? onMediaUpdate;

  const MusicPlayerWidget({super.key, this.onMediaUpdate});

  @override
  State<MusicPlayerWidget> createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  MediaInfo? _mediaInfo;
  Timer? _timer;
  Uint8List? _cachedArtBytes;
  String _lastTrack = '';
  String _lastArtist = '';
  String _lastThumbnailHash = '';
  static final _whitespaceRegex = RegExp(r'\s+');

  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _fetchMedia();
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      _fetchMedia();
    });
  }

  Future<void> _requestPermissionAndFetch() async {
    _timer?.cancel();
    try {
      await FlutterMediaController.requestPermissions();
    } catch (e) {
      debugPrint("Media permission error: $e");
    }

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    _startPolling();
  }

  Future<void> _fetchMedia() async {
    try {
      final info = await FlutterMediaController.getCurrentMediaInfo();
      if (!mounted) return;

      if (info.track.startsWith('Error')) {
        _timer?.cancel();
        _timer = null;
        final errorInfo = MediaInfo(
          track: 'Permission Needed',
          artist: 'Tap to grant access',
          thumbnailUrl: '',
          isPlaying: false,
        );
        setState(() => _mediaInfo = errorInfo);
        widget.onMediaUpdate?.call(errorInfo);
        return;
      }

      final bool trackChanged =
          info.track != _lastTrack || info.artist != _lastArtist;
      final bool artChanged = info.thumbnailUrl != _lastThumbnailHash;
      final bool playStateChanged =
          (_mediaInfo?.isPlaying ?? false) != info.isPlaying;

      if (!trackChanged && !artChanged && !playStateChanged) return;

      if (artChanged && info.thumbnailUrl.isNotEmpty) {
        try {
          _cachedArtBytes = base64Decode(
            info.thumbnailUrl.replaceAll(_whitespaceRegex, ''),
          );
        } catch (e) {
          _cachedArtBytes = null;
        }
      } else if (info.thumbnailUrl.isEmpty) {
        _cachedArtBytes = null;
      }

      _lastTrack = info.track;
      _lastArtist = info.artist;
      _lastThumbnailHash = info.thumbnailUrl;

      setState(() => _mediaInfo = info);

      if (trackChanged || artChanged) {
        widget.onMediaUpdate?.call(info);
      }
    } catch (e) {
      debugPrint("Error fetching media info: $e");
      _timer?.cancel();
      _timer = null;
      if (mounted) {
        final errorInfo = MediaInfo(
          track: 'Permission Needed',
          artist: 'Tap to grant access',
          thumbnailUrl: '',
          isPlaying: false,
        );
        setState(() => _mediaInfo = errorInfo);
        widget.onMediaUpdate?.call(errorInfo);
      }
    }
  }

  void _openActiveMusicApp() {
    // Attempt to open standard music action intent
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        category: 'android.intent.category.APP_MUSIC',
      );
      intent.launch();
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isPlaying = _mediaInfo?.isPlaying ?? false;
    String track = _mediaInfo?.track ?? 'No track playing';
    String artist = _mediaInfo?.artist ?? 'Tap to play music';
    bool needsPermission = _mediaInfo?.track == 'Permission Needed';

    return GestureDetector(
      onTap: () {
        if (needsPermission) {
          _requestPermissionAndFetch();
        } else {
          _openActiveMusicApp();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: _cachedArtBytes != null
                      ? Image.memory(
                          _cachedArtBytes!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          cacheWidth: 96,
                          cacheHeight: 96,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.music_note,
                            color: Color(0xFF888888),
                            size: 24,
                          ),
                        )
                      : const Icon(
                          Icons.music_note,
                          color: Color(0xFF888888),
                          size: 24,
                        ),
                ),
                if (isPlaying)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'PLAYING',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NOW PLAYING',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 10,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  track,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  artist,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () async {
                    await FlutterMediaController.previousTrack();
                    _fetchMedia();
                  },
                  child: const Icon(
                    Icons.skip_previous_outlined,
                    color: Color(0xFF888888),
                    size: 24,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await FlutterMediaController.togglePlayPause();
                    _fetchMedia();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await FlutterMediaController.nextTrack();
                    _fetchMedia();
                  },
                  child: const Icon(
                    Icons.skip_next_outlined,
                    color: Color(0xFF888888),
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress Scrubber bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Container(
                height: 3,
                width: double.infinity,
                color: const Color(0xFF333333),
                alignment: Alignment.centerLeft,
                child: isPlaying
                    ? AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, _) {
                          return FractionallySizedBox(
                            widthFactor:
                                (_progressController.value * 0.7 + 0.3).clamp(0.0, 1.0),
                            child: Container(color: Colors.white),
                          );
                        },
                      )
                    : const SizedBox(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
