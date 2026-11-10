import '../core/models.dart';
import 'database.dart';

/// Only question scaffolding is removed. Negation, conditions and modifiers
/// remain mandatory search terms; a query for brown rice never becomes rice.
String normalizeQuestion(String query, String language) {
  var value = query.toLowerCase().trim();
  const prefixes = {
    'en': ['how do i ', 'how can i ', 'how to ', 'what is ', 'what are '],
    'ar': ['كيف يمكنني ', 'كيف ', 'ما هو ', 'ما هي '],
    'ml': ['എങ്ങനെ '],
    'hi': ['कैसे ', 'क्या है '],
    'ta': ['எப்படி '],
    'te': ['ఎలా '],
    'es': ['cómo puedo ', 'cómo ', 'qué es '],
    'fr': ['comment puis-je ', 'comment ', 'qu’est-ce que '],
    'ru': ['как мне ', 'как ', 'что такое '],
  };
  for (final prefix in prefixes[language] ?? <String>[]) {
    if (value.startsWith(prefix)) {
      value = value.substring(prefix.length);
      break;
    }
  }
  // Terminal question punctuation is syntax, not an FTS token.
  value = value.replaceAll(RegExp(r'[?؟¿!।]+$'), '').trim();
  return value;
}

class KnowledgePage {
  final List<Article> articles;
  final bool hasMore;
  const KnowledgePage(this.articles, this.hasMore);
  Article? get reviewedAnswer => articles.where((a) => a.reviewed).firstOrNull;
}

class KnowledgeRepository {
  final AppDatabase database;
  const KnowledgeRepository(this.database);

  /// Bounded SQLite lookup. External references share the same offline FTS
  /// index but keep source-qualified IDs and never qualify as reviewed answers.
  Future<KnowledgePage> search(
    String query,
    String language, {
    String? category,
    String? level,
    bool bookmarksOnly = false,
    int page = 0,
    int pageSize = 20,
  }) async {
    if (page < 0 || pageSize < 1 || pageSize > 100) {
      throw ArgumentError('Invalid search page');
    }
    final normalized = normalizeQuestion(query, language);
    final articles = await database.rankedArticles(
      language,
      normalized,
      category: category,
      level: level,
      bookmarksOnly: bookmarksOnly,
      offset: page * pageSize,
      limit: pageSize + 1,
    );
    return KnowledgePage(
      articles.take(pageSize).toList(),
      articles.length > pageSize,
    );
  }
}
