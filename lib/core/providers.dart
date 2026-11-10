import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../services/packs.dart';
import '../services/navigation.dart';
import 'models.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Override at bootstrap'),
);
final packServiceProvider = Provider<PackService>(
  (ref) => throw UnimplementedError('Override at bootstrap'),
);
final navigationProvider = Provider<NavigationService>(
  (ref) => NavigationService(),
);
final stringsProvider = Provider<Map<String, Map<String, String>>>(
  (ref) => throw UnimplementedError('Override at bootstrap'),
);
final preferencesProvider =
    NotifierProvider<PreferencesController, AppPreferences>(
      PreferencesController.new,
    );
final initialPreferencesProvider = Provider<AppPreferences>(
  (ref) => const AppPreferences(),
);

class PreferencesController extends Notifier<AppPreferences> {
  Future<void> _writes = Future.value();
  int _revision = 0;
  late AppPreferences _committed;
  @override
  AppPreferences build() => _committed = ref.read(initialPreferencesProvider);
  Future<void> update(AppPreferences next) async {
    final revision = ++_revision;
    state = next;
    final database = ref.read(databaseProvider);
    final write = _writes.then((_) async {
      await database.savePreferences(next);
      _committed = next;
    });
    _writes = write.catchError((Object _) {});
    try {
      await write;
    } catch (_) {
      if (revision == _revision) state = _committed;
      rethrow;
    }
  }
}

String tr(WidgetRef ref, String key) {
  final code = ref.watch(preferencesProvider).language;
  final strings = ref.watch(stringsProvider);
  return strings[code]?[key] ?? strings['en']?[key] ?? key;
}

final revisionProvider = NotifierProvider<Revision, int>(Revision.new);

class Revision extends Notifier<int> {
  @override
  int build() => 0;
  void refresh() => state++;
}

final bookmarksProvider = FutureProvider<Set<String>>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(databaseProvider).bookmarks();
});
final installedProvider = FutureProvider<List<Map<String, Object?>>>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(databaseProvider).installedPacks();
});
