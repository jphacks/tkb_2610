import 'package:flutter/foundation.dart';
import '../data/models.dart';

class AppConfig {
  static const baseUrl = String.fromEnvironment('API_BASE_URL');
  static const mode = String.fromEnvironment('APP_MODE');
  static bool get isDemo =>
      mode == 'demo' || (mode.isEmpty && baseUrl.isEmpty && !kReleaseMode);
  static void validate() {
    if (mode.isNotEmpty && mode != 'demo' && mode != 'api') {
      throw const GameException('起動設定を確認してください。');
    }
    if (!isDemo && baseUrl.isEmpty) {
      throw const GameException('接続先が未設定です。API_BASE_URLを設定して起動してください。');
    }
    if (!isDemo && kReleaseMode && !baseUrl.startsWith('https://')) {
      throw const GameException('本番環境ではHTTPSの接続先が必要です。');
    }
  }
}
