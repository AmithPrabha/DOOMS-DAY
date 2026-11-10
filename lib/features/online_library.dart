import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../core/models.dart';
import '../services/wikipedia.dart';
import 'handbook.dart';

class OnlineLibrary extends ConsumerStatefulWidget {
  const OnlineLibrary({super.key});
  @override
  ConsumerState<OnlineLibrary> createState() => _OnlineLibraryState();
}

class _OnlineLibraryState extends ConsumerState<OnlineLibrary> {
  final query = TextEditingController();
  List<WikiResult> results = [];
  String? error, resultLanguage;
  bool busy = false;
  int received = 0;
  final saved = <int>{};
  WikipediaService get service => WikipediaService(
    ref.read(databaseProvider),
    ref.read(packServiceProvider),
  );
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final language = ref.read(preferencesProvider).language;
    setState(() {
      busy = true;
      error = null;
      results = [];
      saved.clear();
    });
    try {
      final items = await service.search(language, query.text);
      final stored = <int>{};
      for (final item in items) {
        if (await ref
                .read(databaseProvider)
                .article('wiki:$language:${item.pageId}', language) !=
            null) {
          stored.add(item.pageId);
        }
      }
      if (mounted) {
        setState(() {
          results = items;
          resultLanguage = language;
          saved.addAll(stored);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save(WikiResult item) async {
    setState(() {
      busy = true;
      error = null;
      received = 0;
    });
    try {
      final article = await service.save(
        resultLanguage!,
        item,
        ref.read(preferencesProvider),
        progress: (bytes) {
          if (mounted) setState(() => received = bytes);
        },
      );
      ref.read(revisionProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => saved.add(item.pageId));
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ArticleScreen(article: article)),
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Online reference library')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Wikipedia · ${languages[ref.watch(preferencesProvider).language]}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          'Search contacts Wikipedia only when you press Search. '
          'Save a text-only article to read it from Library without internet. '
          'External articles are not reviewed survival instructions. '
          'Images and interactive elements are not included.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: query,
          decoration: const InputDecoration(labelText: 'Search Wikipedia'),
          onSubmitted: busy ? null : (_) => search(),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : search,
          icon: const Icon(Icons.travel_explore),
          label: const Text('Search online'),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final topic in const [
              'Rice',
              'Python (programming language)',
              'Electricity',
            ])
              ActionChip(
                label: Text(topic),
                onPressed: busy
                    ? null
                    : () {
                        query.text = topic;
                      },
              ),
          ],
        ),
        if (busy) ...[
          const LinearProgressIndicator(),
          Text('${(received / 1024).toStringAsFixed(1)} KB received'),
        ],
        if (error != null) Text(error!),
        for (final item in results)
          Card(
            child: ListTile(
              title: Text(item.title),
              subtitle: Text(
                '${languages[resultLanguage]} · ${saved.contains(item.pageId) ? "Saved offline" : "Text only · size shown during download"}',
              ),
              trailing: IconButton(
                tooltip: saved.contains(item.pageId)
                    ? 'Save current revision again'
                    : 'Save offline',
                onPressed: busy ? null : () => save(item),
                icon: Icon(
                  saved.contains(item.pageId)
                      ? Icons.download_done
                      : Icons.download_outlined,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
