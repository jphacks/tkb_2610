import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/core/api_client.dart';
import 'package:ichinichi_ichizen/data/api_repository.dart';
import 'package:ichinichi_ichizen/data/models.dart';
class TestSessions implements SessionStore {
  String? token; bool fail = false;
  @override Future<String?> read() async => token;
  @override Future<void> write(String? value) async { if(fail) throw Exception('keychain'); token = value; }
}
Map<String,dynamic> character() => {'id':'c1','generation':1,'imageId':'base_01','hp':100,'maxHp':100,'totalXp':0,'level':1,'evolutionStage':0,'status':'alive','createdAt':'2026-10-24T03:00:00Z'};
void main() {
  test('Guest token saving retry does not create a second guest; rename is authenticated PUT', () async {
    final sessions = TestSessions()..fail = true; final dio = Dio(); final calls = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o,h) { calls.add(o); h.resolve(Response(requestOptions:o,statusCode:201,data: o.path == '/guests' ? {'sessionToken':'test-token','user':{'displayName':'はる'},'currentCharacter':character()} : {'user':{'displayName':'なつ'}})); }));
    final repo = ApiRepository(ApiClient(baseUrl:'https://example.invalid/api',sessions:sessions,dio:dio));
    await expectLater(repo.register('はる'), throwsException);
    sessions.fail = false;
    expect((await repo.register('はる')).name,'はる'); expect(calls.length,1);
    expect(calls.first.uri.toString(), 'https://example.invalid/api/guests');
    expect((await repo.rename('なつ')).name,'なつ'); expect(calls.last.method,'PUT'); expect(calls.last.headers['Authorization'],'Bearer test-token');
    expect(calls.last.data,{'displayName':'なつ'});
  });
  test('API base URL without /api is rejected before making a request', () {
    expect(
      () => ApiClient(baseUrl:'http://127.0.0.1:3000',sessions:TestSessions()),
      throwsA(isA<GameException>()),
    );
  });
  test('generic NOT_FOUND explains the required API prefix', () async {
    final sessions = TestSessions()..token = 'test-token';
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(
        DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 404,
            data: {'error': {'code': 'NOT_FOUND'}},
          ),
          type: DioExceptionType.badResponse,
        ),
      ),
    ));
    final client = ApiClient(
      baseUrl: 'http://127.0.0.1:3000/api',
      sessions: sessions,
      dio: dio,
    );

    await expectLater(
      client.request('GET', '/users/me'),
      throwsA(
        isA<GameException>().having((error) => error.message, 'message', contains('/api')),
      ),
    );
  });
  test('Posting sends only content and stable requestId, uses actual server rewards', () async {
    final sessions = TestSessions(); final dio = Dio(); final calls = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest:(o,h) { calls.add(o); h.resolve(Response(requestOptions:o,statusCode:201,data:o.path == '/guests' ? {'sessionToken':'test','user':{'displayName':'はる'},'currentCharacter':character()} : {'currentCharacter':{...character(),'totalXp':10},'deed':{'id':'d','characterId':'c1','content':'ありがとう','category':'gratitude','praise':'すてきだね','earnedXp':10,'earnedCategoryPoints':1,'recoveredHp':0,'createdAt':'2026-10-24T03:01:00Z'},'evolution':{'changed':false}})); }));
    final repo = ApiRepository(ApiClient(baseUrl:'https://example.invalid/api',sessions:sessions,dio:dio)); await repo.register('はる');
    final first = await repo.postDeed('ありがとう','stable'); final second = await repo.postDeed('ありがとう','stable');
    expect(calls.last.data,{'content':'ありがとう','requestId':'stable'}); expect(first.deed.hp,0); expect(second.snapshot.todayCount,1); expect(second.snapshot.deeds.length,1);
  });
  test('401 does not silently clear guest credentials', () async {
    final sessions = TestSessions()..token='keep'; final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest:(o,h) => h.reject(DioException(requestOptions:o,response:Response(requestOptions:o,statusCode:401,data:{'error':{'code':'UNAUTHENTICATED'}}),type:DioExceptionType.badResponse))));
    final client = ApiClient(baseUrl:'https://example.invalid/api',sessions:sessions,dio:dio);
    await expectLater(client.request('GET','/users/me'), throwsA(isA<GameException>())); expect(sessions.token,'keep');
  });
}
