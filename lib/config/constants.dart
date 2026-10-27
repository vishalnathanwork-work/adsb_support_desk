import '../models/user_model.dart';

class AppConstants {
  static const String appName = 'Parken Assist';
  static const String appVersion = '1.0.0';

  // ═══════════════════════════════════════════════
  // ADMIN CONTACT
  // ═══════════════════════════════════════════════

  /// Admin WhatsApp number — international format WITHOUT + or spaces.
  /// Example: Malaysia number +60 12-345 6789 → "60123456789"
  /// ⚠️ REPLACE THIS with the real admin WhatsApp number.
  static const String adminWhatsAppNumber = '60123456789';

  /// Pre-filled message when user taps "Chat with admin".
  static const String adminWhatsAppMessage =
      'Hi ADSB Admin, I forgot my password for the Parken Assist app. '
      'Please help me reset it. My username is: ';

  // ═══════════════════════════════════════════════
  // MOCK USERS (for testing only — remove in production)
  // ═══════════════════════════════════════════════

  static final Map<String, UserModel> mockUsers = {
    'owner@adsb.com': UserModel(
      email: 'owner@adsb.com',
      name: 'Parken Client',
      role: 'owner',
      phone: '+60 12-345 6789',
      company: 'Parken Sdn Bhd',
    ),
    'operator@adsb.com': UserModel(
      email: 'operator@adsb.com',
      name: 'Parken Operator',
      role: 'operator',
      phone: '+60 12-345 6790',
      company: 'Parken Sdn Bhd',
    ),
    'adsb@adsb.com': UserModel(
      email: 'adsb@adsb.com',
      name: 'ADSB Support Agent',
      role: 'adsb',
      phone: '+60 12-345 6791',
      company: 'Access Digital Sdn Bhd',
    ),
    'tech@adsb.com': UserModel(
      email: 'tech@adsb.com',
      name: 'TT Advisor',
      role: 'technician',
      phone: '+60 12-345 6792',
      company: 'Access Digital Sdn Bhd',
    ),
    'admin@adsb.com': UserModel(
      email: 'admin@adsb.com',
      name: 'ADSB Admin',
      role: 'admin',
      phone: '+60 12-345 6793',
      company: 'Access Digital Sdn Bhd',
    ),
  };

  static const Map<String, String> mockPasswords = {
    'owner@adsb.com': 'client123',
    'operator@adsb.com': 'operator123',
    'adsb@adsb.com': 'adsb123',
    'tech@adsb.com': 'tech123',
    'admin@adsb.com': 'admin123',
  };
}