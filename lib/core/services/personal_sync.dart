import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_session.dart';

class SyncVersion {
  const SyncVersion(this.revision, this.snapshot);
  SyncVersion.fromJson(Map<String, dynamic> json)
    : this(json['revision'] as int, json['snapshot'] as String?);

  final int revision;
  final String? snapshot;
  Map<String, dynamic> toJson() => {'revision': revision, 'snapshot': snapshot};
}

class _Collection {
  const _Collection({
    this.local,
    this.base = const SyncVersion(0, null),
    this.remote,
    this.savedVersions = const [],
  });

  _Collection.fromJson(Map<String, dynamic> json)
    : local = json['local'] as String?,
      base = SyncVersion.fromJson(json['base'] as Map<String, dynamic>),
      remote = json['remote'] == null
          ? null
          : SyncVersion.fromJson(json['remote'] as Map<String, dynamic>),
      savedVersions = (json['savedVersions'] as List).cast<String>();

  final String? local;
  final SyncVersion base;
  final SyncVersion? remote;
  final List<String> savedVersions;
  bool get pending => local != base.snapshot;
  bool get conflict => pending && remote != null;

  Map<String, dynamic> toJson() => {
    'local': local,
    'base': base.toJson(),
    'remote': remote?.toJson(),
    'savedVersions': savedVersions,
  };
}

/// Stores the visible snapshot and its upload baseline together. A stopped
/// process can always reconstruct the queue without a separate dirty flag.
class PersonalSync extends ChangeNotifier {
  PersonalSync(this.session, this.disk) : accountId = session.account!.id;

  final AppSession session;
  final SharedPreferencesAsync disk;
  final String accountId;
  final _collections = <String, _Collection>{};
  Future<void> _serial = Future.value();
  Future<void>? _inFlight;
  Timer? _timer;
  Timer? _debounce;
  bool _disposed = false;
  bool _loaded = false;
  bool _opening = true;
  bool offline = false;
  bool synced = false;
  String? error;
  bool get syncing => _inFlight != null;
  bool get pending => _collections.values.any((entry) => entry.pending);

  static const labels = {
    'tasks': 'Tasks',
    'planning': 'Calendar and day plans',
    'focus': 'Focus and reminders',
    'check-ins': 'Daily check-ins',
  };

  Map<String, bool> get updates => {
    for (final entry in _collections.entries)
      if (entry.value.remote != null) entry.key: entry.value.conflict,
  };

  List<String> versions(String collection) => List.unmodifiable(
    _collections[collection]?.savedVersions ?? const <String>[],
  );

  String _key(String collection) =>
      'planify.personal-sync.v1.${session.baseUrl}.$accountId.$collection';

  Map<String, String> get _legacyKeys => {
    'tasks': 'planify.tasks.v1.$accountId',
    'planning': 'planify.planning.v1.$accountId',
    'focus': 'planify.oumayma.v1.$accountId',
  };

  String get _checkInPrefix => 'planify.mood.$accountId.';

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _serial.then((_) => action());
    _serial = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _persist(String key, _Collection state) async {
    await disk.setString(_key(key), jsonEncode(state.toJson()));
    _collections[key] = state;
  }

  Future<void> open() async {
    await _locked(() async {
      if (_loaded) return;
      for (final collection in labels.keys) {
        final state = await disk.getString(_key(collection));
        if (state != null) {
          _collections[collection] = _Collection.fromJson(jsonDecode(state));
          continue;
        }
        String? snapshot;
        if (collection == 'check-ins') {
          final moods = <String, String>{};
          for (final key in await disk.getKeys()) {
            if (!key.startsWith(_checkInPrefix)) continue;
            final mood = await disk.getString(key);
            if (mood != null) {
              moods[key.substring(_checkInPrefix.length)] = mood;
            }
          }
          if (moods.isNotEmpty) snapshot = jsonEncode(moods);
        } else {
          snapshot = await disk.getString(_legacyKeys[collection]!);
        }
        await _persist(collection, _Collection(local: snapshot));
      }
      _loaded = true;
    });
    if (_disposed) return;
    _timer ??= Timer.periodic(const Duration(seconds: 15), (_) => sync());
    await sync().timeout(const Duration(seconds: 2), onTimeout: () {});
    await _locked(() async {
      _opening = false;
    });
  }

  String? _collectionFor(String key) {
    if (key.startsWith(_checkInPrefix)) return 'check-ins';
    for (final entry in _legacyKeys.entries) {
      if (entry.value == key) return entry.key;
    }
    return null;
  }

  Future<String?> read(String key) => _locked(() async {
    final collection = _collectionFor(key);
    if (collection == null) throw ArgumentError.value(key, 'storage key');
    final snapshot = _collections[collection]!.local;
    if (snapshot == null || collection != 'check-ins') return snapshot;
    return (jsonDecode(snapshot) as Map)[key.substring(_checkInPrefix.length)]
        as String?;
  });

  Future<void> write(String key, String value) async {
    await _locked(() async {
      final collection = _collectionFor(key);
      if (collection == null) throw ArgumentError.value(key, 'storage key');
      final current = _collections[collection]!;
      final snapshot = collection == 'check-ins'
          ? jsonEncode({
              if (current.local != null) ...jsonDecode(current.local!) as Map,
              key.substring(_checkInPrefix.length): value,
            })
          : value;
      if (current.local == snapshot) return;
      await _persist(
        collection,
        _Collection(
          local: snapshot,
          base: current.base,
          remote: current.remote,
          savedVersions: current.savedVersions,
        ),
      );
    });
    _changed();
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => sync());
  }

  Future<void> sync() {
    if (_disposed || !_loaded || session.account?.id != accountId) {
      return Future.value();
    }
    if (_inFlight != null) return _inFlight!;
    final result = _synchronize().whenComplete(() {
      _inFlight = null;
      _changed();
    });
    _inFlight = result;
    _changed();
    return result;
  }

  Future<void> _synchronize() async {
    try {
      final result = await session.request('GET', '/users/me/sync');
      if (_disposed || session.account?.id != accountId) return;
      final remote = result['collections'] as Map<String, dynamic>;
      for (final collection in labels.keys) {
        final version = remote[collection] == null
            ? const SyncVersion(0, null)
            : SyncVersion.fromJson(remote[collection] as Map<String, dynamic>);
        final upload = await _locked(() async {
          final state = _collections[collection]!;
          if (version.revision < state.base.revision) {
            throw const ApiFailure(
              'Server data is older than this device’s last sync.',
              status: 409,
            );
          }
          await _observe(collection, state, version);
          final updated = _collections[collection]!;
          return updated.pending && updated.remote == null ? updated : null;
        });
        if (upload == null || _disposed || session.account?.id != accountId) {
          continue;
        }
        final response = await session.request(
          'POST',
          '/users/me/sync/$collection',
          {'revision': upload.base.revision, 'snapshot': upload.local},
        );
        final observed = SyncVersion.fromJson(response);
        await _locked(() async {
          final current = _collections[collection]!;
          if (response['applied'] == true) {
            // A local edit may have arrived while the upload was in flight.
            await _persist(
              collection,
              _Collection(
                local: current.local,
                base: observed,
                savedVersions: current.savedVersions,
              ),
            );
          } else {
            await _observe(collection, current, observed);
          }
        });
      }
      await session.refreshAccount();
      offline = false;
      error = null;
      synced = true;
    } on ApiFailure catch (failure) {
      offline = failure.status == 0;
      error = offline ? null : failure.message;
    } catch (_) {
      offline = false;
      error = 'Could not synchronize personal data. Try again.';
    }
  }

  Future<void> _observe(
    String key,
    _Collection state,
    SyncVersion version,
  ) async {
    if ((state.remote?.revision == version.revision &&
            !(_opening && !state.pending)) ||
        (state.base.revision == version.revision && state.remote == null)) {
      return;
    }
    if (state.local == version.snapshot || (_opening && !state.pending)) {
      await _persist(
        key,
        _Collection(
          local: version.snapshot,
          base: version,
          savedVersions: state.savedVersions,
        ),
      );
    } else {
      await _persist(
        key,
        _Collection(
          local: state.local,
          base: state.base,
          remote: version,
          savedVersions: state.savedVersions,
        ),
      );
    }
  }

  Map<String, dynamic> preview(String collection) {
    final state = _collections[collection]!;
    Map<String, dynamic> records(String? raw) {
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return {for (final row in decoded) (row as Map)['id'].toString(): row};
      }
      return Map<String, dynamic>.from(decoded as Map);
    }

    final local = records(state.local),
        remote = records(state.remote?.snapshot);
    final added = local.keys.where((id) => !remote.containsKey(id)).toList();
    final removed = remote.keys.where((id) => !local.containsKey(id)).toList();
    final changed = local.keys
        .where(
          (id) =>
              remote.containsKey(id) && !mapEqualsDeep(local[id], remote[id]),
        )
        .toList();
    return {
      'collection': collection,
      'base_revision': state.base.revision,
      'remote_revision': state.remote?.revision ?? state.base.revision,
      'counts': {
        'added': added.length,
        'removed': removed.length,
        'changed': changed.length,
      },
      'details': [
        for (final id in {...added, ...removed, ...changed})
          {'id': id, 'device': local[id], 'server': remote[id]},
      ],
      'fingerprint': jsonEncode({
        'local': state.local,
        'base': state.base.toJson(),
        'remote': state.remote?.toJson(),
      }),
    };
  }

  bool mapEqualsDeep(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

  Future<void> resolve(
    String collection, {
    required bool keepLocal,
    String? expectedPreview,
  }) async {
    if (expectedPreview != null) {
      await sync();
      if (offline || error != null || session.account?.id != accountId) {
        throw const ApiFailure(
          'Reconnect and refresh the preview before resolving. Your edits are preserved.',
        );
      }
    }
    await _inFlight;
    await _locked(() async {
      if (expectedPreview != null &&
          preview(collection)['fingerprint'] != expectedPreview) {
        throw const ApiFailure(
          'The local or server version changed. Review a fresh preview.',
          status: 409,
        );
      }
      final current = _collections[collection]!;
      final remote = current.remote;
      if (remote == null) return;
      final dismissed = keepLocal ? remote.snapshot : current.local;
      await _persist(
        collection,
        _Collection(
          local: keepLocal ? current.local : remote.snapshot,
          base: remote,
          savedVersions: [
            ...current.savedVersions,
            if (current.conflict &&
                dismissed != null &&
                !current.savedVersions.contains(dismissed))
              dismissed,
          ],
        ),
      );
    });
    _changed();
    if (keepLocal) await sync();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}

/// Keeps existing feature store APIs and standalone storage behavior intact.
class SyncedPreferences extends SharedPreferencesAsync {
  SyncedPreferences(this.sync);
  final PersonalSync sync;

  @override
  Future<String?> getString(String key) => sync.read(key);

  @override
  Future<void> setString(String key, String value) => sync.write(key, value);
}
