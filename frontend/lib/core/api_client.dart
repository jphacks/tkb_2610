import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/models.dart';

abstract interface class SessionStore {
  Future<String?> read();
  Future<void> write(String? token);
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore(String baseUrl) : key = 'yoinoko.session.$baseUrl';
  final String key;
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String? token) => token == null
      ? storage.delete(key: key)
      : storage.write(key: key, value: token);
}

class ApiClient {
  ApiClient({required String baseUrl, required this.sessions, Dio? dio})
    : dio = dio ?? Dio() {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const GameException('API接続先が設定されていません。管理者にお問い合わせください。');
    }
    this.dio.options = BaseOptions(
      baseUrl: baseUrl.replaceFirst(RegExp(r'/+$'), ''),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      followRedirects: false,
    );
  }
  final Dio dio;
  final SessionStore sessions;
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) async {
    final token = authenticated ? await sessions.read() : null;
    if (authenticated && token == null) {
      throw const GameException('ログイン情報が見つかりません。アプリを再起動してください。');
    }
    try {
      final response = await dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: token == null ? null : {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 204) return {};
      if (response.data is! Map) {
        throw const GameException('サーバーからの応答を読み取れませんでした。');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      final data = e.response?.data;
      final error = data is Map && data['error'] is Map
          ? data['error'] as Map
          : const {};
      final code = error['code'];
      final message = switch (code) {
        'UNAUTHENTICATED' =>
          'ログインの有効期限が切れたか、認証できませんでした。データ保護のため、自動で新規登録は行いません。',
        'DEED_NOT_VALID' => '善行として受け付けられませんでした。内容を見直してみてください。',
        'AI_UNAVAILABLE' => '今はお返事を準備できません。同じ内容で、少し待って再送してください。',
        'REQUEST_IN_PROGRESS' => 'まだ送信した善行を確認しています。少し待って、もう一度送ってください。',
        'IDEMPOTENCY_CONFLICT' => '送信内容が一致しません。画面を閉じて、もう一度入力してください。',
        'CHARACTER_NOT_ACTIVE' => 'この子は育成を終えています。ホームを再読み込みしてください。',
        'GENERATION_NOT_AVAILABLE' => '新しい子を迎えられる時間まで、もう少し待ってください。',
        'ACTIVE_CHARACTER_EXISTS' => '新しい子はすでに迎えられています。ホームを再読み込みしてください。',
        'VALIDATION_ERROR' => '入力内容を確認してください。',
        _ =>
          e.response?.statusCode == 404
              ? 'この機能はまだサーバーで準備中です。時間をおいてお試しください。'
              : '通信できませんでした。接続を確認して、もう一度お試しください。',
      };
      throw GameException(message);
    }
  }

  void dispose() => dio.close();
}
