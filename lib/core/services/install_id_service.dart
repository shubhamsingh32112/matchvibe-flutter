import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

const _installIdKey = 'install_id';

/// Provides a stable install ID (one per app install) for Fast Login.
/// Stored in secure storage; generated once (UUID v4) and reused.
class InstallIdService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _uuid = Uuid();

  /// Returns the existing install ID or creates and stores a new one.
  static Future<String> getInstallId() async {
    String? id = await _storage.read(key: _installIdKey);
    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      await _storage.write(key: _installIdKey, value: id);
    }
    return id;
  }
}
