class MockApiService {
  // Ticket, notification, and other mock APIs will be added in Sprint 3+
  // For now, this is a placeholder so imports work everywhere.

  Future<void> noop() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}