import 'dart:async';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isLoading = false;
  bool _hasRequestedAccess = false;
  String _selectedAlbumId = '';
  String _selectedAlbumName = 'GALLERY';
  final Map<int, Uint8List> _thumbnailCache = {};

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchImages() async {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _hasRequestedAccess = true;
        _isLoading = true;
      });
    }

    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );
      if (albums.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        _selectedAlbumId = prefs.getString('gallery_album_id') ?? '';

        AssetPathEntity selectedAlbum = albums.first;
        if (_selectedAlbumId.isNotEmpty) {
          try {
            selectedAlbum = albums.firstWhere(
              (element) => element.id == _selectedAlbumId,
            );
          } catch (e) {
            // Album might have been deleted
          }
        }

        if (mounted) {
          setState(() {
            _selectedAlbumName = selectedAlbum.name.toUpperCase();
          });
        }

        List<AssetEntity> photos = await selectedAlbum.getAssetListPaged(
          page: 0,
          size: 20,
        );
        if (mounted) {
          setState(() {
            _images = photos;
            _isLoading = false;
          });
        }

        if (_images.isNotEmpty) {
          _loadThumbnail(0);
          _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
            if (mounted) {
              setState(() {
                _currentIndex = (_currentIndex + 1) % _images.length;
              });
              // Pre-load next thumbnail
              final nextIndex = (_currentIndex + 1) % _images.length;
              _loadThumbnail(nextIndex);
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

  static const int _maxCachedThumbnails = 8;

  @override
  void dispose() {
    _timer?.cancel();
    _thumbnailCache.clear();
    super.dispose();
  }

  Future<Uint8List?> _loadThumbnail(int index) async {
    if (_thumbnailCache.containsKey(index)) return _thumbnailCache[index];
    if (index < 0 || index >= _images.length) return null;
    final data = await _images[index].thumbnailDataWithSize(
      const ThumbnailSize(360, 360),
    );
    if (data != null) {
      if (_thumbnailCache.length >= _maxCachedThumbnails) {
        _thumbnailCache.remove(_thumbnailCache.keys.first);
      }
      _thumbnailCache[index] = data;
    }
    return data;
  }

  void _showAlbumSelectionDialog() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo access required to select folders'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Select Folder',
            style: TextStyle(color: Colors.black),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: albums.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    albums[index].name,
                    style: const TextStyle(color: Colors.black),
                  ),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('gallery_album_id', albums[index].id);

                    if (!context.mounted) return;
                    setState(() {
                      _selectedAlbumId = albums[index].id;
                      _selectedAlbumName = albums[index].name.toUpperCase();
                      _isLoading = true;
                    });
                    _fetchImages();
                    Navigator.pop(context);
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
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.photo_library_outlined,
                                    color: Color(0xFFAAAAAA),
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _hasRequestedAccess
                                        ? 'No photos'
                                        : 'Tap to load',
                                    style: const TextStyle(
                                      color: Color(0xFF888888),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _thumbnailCache.containsKey(_currentIndex)
                        ? Image.memory(
                            _thumbnailCache[_currentIndex]!,
                            key: ValueKey<int>(_currentIndex),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            gaplessPlayback: true,
                            cacheWidth: 360,
                            cacheHeight: 360,
                            filterQuality: FilterQuality.low,
                          )
                        : FutureBuilder<Uint8List?>(
                            key: ValueKey<int>(_currentIndex),
                            future: _loadThumbnail(_currentIndex),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                      ConnectionState.done &&
                                  snapshot.data != null) {
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  gaplessPlayback: true,
                                  cacheWidth: 360,
                                  cacheHeight: 360,
                                  filterQuality: FilterQuality.low,
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
                      child: Text(
                        _images.isEmpty ? 'Gallery' : 'Photos',
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
          GestureDetector(
            onTap: _images.isEmpty ? _fetchImages : _showAlbumSelectionDialog,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.transparent, // ensure tap area is filled
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedAlbumName,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 10,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5E5E5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5E5E5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5E5E5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
