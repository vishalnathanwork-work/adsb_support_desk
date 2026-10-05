import '../models/user_model.dart';

class AppConstants {
  static const String appName = 'ADSB Support Desk';
  static const String appVersion = '1.0.0';

  // Mock users for testing
  static final Map<String, UserModel> mockUsers = {
    'client@adsb.com': UserModel(
      email: 'client@adsb.com',
      name: 'Parken Client',
      role: 'client',
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

  // Mock passwords (in real app, this comes from backend)
  static const Map<String, String> mockPasswords = {
    'client@adsb.com': 'client123',
    'operator@adsb.com': 'operator123',
    'adsb@adsb.com': 'adsb123',
    'tech@adsb.com': 'tech123',
    'admin@adsb.com': 'admin123',
  };
}