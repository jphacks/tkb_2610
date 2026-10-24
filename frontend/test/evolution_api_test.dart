import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/core/api_client.dart';
import 'package:ichinichi_ichizen/data/api_repository.dart';
import 'api_repository_test.dart' show TestSessions, character;

void main() {
  for (final failProgress in [false, true]) {
    test('進化後の進捗取得${failProgress ? '失敗でも投稿成功を保持' : 'で次の条件を表示'}', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            if (o.path == '/characters/me/evolution') {
              if (failProgress) {
                h.reject(
                  DioException(
                    requestOptions: o,
                    type: DioExceptionType.connectionError,
                  ),
                );
              } else {
                h.resolve(
                  Response(
                    requestOptions: o,
                    statusCode: 200,
                    data: {'nextEvolutionXp': 300},
                  ),
                );
              }
              return;
            }
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 201,
                data: o.path == '/guests'
                    ? {
                        'sessionToken': 'test',
                        'user': {'displayName': 'はる'},
                        'currentCharacter': character(),
                      }
                    : {
                        'currentCharacter': {
                          ...character(),
                          'imageId': 'stage1_environment',
                          'evolutionStage': 1,
                          'totalXp': 100,
                        },
                        'deed': {
                          'id': 'd',
                          'characterId': 'c1',
                          'content': 'ごみを拾った',
                          'category': 'environment',
                          'praise': 'ありがとう',
                          'earnedXp': 10,
                          'earnedCategoryPoints': 1,
                          'recoveredHp': 0,
                          'createdAt': '2026-10-24T03:00:00Z',
                        },
                        'evolution': {'changed': true},
                      },
              ),
            );
          },
        ),
      );
      final repo = ApiRepository(
        ApiClient(
          baseUrl: 'https://example.invalid/api',
          sessions: TestSessions(),
          dio: dio,
        ),
      );
      await repo.register('はる');
      final result = await repo.postDeed('ごみを拾った', 'stable');
      expect(result.evolved, isTrue);
      expect(result.snapshot.current.form.label, '草・シカ');
      expect(
        result.snapshot.current.nextEvolutionXp,
        failProgress ? null : 300,
      );
      expect(result.snapshot.deeds.length, 1);
    });
  }
}
