class AppConfig {
  /// Set to true when Firebase Storage is enabled (Blaze plan).
  static const bool useFirebaseStorage = true;

  // Ticket form images
  static const int maxTicketImages = 2;

  // On-site completion evidence
  static const int maxCompletionImages = 3;

  // Image size limit (MB)
  static const int maxImageSizeMB = 5;

  // ─── Chat attachments ───
  static const int maxChatAttachments = 3;     // per message
  static const int maxChatFileSizeMB = 10;     // per file
}