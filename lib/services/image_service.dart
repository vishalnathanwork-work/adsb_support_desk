import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
      print('pickFromCamera error: $e');
      return null;
    }
  }

  /// Pick multiple images from gallery up to [limit].
  Future<List<File>> pickFromGallery({int limit = 5}) async {
    try {
      final xFiles = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
        limit: limit,
      );
      return xFiles.map((x) => File(x.path)).toList();
    } catch (e) {
      print('pickFromGallery error: $e');
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
      final isImage = ['jpg', 'jpeg', 'png', 'heic', 'webp']
          .contains(name.split('.').last.toLowerCase());

      return PickedFile(
        file: file,
        name: name,
        isImage: isImage,
      );
    } catch (e) {
      print('pickDocument error: $e');
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

  // ═══════════════════════════════════════════════
  // REAL FIREBASE UPLOAD
  // ═══════════════════════════════════════════════

  Future<String?> _uploadToFirebase({
    required File file,
    required String folder,
    required String ticketId,
  }) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last.split('\\').last}';
      final ref = FirebaseStorage.instance
          .ref('$folder/$ticketId/$fileName');
      final task = await ref.putFile(file);
      return await task.ref.getDownloadURL();
    } catch (e) {
      print('_uploadToFirebase error: $e');
      return null;
    }
  }
}
