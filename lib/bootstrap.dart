import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'core/models.dart';
import 'core/providers.dart';
import 'data/database.dart';
import 'services/packs.dart';

Future<void> bootstrap({
  bool development = false,
  WidgetBuilder? developerTools,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final family in [
      'NotoSans',
      'NotoSansArabic',
      'NotoSansDevanagari',
      'NotoSansMalayalam',
      'NotoSansTamil',
      'NotoSansTelugu',
    ]) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/fonts/$family-OFL.txt'));
    }
  });
  try {
    final support = await getApplicationSupportDirectory();
    final root = Directory(
      p.join(support.path, development ? 'development' : 'production'),
    );
    await root.create(recursive: true);
    if (Platform.isIOS) {
      await const MethodChannel(
        'org.fieldkit/storage',
      ).invokeMethod<void>('excludeFromBackup', {'path': root.path});
    }
    final db = AppDatabase.file(File(p.join(root.path, 'fieldkit.sqlite')));
    final content = jsonDecode(
      await rootBundle.loadString('assets/content/essential.json'),
    );
    final practical = jsonDecode(
      await rootBundle.loadString('assets/content/practical.json'),
    );
    final articles =
        [...(content['articles'] as List), ...(practical['articles'] as List)]
            .map((e) => Article(e))
            .where(
              (a) =>
                  development ||
                  (a.review == 'approved' &&
                      a.data['translation_review'] == 'approved'),
            )
            .toList();
    for (final a in articles) {
      PackService.validateArticle(a, allowDrafts: development);
    }
    await db.installArticles('essential', articles);
    final preferences = await db.preferences();
    final strings = <String, Map<String, String>>{};
    for (final code in languages.keys) {
      strings[code] =
          (jsonDecode(await rootBundle.loadString('assets/i18n/$code.json'))
                  as Map)
              .cast<String, String>();
    }
    runApp(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialPreferencesProvider.overrideWithValue(preferences),
          stringsProvider.overrideWithValue(strings),
          packServiceProvider.overrideWithValue(
            PackService(
              db,
              Directory(p.join(root.path, 'packs')),
              allowDrafts: development,
            ),
          ),
        ],
        child: FieldkitApp(developerTools: developerTools),
      ),
    );
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.storage_outlined, size: 64),
                  const Text(
                    'Dooms Day App could not open local storage.',
                    style: TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your existing files have not been reset. Check free space and restart the app.',
                  ),
                  if (development) SelectableText('$error'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
