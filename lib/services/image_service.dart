import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';

class PickedFile {
  final File file;
  final String name;
  final bool isImage;

  PickedFile({
    required this.file,
    required this.name,
    required this.isImage,
  });
}

class ImageService {
  final _picker = ImagePicker();

  /// Last error message from a pick/upload. Show it in a SnackBar if needed.
  String? lastError;

  // ═══════════════════════════════════════════════
  // PICKERS
  // ═══════════════════════════════════════════════

  /// Pick an image from camera. Returns null if cancelled.
  Future<File?> pickFromCamera() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (xFile == null) return null;
      return File(xFile.path);
    } catch (e) {
      lastError = 'Camera error: $e';
      debugPrint('pickFromCamera error: $e');
      return null;
    }
  }

  /// Pick images from gallery up to [limit].
  ///
  /// NOTE: image_picker's pickMultiImage throws if limit < 2, so a limit of 1
  /// (e.g. the on-site completion photo) uses pickImage instead.
  Future<List<File>> pickFromGallery({int limit = 5}) async {
    try {
      if (limit <= 1) {
        final x = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        return x == null ? [] : [File(x.path)];
      }

      final xFiles = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
        limit: limit,
      );
      // Some platforms ignore `limit`, so enforce it here too.
      return xFiles.take(limit).map((x) => File(x.path)).toList();
    } catch (e) {
      lastError = 'Gallery error: $e';
      debugPrint('pickFromGallery error: $e');
      return [];
    }
  }

  /// Pick a single document (PDF, Word, Excel, ZIP, etc.).
  Future<PickedFile?> pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'csv',
          'txt',
          'zip',
        ],
      );
      if (result == null || result.files.isEmpty) return null;
      final path = result.files.first.path;
      if (path == null) return null;

      final file = File(path);
      final name = result.files.first.name;

      // Enforce the size limit before uploading (Storage rules also reject it).
      final maxBytes = AppConfig.maxChatFileSizeMB * 1024 * 1024;
      if (await file.length() > maxBytes) {
        lastError =
        'File is too large (max ${AppConfig.maxChatFileSizeMB} MB).';
        return null;
      }

      final isImage = ['jpg', 'jpeg', 'png', 'heic', 'webp']
          .contains(name.split('.').last.toLowerCase());

      return PickedFile(file: file, name: name, isImage: isImage);
    } catch (e) {
      lastError = 'File picker error: $e';
      debugPrint('pickDocument error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════
  // UPLOAD — images
  // ═══════════════════════════════════════════════

  Future<String?> uploadImage({
    required File file,
    required String folder,
    required String ticketId,
  }) async {
    if (!AppConfig.useFirebaseStorage) {
      return 'local://${file.path}';
    }
    return _uploadToFirebase(
      file: file,
      folder: folder,
      ticketId: ticketId,
    );
  }

  Future<List<String>> uploadImages({
    required List<File> files,
    required String folder,
    required String ticketId,
  }) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await uploadImage(
        file: file,
        folder: folder,
        ticketId: ticketId,
      );
      if (url != null) urls.add(url);
    }
    return urls;
  }

  // ═══════════════════════════════════════════════
  // UPLOAD — documents
  // ═══════════════════════════════════════════════

  Future<String?> uploadDocument({
    required File file,
    required String ticketId,
    required String originalName,
  }) async {
    if (!AppConfig.useFirebaseStorage) {
      return 'local://${file.path}';
    }
    return _uploadToFirebase(
      file: file,
      folder: 'chat_attachments',
      ticketId: ticketId,
      originalName: originalName,
    );
  }

  // ═══════════════════════════════════════════════
  // REAL FIREBASE UPLOAD
  // ═══════════════════════════════════════════════

  /// Uploads to  <folder>/<ticketId>/<timestamp>_<name>
  /// Folders used: ticket_images, completion_evidence, chat_attachments
  Future<String?> _uploadToFirebase({
    required File file,
    required String folder,
    required String ticketId,
    String? originalName,
  }) async {
    try {
      final rawName =
          originalName ?? file.path.split('/').last.split('\\').last;
      // Keep file names URL/Storage safe.
      final safeName = rawName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final ext = safeName.contains('.')
          ? safeName.split('.').last.toLowerCase()
          : '';

      final ref = FirebaseStorage.instance.ref('$folder/$ticketId/$fileName');

      // Always send a content type so the Storage rules can check it.
      final task = await ref.putFile(
        file,
        SettableMetadata(contentType: _mimeFor(ext)),
      );
      return await task.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      // unauthorized     -> Storage rules block the upload
      // bucket-not-found -> wrong bucket / Storage not set up
      // canceled / retry-limit-exceeded -> network problem
      lastError = 'Upload failed [${e.code}]';
      debugPrint('_uploadToFirebase FirebaseException: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      lastError = 'Upload failed: $e';
      debugPrint('_uploadToFirebase error: $e');
      return null;
    }
  }

  static String _mimeFor(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv':
        return 'text/csv';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      default:
      // Photos from the camera/gallery are saved as JPEG by image_picker.
        return 'image/jpeg';
    }
  }
}