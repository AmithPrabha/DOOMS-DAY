import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../app.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../data/database.dart';
import '../services/packs.dart';
import '../features/handbook.dart';
import 'fixtures.dart';

/// Imported only by main_development.dart. No production route or secret switch.
class TestCenter extends ConsumerStatefulWidget {
  const TestCenter({super.key});
  @override
  ConsumerState<TestCenter> createState() => _TestCenterState();
}

class _TestCenterState extends ConsumerState<TestCenter> {
  List<Map<String, dynamic>> cases = [];
  Map<String, dynamic> results = {};
  String output = 'No diagnostic run yet.';
  String language = 'en', mode = 'light', scenario = 'normal';
  double scale = 1;
  final buildId = const String.fromEnvironment(
    'BUILD_ID',
    defaultValue: 'local-unversioned',
  );
  File get resultFile => File(
    p.join(
      ref.read(packServiceProvider).root.parent.path,
      'manual-results.json',
    ),
  );
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final j =
        jsonDecode(await rootBundle.loadString('registry/test_cases.json'))
            as List;
    Map<String, dynamic> records = {};
    if (await resultFile.exists()) {
      records = jsonDecode(await resultFile.readAsString());
    }
    if (mounted) {
      setState(() {
        cases = j.cast<Map<String, dynamic>>();
        results = records;
      });
    }
  }

  Future<void> _record(String id, String status) async {
    if (buildId == 'local-unversioned') {
      setState(
        () => output =
            'Use tools/flutter.py to create a build with an evidence fingerprint.',
      );
      return;
    }
    final evidence = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$id · $status'),
        content: TextField(
          controller: evidence,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Observed result and evidence',
            hintText:
                'Device/OS, steps, observations, screenshot or log reference',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, evidence.text.trim()),
            child: const Text('Record'),
          ),
        ],
      ),
    );
    evidence.dispose();
    if (note == null || note.isEmpty) return;
    results[id] = {
      'status': status,
      'build': buildId,
      'platform': Platform.operatingSystem,
      'at': DateTime.now().toUtc().toIso8601String(),
      'origin': 'manual',
      'evidence': note,
    };
    await resultFile.writeAsString(jsonEncode(results), flush: true);
    if (mounted) setState(() {});
  }

  Future<void> _preview() async {
    final db = AppDatabase.memory();
    final j = jsonDecode(
      await rootBundle.loadString('assets/content/essential.json'),
    );
    if (scenario != 'empty') {
      await db.installArticles(
        'essential',
        (j['articles'] as List).map((e) => Article(e)).toList(),
      );
    }
    if (!mounted) {
      await db.close();
      return;
    }
    final strings = ref.read(stringsProvider);
    final temporary = await Directory.systemTemp.createTemp(
      'fieldkit-preview-',
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        stringsProvider.overrideWithValue(strings),
        initialPreferencesProvider.overrideWithValue(
          AppPreferences(language: language, theme: mode, textScale: scale),
        ),
        packServiceProvider.overrideWithValue(
          FixturePacks(db, temporary, scenario),
        ),
        navigationProvider.overrideWithValue(FixtureNavigation(scenario)),
      ],
    );
    if (!mounted) {
      container.dispose();
      await db.close();
      await temporary.delete(recursive: true);
      return;
    }
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (routeContext) => Stack(
            children: [
              UncontrolledProviderScope(
                container: container,
                child: const FieldkitApp(),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: Material(
                    child: IconButton(
                      tooltip: 'Close isolated preview',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(routeContext).pop(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      container.dispose();
      await db.close();
      await temporary.delete(recursive: true);
    }
  }

  Future<void> _content() async {
    final j = jsonDecode(
      await rootBundle.loadString('assets/content/essential.json'),
    );
    final practical = jsonDecode(
      await rootBundle.loadString('assets/content/practical.json'),
    );
    final items = [
      ...(j['articles'] as List),
      ...(practical['articles'] as List),
    ].map((e) => Article(e)).toList();
    final coverage = languages.keys
        .map(
          (language) =>
              '$language: ${(practical['articles'] as List).where((a) => a['language'] == language).length}/48 practical drafts',
        )
        .join('\n');
    final failures = <String>[];
    for (final a in items) {
      try {
        PackService.validateArticle(a, allowDrafts: true);
      } catch (e) {
        failures.add('${a.id}/${a.language}: $e');
      }
    }
    if (mounted) {
      setState(
        () => output =
            'Structural checks: ${items.length} records, ${failures.length} errors.\n'
            'Approved: ${items.where((a) => a.review == "approved").length}.\n'
            '$coverage\n'
            'Medical and translation review cannot be performed by this check.\n${failures.join('\n')}',
      );
    }
  }

  Future<void> _diagnostics() async {
    final db = ref.read(databaseProvider),
        service = ref.read(packServiceProvider);
    final bytes = await service.usedBytes();
    final installed = await db.installedPacks();
    final free = await service.diskBytes();
    if (mounted) {
      setState(
        () => output =
            'Build: $buildId\nDatabase schema: ${db.schemaVersion}\n'
            'App: 0.1.0+1\nPlatform: ${Platform.operatingSystem}\nPacks: ${installed.length}\nOptional storage: $bytes bytes\nFree storage: $free bytes\n'
            '${installed.map((p) => "${p['id']} ${p['version']}").join('\n')}\n'
            'Location and messages are excluded from this output.',
      );
    }
  }

  Future<void> _sensorCheck() async {
    try {
      final reading = await ref
          .read(navigationProvider)
          .compass
          .first
          .timeout(const Duration(seconds: 5));
      output = reading.heading == null
          ? 'BLOCKED: native sensor returned no heading. Check device support and calibration.'
          : 'Native heading available. Accuracy: ${reading.accuracy ?? "unknown"} degrees. Physical accuracy still needs manual comparison.';
    } catch (_) {
      output =
          'BLOCKED: native compass unavailable or timed out. No location coordinates collected.';
    }
    if (mounted) setState(() {});
  }

  Future<void> _feature(String which) async {
    // Isolated fixture database: reset/test actions cannot touch real app data.
    final db = AppDatabase.memory();
    try {
      if (which == 'search') {
        final j = jsonDecode(
          await rootBundle.loadString('assets/content/essential.json'),
        );
        await db.installArticles(
          'essential',
          (j['articles'] as List).map((e) => Article(e)).toList(),
        );
        final found = await db.articles('en', query: 'APAP');
        if (found.length != 1 || found.single.id != 'paracetamol') {
          throw StateError('Alias search failed');
        }
        output =
            'PASS: APAP resolves to the medicine reference in isolated SQLite.';
      } else {
        try {
          await db.removePack('essential');
          throw StateError('Core was removable');
        } on StateError catch (e) {
          if (!e.message.toString().contains('cannot be removed')) rethrow;
          output = 'PASS: essential handbook removal rejected.';
        }
      }
    } catch (e) {
      output = 'FAIL: $e';
    } finally {
      await db.close();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 5,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Test Center'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'UI'),
            Tab(text: 'Content'),
            Tab(text: 'Features'),
            Tab(text: 'Diagnostics'),
            Tab(text: 'Results'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Previews use a separate in-memory database and simulated sensors. They never request device permissions.',
              ),
              DropdownButton<String>(
                isExpanded: true,
                value: language,
                items: languages.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => language = v!),
              ),
              DropdownButton<String>(
                value: mode,
                items: ['light', 'dark', 'system']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => mode = v!),
              ),
              Slider(
                value: scale,
                min: 1,
                max: 2,
                divisions: 4,
                label: '${scale}x',
                onChanged: (v) => setState(() => scale = v),
              ),
              DropdownButton<String>(
                value: scenario,
                items:
                    [
                          'normal',
                          'empty',
                          'missing sensor',
                          'denied location',
                          'network unavailable',
                        ]
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (v) => setState(() => scenario = v!),
              ),
              FilledButton(
                onPressed: _preview,
                child: const Text('Open isolated preview'),
              ),
              const SectionTitle('Error and loading specimens'),
              const LinearProgressIndicator(),
              const ListTile(
                leading: Icon(Icons.location_disabled),
                title: Text('Location permission denied'),
              ),
              const ListTile(
                leading: Icon(Icons.explore_off_outlined),
                title: Text('Compass unavailable'),
              ),
              const ListTile(
                leading: Icon(Icons.cloud_off),
                title: Text(
                  'Network unavailable — installed content remains accessible',
                ),
              ),
              const Text(
                'Specimens are visual states, not proof that device permission handling passed.',
              ),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              FilledButton(
                onPressed: _content,
                child: const Text('Validate bundled content structure'),
              ),
              const SizedBox(height: 16),
              SelectableText(output),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              FilledButton(
                onPressed: () => _feature('search'),
                child: const Text('Run isolated alias-search test'),
              ),
              FilledButton(
                onPressed: () => _feature('core'),
                child: const Text('Check essential-pack protection'),
              ),
              const Text(
                'Run corrupt-package, interrupted-update and migration suites with flutter test. Hardware cases require a real device.',
              ),
              const SizedBox(height: 16),
              SelectableText(output),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              FilledButton(
                onPressed: _diagnostics,
                child: const Text('Collect sanitized diagnostics'),
              ),
              OutlinedButton(
                onPressed: _sensorCheck,
                child: const Text('Probe native compass availability'),
              ),
              const SizedBox(height: 16),
              SelectableText(output),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Build: $buildId. Manual records are distinct from automated evidence.',
              ),
              ...cases.map((c) {
                final record = results[c['id']] as Map?;
                final current =
                    buildId != 'local-unversioned' &&
                    record?['build'] == buildId;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c['id']} · ${c['title']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Expected: ${c['expected']}'),
                        Text(
                          'Features: ${c['feature_ids']}\nPrerequisites: ${c['prerequisites']}\nSteps: ${c['steps']}\nType: ${c['type']}\nPlatforms: ${c['platforms']}',
                        ),
                        Text(
                          'Result: ${current ? record!['status'] : 'not_run'}${record != null && !current ? ' (older build evidence retained)' : ''}',
                        ),
                        Wrap(
                          spacing: 6,
                          children: ['passed', 'failed', 'blocked', 'not_run']
                              .map(
                                (status) => TextButton(
                                  onPressed: () =>
                                      _record(c['id'] as String, status),
                                  child: Text(status),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              FilledButton(
                onPressed: () async {
                  final controller = TextEditingController();
                  final data = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Import automated JSON results'),
                      content: TextField(controller: controller, maxLines: 8),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, controller.text),
                          child: const Text('Import'),
                        ),
                      ],
                    ),
                  );
                  controller.dispose();
                  if (data == null) return;
                  try {
                    final record = jsonDecode(data) as Map<String, dynamic>;
                    if (buildId == 'local-unversioned' ||
                        record['build'] != buildId ||
                        record['results'] is! List) {
                      throw const FormatException(
                        'Build mismatch or missing results',
                      );
                    }
                    final imported = <String, dynamic>{};
                    for (final r in record['results'] as List) {
                      if (!cases.any((c) => c['id'] == r['id']) ||
                          ![
                            'passed',
                            'failed',
                            'blocked',
                            'not_run',
                          ].contains(r['status'])) {
                        throw const FormatException('Unknown test or status');
                      }
                      imported[r['id']] = {
                        ...r as Map<String, dynamic>,
                        'build': buildId,
                        'origin': 'automated import',
                      };
                    }
                    results.addAll(imported);
                    await resultFile.writeAsString(
                      jsonEncode(results),
                      flush: true,
                    );
                    if (mounted) setState(() {});
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Import rejected: $e')),
                      );
                    }
                  }
                },
                child: const Text('Import build results'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
