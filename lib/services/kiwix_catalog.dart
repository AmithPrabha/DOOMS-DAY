import 'dart:convert';
import 'dart:io';
import 'package:xml/xml.dart';

class ArchiveEdition {
  final String id, title, language, date, name, variant, metalink;
  final int bytes;
  const ArchiveEdition({
    required this.id,
    required this.title,
    required this.language,
    required this.date,
    required this.name,
    required this.variant,
    required this.metalink,
    required this.bytes,
  });
  bool get introductoryOnly => variant == 'mini' || name.contains('_mini');
  bool get allArticles =>
      !introductoryOnly &&
      name.contains('_all') &&
      ['nopic', 'maxi'].contains(variant);
}

/// Catalog discovery is explicitly online. Archive acquisition URLs are metalink
/// descriptors, not ZIM bytes; never pass one directly to an archive reader.
class KiwixCatalog {
  static const languageCodes = {
    'en': 'eng',
    'ar': 'ara',
    'ml': 'mal',
    'hi': 'hin',
    'ta': 'tam',
    'te': 'tel',
    'es': 'spa',
    'fr': 'fra',
    'ru': 'rus',
  };
  Future<List<ArchiveEdition>> editions(
    String language, {
    int offset = 0,
  }) async {
    final code = languageCodes[language];
    if (code == null || offset < 0) {
      throw ArgumentError('Invalid catalog query');
    }
    final uri = Uri.https('opds.library.kiwix.org', '/catalog/v2/entries', {
      'lang': code,
      'category': 'wikipedia',
      'count': '40',
      'start': '$offset',
    });
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        throw HttpException('Catalog returned ${response.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        bytes.addAll(chunk);
        if (bytes.length > 2 * 1024 * 1024) {
          throw const FormatException('Catalog too large');
        }
      }
      return parse(utf8.decode(bytes));
    } finally {
      client.close(force: true);
    }
  }

  static List<ArchiveEdition> parse(String xml) {
    final document = XmlDocument.parse(xml);
    final editions = <ArchiveEdition>[];
    for (final entry in document.findAllElements('entry')) {
      String field(String key) => entry.getElement(key)?.innerText ?? '';
      final acquisition = entry
          .findElements('link')
          .where((e) => e.getAttribute('type') == 'application/x-zim')
          .firstOrNull;
      final url = acquisition?.getAttribute('href') ?? '';
      final uri = Uri.tryParse(url);
      final bytes = int.tryParse(acquisition?.getAttribute('length') ?? '');
      if (uri?.scheme != 'https' || bytes == null || bytes <= 0) continue;
      editions.add(
        ArchiveEdition(
          id: field('id'),
          title: field('title'),
          language: field('language'),
          date: field('updated'),
          name: field('name'),
          variant: field('flavour'),
          metalink: url,
          bytes: bytes,
        ),
      );
    }
    return editions;
  }
}
