import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    required this.model,
    required this.apiKey,
  });

  final String baseUrl;
  final String model;
  final String apiKey;

  String get maskedKey {
    if (apiKey.length <= 4) return '••••';
    return '••••${apiKey.substring(apiKey.length - 4)}';
  }
}

class SecureApiConfigStore {
  SecureApiConfigStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _baseUrlKey = 'api_base_url';
  static const _modelKey = 'api_model';
  static const _apiKeyKey = 'api_secret';
  final FlutterSecureStorage _storage;

  Future<ApiConfig?> read() async {
    final baseUrl = await _storage.read(key: _baseUrlKey);
    final model = await _storage.read(key: _modelKey);
    final apiKey = await _storage.read(key: _apiKeyKey);
    if (baseUrl == null ||
        baseUrl.isEmpty ||
        model == null ||
        model.isEmpty ||
        apiKey == null ||
        apiKey.isEmpty) {
      return null;
    }
    return ApiConfig(
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
    );
  }

  Future<void> save(ApiConfig config) async {
    final uri = Uri.tryParse(config.baseUrl);
    if (uri == null || (!uri.hasScheme || !uri.hasAuthority)) {
      throw const FormatException('API 地址无效');
    }
    final parsedHost = InternetAddress.tryParse(uri.host);
    final isLoopback =
        uri.host == 'localhost' || parsedHost?.isLoopback == true;
    if (uri.scheme != 'https' && !isLoopback) {
      throw const FormatException('仅允许 HTTPS；本机回环地址可用于调试');
    }
    if (config.model.trim().isEmpty || config.apiKey.trim().isEmpty) {
      throw const FormatException('模型名和 API Key 不能为空');
    }
    await Future.wait([
      _storage.write(key: _baseUrlKey, value: config.baseUrl.trim()),
      _storage.write(key: _modelKey, value: config.model.trim()),
      _storage.write(key: _apiKeyKey, value: config.apiKey.trim()),
    ]);
  }

  Future<void> clear() => _storage.deleteAll();
}
