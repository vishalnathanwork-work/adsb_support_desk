import 'dart:io';
import 'package:flutter/material.dart';

/// Full-screen image viewer with pinch-to-zoom, pan, and swipe navigation.
///
/// Pass the list of images and the index to show first.
/// Local `local://` paths are handled automatically.
class FullScreenImageViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  final String? title;

  const FullScreenImageViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    this.title,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          widget.title ??
              (_currentIndex + 1).toString() +
                  ' / ' +
                  widget.urls.length.toString(),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          // Close
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Images
          PageView.builder(
            controller: _pageController,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, i) => _buildZoomableImage(widget.urls[i]),
          ),

          // Position indicator dots
          if (widget.urls.length > 1)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.urls.length, (i) {
                  final active = i == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildZoomableImage(String url) {
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 5.0,
      child: Center(
        child: url.startsWith('local://')
            ? Image.file(
          File(url.replaceFirst('local://', '')),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _errorWidget(),
        )
            : Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          },
          errorBuilder: (_, __, ___) => _errorWidget(),
        ),
      ),
    );
  }

  Widget _errorWidget() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined,
              color: Colors.white54, size: 64),
          SizedBox(height: 12),
          Text(
            'Image not available',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}