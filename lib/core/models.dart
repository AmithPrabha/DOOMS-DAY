import 'dart:convert';

const languages = <String, String>{
  'en': 'English',
  'ar': 'العربية',
  'ml': 'മലയാളം',
  'hi': 'हिन्दी',
  'ta': 'தமிழ்',
  'te': 'తెలుగు',
  'es': 'Español',
  'fr': 'Français',
  'ru': 'Русский',
};

class Article {
  final Map<String, dynamic> data;
  Article(this.data);
  factory Article.decode(String value) =>
      Article(jsonDecode(value) as Map<String, dynamic>);
  String get id => data['id'] as String;
  String get language => data['language'] as String;
  String get title => data['title'] as String;
  String get category => data['category'] as String;
  String get summary => data['summary'] as String;
  String get level => data['level'] as String? ?? 'basic';
  String get review => data['review_status'] as String? ?? 'draft';
  String get region => data['region'] as String? ?? 'Global';
  String get sourceKind => data['source_kind'] as String? ?? 'guide';
  bool get reviewed =>
      sourceKind == 'guide' &&
      review == 'approved' &&
      data['translation_review'] == 'approved';
  MedicineEntry? get medicine => data['medicine'] is Map<String, dynamic>
      ? MedicineEntry.fromJson(data['medicine'] as Map<String, dynamic>)
      : null;
  List<String> strings(String key) => (data[key] as List? ?? []).cast<String>();
  List<Map<String, dynamic>> get sections =>
      (data['sections'] as List).cast<Map<String, dynamic>>();
  String get searchText => [
    title,
    summary,
    ...strings('aliases'),
    ...strings('keywords'),
    ...strings('question_aliases'),
    ...sections.map(
      (s) =>
          '${s['heading']} ${(s['steps'] as List? ?? []).join(' ')} ${s['code'] ?? ''} ${s['table'] ?? ''}',
    ),
  ].join(' ');
}

class MedicineEntry {
  final String genericName, storage;
  final List<String> uses, interactions;
  const MedicineEntry({
    required this.genericName,
    required this.storage,
    required this.uses,
    required this.interactions,
  });
  factory MedicineEntry.fromJson(Map<String, dynamic> value) => MedicineEntry(
    genericName: value['generic_name'] as String,
    storage: value['storage'] as String,
    uses: (value['uses'] as List).cast<String>(),
    interactions: (value['interactions'] as List).cast<String>(),
  );
}

class Pack {
  final String id, title, version, language, kind, url, sha256, description;
  final int downloadBytes, installedBytes;
  final bool essential;
  Pack({
    required this.id,
    required this.title,
    required this.version,
    required this.language,
    required this.kind,
    required this.url,
    required this.sha256,
    required this.downloadBytes,
    required this.installedBytes,
    required this.description,
    this.essential = false,
  });
  factory Pack.fromJson(Map<String, dynamic> j) => Pack(
    id: j['id'] as String,
    title: j['title'] as String,
    version: j['version'] as String,
    language: j['language'] as String,
    kind: j['kind'] as String,
    url: j['url'] as String,
    sha256: j['sha256'] as String,
    downloadBytes: j['download_bytes'] as int,
    installedBytes: j['installed_bytes'] as int,
    description: j['description'] as String? ?? '',
    essential: j['essential'] == true,
  );
}

class SavedPlace {
  final int id;
  final String name;
  final double latitude, longitude;
  SavedPlace(this.id, this.name, this.latitude, this.longitude);
}

class AppPreferences {
  final String language, theme;
  final double textScale;
  final int budgetMb;
  final bool wifiOnly;
  const AppPreferences({
    this.language = 'en',
    this.theme = 'system',
    this.textScale = 1,
    this.budgetMb = 512,
    this.wifiOnly = true,
  });
  Map<String, dynamic> toJson() => {
    'language': language,
    'theme': theme,
    'textScale': textScale,
    'budgetMb': budgetMb,
    'wifiOnly': wifiOnly,
  };
  factory AppPreferences.fromJson(Map<String, dynamic> j) => AppPreferences(
    language: languages.containsKey(j['language'])
        ? j['language'] as String
        : 'en',
    theme: ['system', 'light', 'dark'].contains(j['theme'])
        ? j['theme'] as String
        : 'system',
    textScale: ((j['textScale'] as num?)?.toDouble() ?? 1).clamp(1, 2),
    budgetMb: ((j['budgetMb'] as num?)?.toInt() ?? 512).clamp(64, 1 << 30),
    wifiOnly: j['wifiOnly'] as bool? ?? true,
  );
  AppPreferences copyWith({
    String? language,
    String? theme,
    double? textScale,
    int? budgetMb,
    bool? wifiOnly,
  }) => AppPreferences(
    language: language ?? this.language,
    theme: theme ?? this.theme,
    textScale: textScale ?? this.textScale,
    budgetMb: budgetMb ?? this.budgetMb,
    wifiOnly: wifiOnly ?? this.wifiOnly,
  );
}
