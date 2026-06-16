import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_media_controller/flutter_media_controller.dart';

class MusicPlayerWidget extends StatefulWidget {
  const MusicPlayerWidget({super.key});

  @override
  State<MusicPlayerWidget> createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget> {
  MediaInfo? _mediaInfo;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndFetch();
  }

  Future<void> _requestPermissionAndFetch() async {
    // Request notification listener permission to read media
    try {
      await FlutterMediaController.requestPermissions();
    } catch (e) {
      debugPrint("Media permission error: $e");
    }

    _fetchMedia();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchMedia();
    });
  }

  Future<void> _fetchMedia() async {
    try {
      final info = await FlutterMediaController.getCurrentMediaInfo();
      if (info.track.startsWith('Error')) {
        _timer?.cancel();
        if (mounted) {
          setState(() {
            _mediaInfo = MediaInfo(
              track: 'Permission Needed',
              artist: 'Tap to fix',
              thumbnailUrl: '',
              isPlaying: false,
            );
          });
        }
        return;
      }
      
      if (mounted) {
        setState(() {
          _mediaInfo = info;
        });
      }
    } catch (e) {
      debugPrint("Error fetching media info: $e");
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _mediaInfo = MediaInfo(
            track: 'Permission Needed',
            artist: 'Tap to fix',
            thumbnailUrl: '',
            isPlaying: false,
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
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
          color: const Color(0xFF1E1E1E), // Dark grey
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
              child: const Icon(Icons.music_note, color: Color(0xFF888888), size: 24),
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
              children: [
                GestureDetector(
                  onTap: () async {
                    await FlutterMediaController.previousTrack();
                    _fetchMedia();
                  },
                  child: const Icon(Icons.skip_previous_outlined, color: Color(0xFF888888), size: 24),
                ),
                const SizedBox(width: 16),
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
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () async {
                    await FlutterMediaController.nextTrack();
                    _fetchMedia();
                  },
                  child: const Icon(Icons.skip_next_outlined, color: Color(0xFF888888), size: 24),
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
                  ? Container(
                      height: 2,
                      width: 40, // Mock progress
                      color: Colors.white,
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
