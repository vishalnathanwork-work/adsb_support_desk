import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';

/// Picks and (optionally) uploads images.
///
/// When [AppConfig.useFirebaseStorage] is false:
///   - [uploadImage] returns the local file path (prefixed with "local://")
///   - Nothing is uploaded to Firebase
///
/// When true:
///   - Uploads to Firebase Storage
///   - Returns the download URL
class ImageService {
  final _picker = ImagePicker();

  // ─────────────────────────────────────────
  // PICK
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
  // UPLOAD (or stub)
  // ─────────────────────────────────────────

  /// Uploads [file] and returns the URL that should be stored in Firestore.
  /// - If Firebase Storage is enabled: returns the download URL.
  /// - Otherwise: returns a `local://<path>` string so the app can display
  ///   it locally during dev.
  Future<String?> uploadImage({
    required File file,
    required String folder,      // 'ticket_images' or 'completion_evidence'
    required String ticketId,
  }) async {
    if (!AppConfig.useFirebaseStorage) {
      // Not uploading yet. Just remember the local path.
      return 'local://${file.path}';
    }

    try {
      // Lazy import — Firebase Storage only loaded when flag is on.
      // This keeps the app working even if the package isn't in pubspec yet.
      // See "Part 3" for how to enable the real upload.
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

  /// Real Firebase Storage upload — only called when the flag is true.
  /// Kept isolated so it's easy to add the package later.
  Future<String?> _uploadToFirebase({
    required File file,
    required String folder,
    required String ticketId,
  }) async {
    // Firebase Storage code — see Part 3 for the exact implementation.
    // For now this returns null; app is running in local mode.
    return null;
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

/// When you switch to Firebase Storage, replace [_uploadToFirebase] with:
///
/// ```dart
/// import 'package:firebase_storage/firebase_storage.dart';
///
/// Future<String?> _uploadToFirebase({...}) async {
///   final fileName =
///       '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
///   final ref = FirebaseStorage.instance.ref('$folder/$ticketId/$fileName');
///   final task = await ref.putFile(file);
///   return await task.ref.getDownloadURL();
/// }
/// ```
}