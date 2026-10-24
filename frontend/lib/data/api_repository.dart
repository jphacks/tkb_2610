import '../core/api_client.dart';
import 'api_mapper.dart';
import 'models.dart';
import 'repository.dart';

/// API v2 adapter. Endpoints marked provisional in the supplied spec require backend integration testing.
class ApiRepository implements GameRepository {
  ApiRepository(this.client);
  final ApiClient client;
  GameSnapshot? _data;
  Map<String, dynamic>? _pendingRegistration;
  bool _deletedOnServer = false;
  GameSnapshot get data =>
      _data ?? (throw const GameException('プレイヤー情報を読み込んでください。'));
  GameSnapshot _replace(
    Companion c, {
    String? name,
    Deed? deed,
    int? todayCount,
  }) {
    final chars = {
      ...?_data?.characters.map((c) => MapEntry(c.id, c)).toMap(),
      c.id: c,
    };
    final ordered = chars.values.toList()
      ..sort((a, b) => a.generation.compareTo(b.generation));
    final deeds = {for (final d in _data?.deeds ?? <Deed>[]) d.id: d};
    if (deed != null) {
      deeds[deed.id] = deed;
    }
    return _data = GameSnapshot(
      name: name ?? data.name,
      characters: ordered,
      deeds: deeds.values.toList(),
      todayCount: todayCount ?? _data?.todayCount,
    );
  }

  @override
  Future<GameSnapshot?> load() async {
    if (await client.sessions.read() == null) return null;
    final user = await client.request('GET', '/users/me');
    final current = await client.request('GET', '/characters/me');
    final evolution = await client.request('GET', '/characters/me/evolution');
    final c = companionFromApi(
      object(current['currentCharacter']),
      evolution: evolution,
      canCreateNext: current['canCreateNextCharacter'] as bool?,
      nextAvailableAt: jstMidnight(current['nextCharacterAvailableOn']),
    );
    return _replace(
      c,
      name: object(user['user'])['displayName'] as String,
      todayCount: object(current['today'])['deedCount'] as int,
    );
  }

  @override
  Future<GameSnapshot> register(String name) async {
    // If keychain saving fails, retry storing the SAME issued token; don't create a second guest.
    _pendingRegistration ??= await client.request(
      'POST',
      '/guests',
      body: {'displayName': name},
      authenticated: false,
    );
    final response = _pendingRegistration!;
    final token = response['sessionToken'];
    if (token is! String || token.isEmpty) {
      throw const GameException('登録情報を受け取れませんでした。');
    }
    await client.sessions.write(token);
    final result = _replace(
      companionFromApi(object(response['currentCharacter'])),
      name: object(response['user'])['displayName'],
      todayCount: 0,
    );
    _pendingRegistration = null;
    return result;
  }

  @override
  Future<GameSnapshot> rename(String name) async {
    final response = await client.request(
      'PUT',
      '/users/me',
      body: {'displayName': name},
    );
    return _replace(
      data.current,
      name: object(response['user'])['displayName'],
    );
  }

  @override
  Future<DeedResult> postDeed(String text, String requestId) async {
    final response = await client.request(
      'POST',
      '/deeds',
      body: {'content': text, 'requestId': requestId},
    );
    final deed = deedFromApi(object(response['deed']));
    final alreadyKnown = data.deeds.any((d) => d.id == deed.id);
    final c = companionFromApi(object(response['currentCharacter']));
    final snapshot = _replace(
      c,
      deed: deed,
      todayCount: (data.todayCount ?? 0) + (alreadyKnown ? 0 : 1),
    );
    return DeedResult(
      snapshot,
      deed,
      evolved: object(response['evolution'])['changed'] == true,
    );
  }

  @override
  Future<GameSnapshot> welcomeNext() async {
    final response = await client.request('POST', '/characters');
    return _replace(companionFromApi(object(response['currentCharacter'])));
  }

  @override
  Future<void> deleteAccount() async {
    if (!_deletedOnServer) {
      await client.request('DELETE', '/users/me');
      _deletedOnServer = true;
    }
    await client.sessions.write(null);
    _data = null;
    _pendingRegistration = null;
    _deletedOnServer = false;
  }

  @override
  Future<PageResult<Companion>> history({int offset = 0}) async {
    final response = await client.request(
      'GET',
      '/characters/history',
      query: {'limit': 20, 'offset': offset},
    );
    return pageFromApi(response, companionFromApi);
  }

  @override
  Future<PageResult<Deed>> deedsFor(
    String characterId, {
    int offset = 0,
  }) async {
    final response = await client.request(
      'GET',
      '/deeds',
      query: {'characterId': characterId, 'limit': 20, 'offset': offset},
    );
    return pageFromApi(response, deedFromApi);
  }
}

extension _EntriesToMap<K, V> on Iterable<MapEntry<K, V>> {
  Map<K, V> toMap() => Map.fromEntries(this);
}
