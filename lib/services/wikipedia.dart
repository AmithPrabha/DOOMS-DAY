import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/models.dart';
import '../data/database.dart';
import 'packs.dart';

class WikiResult {
  final int pageId;
  final String title;
  const WikiResult(this.pageId, this.title);
}

/// Explicit online actions only. No WebView, JavaScript, remote fonts, tracking
/// pixels, or automatic navigation can run in the offline article renderer.
class WikipediaService {
  final AppDatabase database;
  final PackService packs;
  final HttpClient Function() clientFactory;
  WikipediaService(
    this.database,
    this.packs, {
    HttpClient Function()? clientFactory,
  }) : clientFactory = clientFactory ?? HttpClient.new;

  Future<Map<String, dynamic>> request(
    String language,
    Map<String, String> parameters, {
    void Function(int)? progress,
  }) async {
    if (!languages.containsKey(language)) {
      throw ArgumentError('Unsupported language');
    }
    final client = clientFactory();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(
        Uri.https('$language.wikipedia.org', '/w/api.php', {
          'format': 'json',
          'formatversion': '2',
          ...parameters,
        }),
      );
      request.followRedirects = false;
      request.headers.set(
        'User-Agent',
        'DoomsDayApp/0.1 (offline personal reference)',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        throw HttpException('Wikipedia returned ${response.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        if (bytes.length + chunk.length > 16 * 1024 * 1024) {
          throw StateError('Article exceeds the 16 MB individual-page limit');
        }
        bytes.addAll(chunk);
        progress?.call(bytes.length);
      }
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (json.containsKey('error')) {
        throw StateError(
          (json['error'] as Map)['info'] as String? ??
              'Wikipedia request failed',
        );
      }
      return json;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<WikiResult>> search(String language, String query) async {
    if (query.trim().isEmpty) return [];
    final result = await request(language, {
      'action': 'query',
      'list': 'search',
      'srsearch': query.trim(),
      'srnamespace': '0',
      'srlimit': '20',
      'srprop': '',
    });
    return ((result['query'] as Map)['search'] as List)
        .map((e) => WikiResult(e['pageid'] as int, e['title'] as String))
        .toList();
  }

  Future<Article> save(
    String language,
    WikiResult item,
    AppPreferences preferences, {
    void Function(int)? progress,
  }) async {
    if (preferences.wifiOnly) {
      final connections = await Connectivity().checkConnectivity();
      if (!connections.contains(ConnectivityResult.wifi) &&
          !connections.contains(ConnectivityResult.ethernet)) {
        throw StateError(
          'Wi-Fi-only downloads are enabled. Connect to Wi-Fi or change Settings.',
        );
      }
    }
    final result = await request(language, {
      'action': 'parse',
      'pageid': '${item.pageId}',
      'prop': 'text|revid',
      'disableeditsection': '1',
      'disabletoc': '1',
    }, progress: progress);
    final parsed = result['parse'] as Map<String, dynamic>;
    final rights = await request(language, {
      'action': 'query',
      'meta': 'siteinfo',
      'siprop': 'rightsinfo',
    });
    final license = (rights['query'] as Map)['rightsinfo'] as Map;
    if ((license['text'] as String? ?? '').isEmpty ||
        !(license['url'] as String? ?? '').startsWith('https://')) {
      throw StateError('Could not verify source licensing');
    }
    final article = convertPage(
      language,
      item.pageId,
      parsed,
      license['text'] as String,
      license['url'] as String,
    );
    final bytes = utf8.encode(jsonEncode(article.data)).length;
    final used = await packs.usedBytes();
    if (used + bytes > preferences.budgetMb * 1024 * 1024 ||
        await packs.diskBytes() < bytes * 3 + 8 * 1024 * 1024) {
      throw StateError('Insufficient download budget or device space');
    }
    await database.saveReference(article);
    return article;
  }

  Future<bool> hasUpdate(Article article) async {
    final response = await request(article.language, {
      'action': 'query',
      'prop': 'revisions',
      'rvprop': 'ids',
      'pageids': '${article.data['source_page_id']}',
    });
    final pages = (response['query'] as Map)['pages'] as List;
    return (pages.first['revisions'] as List).first['revid'] !=
        article.data['source_revision'];
  }

  static Article convertPage(
    String language,
    int pageId,
    Map<String, dynamic> parsed,
    String license,
    String licenseUrl,
  ) {
    final document = html.parse(parsed['text'] as String);
    for (final node in document.querySelectorAll(
      'script,style,iframe,object,embed,form,input,button,noscript,.mw-editsection',
    )) {
      node.remove();
    }
    final sections = <Map<String, dynamic>>[];
    var section = <String, dynamic>{
      'heading': parsed['title'],
      'steps': <String>[],
    };
    sections.add(section);
    final links = <String, String>{};
    void walk(Element node) {
      final tag = node.localName;
      if (RegExp(r'^h[1-6]$').hasMatch(tag ?? '')) {
        section = {'heading': node.text.trim(), 'steps': <String>[]};
        sections.add(section);
      } else if ([
        'p',
        'li',
        'pre',
        'table',
        'blockquote',
        'dd',
        'dt',
        'figcaption',
      ].contains(tag)) {
        final text = tag == 'table'
            ? node
                  .querySelectorAll('tr')
                  .map(
                    (row) => row.children
                        .map((cell) => cell.text.trim())
                        .join(' | '),
                  )
                  .join('\n')
            : node.text.trim();
        if (text.isNotEmpty) (section['steps'] as List<String>).add(text);
      } else {
        for (final child in node.children) {
          walk(child);
        }
      }
    }

    walk(document.body!);
    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href']!;
      if (href.startsWith('/wiki/') && !href.contains(':')) {
        final target = Uri.decodeComponent(
          href.substring(6).split('#').first,
        ).replaceAll('_', ' ');
        if (target.isNotEmpty) links[target] = anchor.text.trim();
      }
    }
    sections.removeWhere((s) => (s['steps'] as List).isEmpty);
    if (sections.isEmpty) {
      throw const FormatException('No supported article text');
    }
    final title = parsed['title'] as String;
    final revision = parsed['revid'] as int;
    final source =
        'https://$language.wikipedia.org/w/index.php?oldid=$revision';
    final text = (sections.first['steps'] as List<String>).first;
    return Article({
      'id': 'wiki:$language:$pageId',
      'language': language,
      'source_kind': 'wikipedia',
      'source_page_id': pageId,
      'source_revision': revision,
      'source_url': source,
      'title': title,
      'summary': text.length > 240 ? '${text.substring(0, 240)}…' : text,
      'category': 'reference',
      'region': 'Global',
      'level': 'reference',
      'sections': sections,
      'illustrations': <String>[],
      'internal_links': links.keys.toList(),
      'sources': [source, '$source&action=history', licenseUrl],
      'license': '$license — $licenseUrl',
      'attribution':
          'Wikipedia contributors, “$title”, revision $revision. '
          'Converted to offline text; images and interactive content omitted.',
      'review_status': 'external',
      'translation_review': 'external',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'aliases': [title],
      'keywords': <String>[],
      'cautions': [
        'External encyclopedia reference, not reviewed emergency guidance. '
            'This text-only copy omits images, audio, video and interactive elements; '
            'do not use it for plant or food identification.',
      ],
    });
  }
}
