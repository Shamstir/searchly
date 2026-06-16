import 'dart:async';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';

class ImageGalleryWidget extends StatefulWidget {
  const ImageGalleryWidget({super.key});

  @override
  State<ImageGalleryWidget> createState() => _ImageGalleryWidgetState();
}

class _ImageGalleryWidgetState extends State<ImageGalleryWidget> {
  int _currentIndex = 0;
  Timer? _timer;
  List<AssetEntity> _images = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _fetchImages();
  }
  
  Future<void> _fetchImages() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(type: RequestType.image);
      if (albums.isNotEmpty) {
        List<AssetEntity> photos = await albums[0].getAssetListPaged(page: 0, size: 20);
        if (mounted) {
          setState(() {
            _images = photos;
            _isLoading = false;
          });
        }
        
        if (_images.isNotEmpty) {
          _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
            if (mounted) {
              setState(() {
                _currentIndex = (_currentIndex + 1) % _images.length;
              });
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(seconds: 1),
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : _images.isEmpty
                        ? Container(
                            color: const Color(0xFFE5E5E5),
                            child: const Center(
                              child: Icon(Icons.photo_library_outlined, color: Color(0xFFAAAAAA), size: 40),
                            ),
                          )
                        : FutureBuilder<Uint8List?>(
                            key: ValueKey<int>(_currentIndex),
                            future: _images[_currentIndex].thumbnailDataWithSize(const ThumbnailSize(600, 600)),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                );
                              }
                              return Container(color: const Color(0xFFE5E5E5));
                            },
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.only(left: 12, bottom: 8),
                      alignment: Alignment.bottomLeft,
                      child: const Text(
                        'Today • 9:12 AM', // Mock text
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GALLERY',
                  style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 10,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFE5E5E5), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFE5E5E5), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFE5E5E5), shape: BoxShape.circle)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
