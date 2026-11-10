import 'dart:convert';
import 'dart:io';
import 'package:fieldkit/core/models.dart';
import 'package:fieldkit/services/packs.dart';
import 'package:fieldkit/data/database.dart';

class WidgetPackService extends PackService {
  WidgetPackService(AppDatabase db)
    : super(db, Directory('/unused-widget-fixture'));
  @override
  Future<int> usedBytes() async => 0;
  @override
  Future<int> diskBytes() async => 1024 * 1024 * 1024;
}

List<Article> seedArticles() =>
    (jsonDecode(
              File('assets/content/essential.json').readAsStringSync(),
            )['articles']
            as List)
        .map((j) => Article(j))
        .toList();
Map<String, Map<String, String>> translations() => {
  for (final code in languages.keys)
    code: (jsonDecode(File('assets/i18n/$code.json').readAsStringSync()) as Map)
        .cast<String, String>(),
};
