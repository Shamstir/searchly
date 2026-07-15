import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_media_controller/flutter_media_controller.dart';

class MusicPlayerWidget extends StatefulWidget {
  final Function(MediaInfo?)? onMediaUpdate;

  const MusicPlayerWidget({super.key, this.onMediaUpdate});

  @override
  State<MusicPlayerWidget> createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget>
    with WidgetsBindingObserver {
  MediaInfo? _mediaInfo;
  Timer? _timer;
  Uint8List? _cachedArtBytes;
  String _lastTrack = '';
  String _lastArtist = '';
  String _lastThumbnailHash = '';
  static final _whitespaceRegex = RegExp(r'\s+');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _fetchMedia();
    _timer = Timer.periodic(const Duration(seconds: 8), (timer) {
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
        // Stop polling — permission is missing. User must tap to retry.
        _timer?.cancel();
        _timer = null;
        final errorInfo = MediaInfo(
          track: 'Permission Needed',
          artist: 'Tap to fix',
          thumbnailUrl: '',
          isPlaying: false,
        );
        setState(() {
          _mediaInfo = errorInfo;
        });
        widget.onMediaUpdate?.call(errorInfo);
        return;
      }

      // Only update if something actually changed
      final bool trackChanged =
          info.track != _lastTrack || info.artist != _lastArtist;
      final bool artChanged = info.thumbnailUrl != _lastThumbnailHash;
      final bool playStateChanged =
          (_mediaInfo?.isPlaying ?? false) != info.isPlaying;

      if (!trackChanged && !artChanged && !playStateChanged) return;

      // Cache decoded art bytes only when thumbnail actually changes
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

      setState(() {
        _mediaInfo = info;
      });

      // Only notify parent when track or art actually changed (not just play state)
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
          artist: 'Tap to fix',
          thumbnailUrl: '',
          isPlaying: false,
        );
        setState(() {
          _mediaInfo = errorInfo;
        });
        widget.onMediaUpdate?.call(errorInfo);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isPlaying = _mediaInfo?.isPlaying ?? false;
    String track = _mediaInfo?.track ?? 'No track playing';
    String artist = _mediaInfo?.artist ?? 'Unknown artist';

    return GestureDetector(
      onTap: () {
        if (_mediaInfo?.track == 'Permission Needed') {
          _requestPermissionAndFetch();
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
                      errorBuilder: (context, error, stackTrace) => const Icon(
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
            const SizedBox(height: 16),
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
                const SizedBox(height: 8),
                Text(
                  track,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  artist,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            Container(
              height: 2,
              width: double.infinity,
              color: const Color(0xFF333333),
              alignment: Alignment.centerLeft,
              child: isPlaying
                  ? Container(height: 2, width: 40, color: Colors.white)
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
