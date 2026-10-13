import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import 'image_gallery.dart';

class ChatAttachmentView extends StatelessWidget {
  final List<String> imageUrls;
  final List<String> attachmentUrls;
  final List<String> attachmentNames;

  const ChatAttachmentView({
    super.key,
    this.imageUrls = const [],
    this.attachmentUrls = const [],
    this.attachmentNames = const [],
  });

  bool get _hasImages => imageUrls.isNotEmpty;
  bool get _hasAttachments => attachmentUrls.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasImages && !_hasAttachments) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasImages)
          ImageGallery(
            urls: imageUrls,
            thumbSize: 100,
            title: 'Attached Photos',
          ),
        if (_hasImages && _hasAttachments) const SizedBox(height: 8),
        if (_hasAttachments)
          ...attachmentUrls.asMap().entries.map((entry) {
            final index = entry.key;
            final url = entry.value;
            final name = index < attachmentNames.length
                ? attachmentNames[index]
                : _nameFromUrl(url);
            return _attachmentRow(context, url, name);
          }),
      ],
    );
  }

  Widget _attachmentRow(BuildContext context, String url, String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _openAttachment(context, url, name),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _iconForFile(name),
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLocalFile(url) ? 'Local preview' : 'Tap to open',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new,
                  size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  bool _isLocalFile(String url) => url.startsWith('local://');

  // ═══════════════════════════════════════════════
  // OPEN ATTACHMENT
  // ═══════════════════════════════════════════════

  Future<void> _openAttachment(
      BuildContext context,
      String url,
      String name,
      ) async {
    // ─── Local file ───
    if (url.startsWith('local://')) {
      final path = url.replaceFirst('local://', '');
      final file = File(path);

      if (!file.existsSync()) {
        _snack(context,
            'This file was uploaded on another device or has been cleared. '
                'It will be available once cloud storage is enabled.');
        return;
      }

      try {
        final result = await OpenFilex.open(path);
        if (result.type != ResultType.done) {
          _snack(context, 'Could not open the file. ${result.message}');
        }
      } catch (e) {
        _snack(context, 'Error opening file: $e');
      }
      return;
    }

    // ─── Remote URL ───
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _snack(context, 'Cannot open $name');
      }
    } catch (e) {
      _snack(context, 'Error opening file: $e');
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════

  static String _nameFromUrl(String url) {
    if (url.startsWith('local://')) {
      final path = url.replaceFirst('local://', '');
      return path.split('/').last;
    }
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.last;
      return Uri.decodeComponent(last);
    } catch (_) {
      return url;
    }
  }

  static IconData _iconForFile(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description;
    }
    if (lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.csv')) {
      return Icons.table_chart;
    }
    if (lower.endsWith('.zip') || lower.endsWith('.rar')) {
      return Icons.folder_zip;
    }
    if (lower.endsWith('.txt')) return Icons.text_snippet;
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi')) {
      return Icons.videocam;
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.m4a')) {
      return Icons.audiotrack;
    }
    return Icons.insert_drive_file;
  }
}