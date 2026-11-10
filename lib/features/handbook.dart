import 'dart:io';
import 'dart:async';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../data/knowledge_repository.dart';
import '../services/wikipedia.dart';
import 'online_library.dart';

const categoryNames = {
  'medical': 'First aid',
  'medicines': 'Medicines',
  'disasters': 'Disasters',
  'wilderness': 'Wilderness & desert',
  'food': 'Food & foraging',
  'water': 'Water',
  'cooking': 'Cooking & storage',
  'sanitation': 'Sanitation',
  'outbreaks': 'Outbreaks',
  'electronics': 'Electronics & power',
  'mechanical': 'Mechanical repairs',
  'computing': 'Computing & coding',
  'networks': 'Local networks',
  'communications': 'Radio & satellite',
  'preparedness': 'Preparation & shutdowns',
};
IconData categoryIcon(String category) => switch (category) {
  'medical' || 'medicines' => Icons.medical_services_outlined,
  'water' => Icons.water_drop_outlined,
  'food' || 'cooking' => Icons.restaurant_outlined,
  'wilderness' => Icons.terrain,
  'disasters' => Icons.thunderstorm_outlined,
  'electronics' || 'mechanical' => Icons.build_outlined,
  'computing' || 'networks' || 'communications' => Icons.router_outlined,
  _ => Icons.shield_outlined,
};

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

Future<void> openArticle(BuildContext context, WidgetRef ref, String id) async {
  final lang = ref.read(preferencesProvider).language;
  var article = await ref.read(databaseProvider).article(id, lang);
  var fallback = false;
  if (article == null && lang != 'en') {
    article = await ref.read(databaseProvider).article(id, 'en');
    fallback = true;
  }
  if (!context.mounted) return;
  if (article == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This article is not installed or has not been approved.',
        ),
      ),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ArticleScreen(article: article!, fallback: fallback),
    ),
  );
}

class EmergencyScreen extends ConsumerWidget {
  final VoidCallback onLibrary;
  const EmergencyScreen({super.key, required this.onLibrary});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xff244d40),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(ref, 'offline'),
              style: const TextStyle(
                color: Color(0xffc4dca5),
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              tr(ref, 'ready'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 32,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: () => openArticle(context, ref, 'prepare'),
              child: Text(tr(ref, 'essential')),
            ),
          ],
        ),
      ),
      SectionTitle(tr(ref, 'help')),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth > 520
              ? (constraints.maxWidth - 24) / 3
              : (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                [
                      (
                        'first-aid',
                        'category_medical',
                        Icons.medical_services_outlined,
                      ),
                      ('flood', 'flood', Icons.flood_outlined),
                      ('earthquake', 'earthquake', Icons.broken_image_outlined),
                      ('desert', 'desert', Icons.wb_sunny_outlined),
                      ('water', 'safe_water', Icons.water_drop_outlined),
                      ('outbreak', 'category_outbreaks', Icons.masks_outlined),
                    ]
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => openArticle(context, ref, item.$1),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    item.$3,
                                    size: 29,
                                    color: const Color(0xffa95737),
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    tr(ref, item.$2),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          );
        },
      ),
      SectionTitle(tr(ref, 'learn')),
      Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const Icon(Icons.auto_stories_outlined, size: 34),
          title: Text(tr(ref, 'library')),
          subtitle: Text(tr(ref, 'library_summary')),
          trailing: const Icon(Icons.arrow_forward),
          onTap: onLibrary,
        ),
      ),
      const ReadinessCard(),
      SectionTitle(tr(ref, 'checklist')),
      const PreparationChecklist(),
    ],
  );
}

class ReadinessCard extends ConsumerWidget {
  const ReadinessCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(installedProvider).asData?.value ?? [];
    final maps = packs
        .where(
          (p) =>
              p['kind'] == 'map' &&
              File('${p['path']}/map.pmtiles').existsSync(),
        )
        .length;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: Text(tr(ref, 'readiness')),
        subtitle: Text(
          'Handbook bundled • $maps map regions on disk\nOpen Downloads to verify installed resources.',
        ),
      ),
    );
  }
}

class PreparationChecklist extends ConsumerStatefulWidget {
  const PreparationChecklist({super.key});
  @override
  ConsumerState<PreparationChecklist> createState() =>
      _PreparationChecklistState();
}

class _PreparationChecklistState extends ConsumerState<PreparationChecklist> {
  Set<String> checked = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await ref.read(databaseProvider).checkedItems();
    if (mounted) setState(() => checked = values);
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children:
          [
                ('water', 'Water and essential supplies'),
                ('medicines', 'Prescribed medicines and records'),
                ('contacts', 'Emergency contacts saved offline'),
                ('maps', 'Local map downloaded and tested'),
                ('power', 'Charged light and power bank'),
                ('meeting', 'Meeting point agreed'),
              ]
              .map(
                (item) => CheckboxListTile(
                  value: checked.contains(item.$1),
                  title: Text(tr(ref, 'check_${item.$1}')),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) async {
                    await ref.read(databaseProvider).checkItem(item.$1, value!);
                    await _load();
                  },
                ),
              )
              .toList(),
    ),
  );
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String query = '';
  Timer? debounce;
  int page = 0;
  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  String? category, level;
  String? lastLanguage;
  bool bookmarksOnly = false, englishFallback = false;
  @override
  Widget build(BuildContext context) {
    ref.watch(revisionProvider);
    final locale = ref.watch(preferencesProvider).language;
    if (lastLanguage != locale) {
      lastLanguage = locale;
      englishFallback = false;
      page = 0;
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(ref, 'library'),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    icon: const Icon(Icons.public),
                    label: const Text('Online reference library'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OnlineLibrary()),
                    ),
                  ),
                ),
                TextField(
                  decoration: InputDecoration(
                    hintText: tr(ref, 'search'),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (s) {
                    debounce?.cancel();
                    debounce = Timer(const Duration(milliseconds: 250), () {
                      if (mounted) {
                        setState(() {
                          query = s;
                          page = 0;
                        });
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: Text(tr(ref, 'bookmarks')),
                      selected: bookmarksOnly,
                      onSelected: (v) => setState(() {
                        bookmarksOnly = v;
                        page = 0;
                      }),
                    ),
                    for (final value in ['basic', 'advanced'])
                      FilterChip(
                        label: Text(tr(ref, value)),
                        selected: level == value,
                        onSelected: (v) => setState(() {
                          level = v ? value : null;
                          page = 0;
                        }),
                      ),
                    if (locale != 'en')
                      FilterChip(
                        label: Text(tr(ref, 'english_reference')),
                        selected: englishFallback,
                        onSelected: (v) => setState(() {
                          englishFallback = v;
                          page = 0;
                        }),
                      ),
                  ],
                ),
                DropdownButton<String?>(
                  isExpanded: true,
                  value: category,
                  items: [
                    DropdownMenuItem(value: null, child: Text(tr(ref, 'all'))),
                    ...categoryNames.entries.map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(tr(ref, 'category_${e.key}')),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    category = v;
                    page = 0;
                  }),
                ),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: true,
          child: FutureBuilder<KnowledgePage>(
            key: ValueKey(
              '$locale/$englishFallback/$query/$category/$level/$bookmarksOnly/$page',
            ),
            future: KnowledgeRepository(ref.read(databaseProvider)).search(
              query,
              englishFallback ? 'en' : locale,
              category: category,
              level: level,
              bookmarksOnly: bookmarksOnly,
              page: page,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Search unavailable: ${snapshot.error}'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final result = snapshot.data!;
              final items = result.articles;
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(tr(ref, 'no_results')),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (query.isNotEmpty && result.reviewedAnswer != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(result.reviewedAnswer!.title),
                            Text(
                              (result.reviewedAnswer!.sections.first['steps']
                                      as List)
                                  .join('\n'),
                            ),
                            ...result.reviewedAnswer!
                                .strings('cautions')
                                .map(Text.new),
                          ],
                        ),
                      ),
                    ),
                  ...items.map((article) => ArticleTile(article: article)),
                  Wrap(
                    spacing: 12,
                    children: [
                      if (page > 0)
                        OutlinedButton(
                          onPressed: () => setState(() => page--),
                          child: const Text('Previous'),
                        ),
                      if (result.hasMore)
                        OutlinedButton(
                          onPressed: () => setState(() => page++),
                          child: const Text('Next'),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class ArticleTile extends StatelessWidget {
  final Article article;
  const ArticleTile({super.key, required this.article});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(
        categoryIcon(article.category),
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        article.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '${article.sourceKind == 'wikipedia' ? 'Wikipedia · saved external reference\n' : ''}${article.summary}',
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ArticleScreen(article: article)),
      ),
    ),
  );
}

class ArticleScreen extends ConsumerWidget {
  final Article article;
  final bool fallback;
  const ArticleScreen({
    super.key,
    required this.article,
    this.fallback = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionKeys = article.sections.map((_) => GlobalKey()).toList();
    final saved =
        ref.watch(bookmarksProvider).asData?.value.contains(article.id) ??
        false;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (article.sourceKind == 'wikipedia')
            IconButton(
              tooltip: 'Remove offline copy (keep bookmark)',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final remove = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove offline copy?'),
                    content: const Text(
                      'The bookmark remains. Internet will be needed to save this article again.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (remove != true) return;
                await ref.read(databaseProvider).removePack(article.id);
                ref.read(revisionProvider.notifier).refresh();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          IconButton(
            tooltip: tr(ref, 'bookmarks'),
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_outline),
            onPressed: () async {
              await ref.read(databaseProvider).toggleBookmark(article);
              ref.read(revisionProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Directionality(
        textDirection: article.language == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (fallback)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'English reference. Translation is not installed.',
                    ),
                  ),
                ),
              Text(
                article.title,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                article.summary,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(article.level)),
                  Chip(label: Text(article.region)),
                ],
              ),
              if (article.id == 'practical-python-inventory')
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Save Python example…'),
                  onPressed: () async {
                    try {
                      final text = await rootBundle.loadString(
                        'assets/examples/supplies.py',
                      );
                      await const MethodChannel(
                        'org.fieldkit/export',
                      ).invokeMethod<bool>('example', {'text': text});
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not export example: $e'),
                          ),
                        );
                      }
                    }
                  },
                ),
              if (article.sourceKind == 'wikipedia') ...[
                Text(article.data['attribution'] as String),
                TextButton.icon(
                  icon: const Icon(Icons.update),
                  label: const Text('Check for update online'),
                  onPressed: () async {
                    try {
                      final available = await WikipediaService(
                        ref.read(databaseProvider),
                        ref.read(packServiceProvider),
                      ).hasUpdate(article);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              available
                                  ? 'A newer revision is available. Save this page again in Online reference library.'
                                  : 'This is the current revision.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                ),
              ],
              if (article.sourceKind == 'guide' && article.review != 'approved')
                Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(tr(ref, 'draft')),
                  ),
                ),
              for (final name in article.strings('illustrations'))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: InkWell(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: IconButton(
                                tooltip: 'Close image',
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            SizedBox(
                              height: 360,
                              child: InteractiveViewer(
                                maxScale: 6,
                                child: _illustration(ref, name),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    child: Semantics(
                      label: 'Zoom image',
                      button: true,
                      child: _illustration(ref, name),
                    ),
                  ),
                ),
              ExpansionTile(
                title: const Text('Contents'),
                children: [
                  for (var i = 0; i < article.sections.length; i++)
                    ListTile(
                      title: Text(article.sections[i]['heading'] as String),
                      onTap: () => Scrollable.ensureVisible(
                        sectionKeys[i].currentContext!,
                        duration: const Duration(milliseconds: 250),
                      ),
                    ),
                ],
              ),
              if (article.strings('prerequisites').isNotEmpty) ...[
                SectionTitle(tr(ref, 'equipment')),
                ...article.strings('prerequisites').map((s) => Text('• $s')),
              ],
              ...article.sections.asMap().entries.expand((entry) {
                final s = entry.value;
                return [
                  Container(
                    key: sectionKeys[entry.key],
                    child: SectionTitle(s['heading'] as String),
                  ),
                  if (s['code'] is String)
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SelectableText(
                            s['code'] as String,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ),
                  if (s['table'] is List)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Table(
                        defaultColumnWidth: const FixedColumnWidth(180),
                        border: TableBorder.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        children: (s['table'] as List)
                            .map(
                              (row) => TableRow(
                                children: (row as List)
                                    .map(
                                      (cell) => Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text('$cell'),
                                      ),
                                    )
                                    .toList(),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ...(s['steps'] as List).asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 15,
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SelectableText(
                              entry.value as String,
                              style: const TextStyle(
                                fontSize: 17,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              }),
              ...article
                  .strings('cautions')
                  .map(
                    (s) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(s)),
                          ],
                        ),
                      ),
                    ),
                  ),
              if (article.strings('internal_links').isNotEmpty)
                ExpansionTile(
                  title: const Text('Related pages (saved offline only)'),
                  children: [
                    for (final title in article.strings('internal_links'))
                      ListTile(
                        title: Text(title),
                        onTap: () async {
                          final rows = await ref
                              .read(databaseProvider)
                              .customSelect(
                                'SELECT body FROM articles WHERE language=? AND title=? LIMIT 1',
                                variables: [
                                  Variable(article.language),
                                  Variable(title),
                                ],
                              )
                              .get();
                          if (!context.mounted) return;
                          if (rows.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'This page is not saved. Use Online reference library while connected.',
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArticleScreen(
                                article: Article.decode(
                                  rows.first.read<String>('body'),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              SectionTitle(tr(ref, 'sources')),
              ...article
                  .strings('sources')
                  .map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: SelectableText(s),
                      trailing: IconButton(
                        tooltip: 'Open source (internet required)',
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () async {
                          final uri = Uri.tryParse(s);
                          if (uri?.scheme == 'https') {
                            await launchUrl(
                              uri!,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      ),
                    ),
                  ),
              Text(
                'Updated: ${article.data['updated_at']}\nReview: ${article.review}\n${article.data['license']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _illustration(WidgetRef ref, String name) {
    final descriptions = (article.data['media'] as List? ?? []).where(
      (m) => m is Map && m['path'] == name,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _image(ref, name),
        for (final media in descriptions) ...[
          Text(media['caption'] as String? ?? ''),
          Text(
            '${media['attribution'] ?? ''} · ${media['license'] ?? ''}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _image(WidgetRef ref, String name) {
    if (name.startsWith('assets/')) {
      return name.endsWith('.svg')
          ? SvgPicture.asset(name, height: 160, semanticsLabel: article.title)
          : Image.asset(name, height: 200, semanticLabel: article.title);
    }
    return FutureBuilder(
      future: ref
          .read(databaseProvider)
          .customSelect(
            'SELECT p.path FROM packs p JOIN articles a ON a.pack_id=p.id WHERE a.id=? AND a.language=?',
            variables: [Variable(article.id), Variable(article.language)],
          )
          .getSingleOrNull(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final root = snapshot.data!.read<String>('path');
        final path = p.normalize(p.join(root, name));
        if (!p.isWithin(root, path)) return const SizedBox.shrink();
        final file = File(path);
        return name.endsWith('.svg')
            ? SvgPicture.file(file, height: 160)
            : Image.file(file, height: 160);
      },
    );
  }
}
