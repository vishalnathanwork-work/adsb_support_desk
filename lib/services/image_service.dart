import 'dart:io';
import 'package:file_picker/file_picker.dart';
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

  // ─────────────────────────────────────────
  // PICK — images
  // ─────────────────────────────────────────

  Future<File?> pickFromCamera() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1280,
      );
      return picked == null ? null : File(picked.path);
    } catch (e) {
      print('pickFromCamera error: $e');
      return null;
    }
  }

  Future<List<File>> pickFromGallery({int limit = 5}) async {
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1280,
        limit: limit,
      );
      return picked.map((x) => File(x.path)).toList();
    } catch (e) {
      print('pickFromGallery error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────
  // PICK — any document
  // ─────────────────────────────────────────

  /// Pick one document (pdf, docx, xlsx, txt, zip, etc.).
  Future<PickedFile?> pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return null;

      final picked = result.files.first;
      if (picked.path == null) return null;

      final name = picked.name;
      final lower = name.toLowerCase();
      final isImage = lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.gif') ||
          lower.endsWith('.webp') ||
          lower.endsWith('.heic');

      return PickedFile(
        file: File(picked.path!),
        name: name,
        isImage: isImage,
      );
    } catch (e) {
      print('pickDocument error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────
  // UPLOAD — images
  // ─────────────────────────────────────────

  Future<String?> uploadImage({
    required File file,
    required String folder,
    required String ticketId,
  }) async {
    if (!AppConfig.useFirebaseStorage) {
      return 'local://${file.path}';
    }
    try {
      return await _uploadToFirebase(
        file: file,
        folder: folder,
        ticketId: ticketId,
      );
    } catch (e) {
      print('uploadImage error: $e');
      return null;
    }
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

  // ─────────────────────────────────────────
  // UPLOAD — documents / any file
  // ─────────────────────────────────────────

  Future<String?> uploadDocument({
    required File file,
    required String ticketId,
    required String originalName,
  }) async {
    if (!AppConfig.useFirebaseStorage) {
      return 'local://${file.path}';
    }
    try {
      return await _uploadToFirebase(
        file: file,
        folder: 'chat_attachments',
        ticketId: ticketId,
      );
    } catch (e) {
      print('uploadDocument error: $e');
      return null;
    }
  }

  /// Real Firebase Storage upload.
  Future<String?> _uploadToFirebase({
    required File file,
    required String folder,
    required String ticketId,
  }) async {
    // Replace with real Firebase Storage when ready:
    // import 'package:firebase_storage/firebase_storage.dart';
    // final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    // final ref = FirebaseStorage.instance.ref('$folder/$ticketId/$fileName');
    // final task = await ref.putFile(file);
    // return await task.ref.getDownloadURL();
    return null;
  }
}