import 'dart:io';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'full_screen_image_viewer.dart';

/// Renders a row of image thumbnails. Tap any thumbnail to open the
/// full-screen viewer at that image's index.
class ImageGallery extends StatelessWidget {
  final List<String> urls;
  final double thumbSize;
  final String? title;

  const ImageGallery({
    super.key,
    required this.urls,
    this.thumbSize = 80,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: urls.asMap().entries.map((entry) {
        final index = entry.key;
        final url = entry.value;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullScreenImageViewer(
                  urls: urls,
                  initialIndex: index,
                  title: title,
                ),
              ),
            );
          },
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _thumbnail(url),
              ),
              // Small "expand" icon overlay
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.zoom_out_map,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _thumbnail(String url) {
    if (url.startsWith('local://')) {
      return Image.file(
        File(url.replaceFirst('local://', '')),
        width: thumbSize,
        height: thumbSize,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _broken(),
      );
    }
    return Image.network(
      url,
      width: thumbSize,
      height: thumbSize,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _broken(),
    );
  }

  Widget _broken() {
    return Container(
      width: thumbSize,
      height: thumbSize,
      color: AppColors.divider,
      child: const Icon(
        Icons.broken_image_outlined,
        color: AppColors.textSecondary,
      ),
    );
  }
}