import 'dart:io';

import 'package:flutter/foundation.dart';

/// Live Sir API on the Adikern Hostinger account.
/// Android emulator reaches this Mac through 10.0.2.2 when [useLiveApi] is false.
class ApiConfig {
  static const bool useLiveApi = true;
  static const String liveHost = 'https://adikern.com/sir';

  static String get baseUrl => '$assetBaseUrl/api';

  static const tokenKey = 'auth_token';

  static String get assetBaseUrl {
    if (useLiveApi) return liveHost;
    if (kIsWeb) return 'http://127.0.0.1:8001';
    if (Platform.isAndroid) return 'http://10.0.2.2:8001';
    return 'http://127.0.0.1:8001';
  }

  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final clean = path.startsWith('/') ? path : '/storage/$path';
    return '$assetBaseUrl$clean'.replaceAll('/storage/storage/', '/storage/');
  }
}
