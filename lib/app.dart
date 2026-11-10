import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/models.dart';
import 'core/providers.dart';
import 'features/handbook.dart';
import 'features/maps.dart';
import 'features/downloads.dart';
import 'features/settings.dart';
import 'widgets/quick_header.dart';

class FieldkitApp extends ConsumerWidget {
  final WidgetBuilder? developerTools;
  const FieldkitApp({super.key, this.developerTools});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final font = switch (prefs.language) {
      'ar' => 'NotoSansArabic',
      'ml' => 'NotoSansMalayalam',
      'hi' => 'NotoSansDevanagari',
      'ta' => 'NotoSansTamil',
      'te' => 'NotoSansTelugu',
      _ => 'NotoSans',
    };
    ThemeData theme(Brightness brightness) {
      final dark = brightness == Brightness.dark;
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xff244d40),
        brightness: brightness,
        surface: dark ? const Color(0xff17221e) : const Color(0xfff6f4ed),
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        fontFamily: font,
        fontFamilyFallback: const [
          'NotoSans',
          'NotoSansArabic',
          'NotoSansDevanagari',
          'NotoSansMalayalam',
          'NotoSansTamil',
          'NotoSansTelugu',
        ],
        scaffoldBackgroundColor: scheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: dark ? const Color(0xff23342c) : Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: dark ? const Color(0xff23342c) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: scheme.surface,
          indicatorColor: dark
              ? const Color(0xff385144)
              : const Color(0xffdce7d9),
        ),
      );
    }

    return MaterialApp(
      title: 'Dooms Day App',
      debugShowCheckedModeBanner: false,
      locale: Locale(prefs.language),
      supportedLocales: languages.keys.map(Locale.new),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: switch (prefs.theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            MediaQuery.textScalerOf(context).scale(1) * prefs.textScale,
          ),
        ),
        child: child!,
      ),
      home: AppShell(developerTools: developerTools),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  final WidgetBuilder? developerTools;
  const AppShell({super.key, this.developerTools});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final keys = ['emergency', 'library', 'map', 'downloads', 'settings'];
    final icons = [
      Icons.health_and_safety_outlined,
      Icons.menu_book_outlined,
      Icons.explore_outlined,
      Icons.download_for_offline_outlined,
      Icons.tune,
    ];
    final pages = <Widget>[
      EmergencyScreen(onLibrary: () => setState(() => index = 1)),
      const LibraryScreen(),
      const MapScreen(),
      const DownloadsScreen(),
      SettingsScreen(developerTools: widget.developerTools),
    ];
    return Scaffold(
      body: SafeArea(
        top: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                const QuickHeader(),
                Expanded(child: pages[index]),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (n) => setState(() => index = n),
        destinations: List.generate(
          keys.length,
          (i) => NavigationDestination(
            icon: Icon(icons[i]),
            label: tr(ref, keys[i]),
          ),
        ),
      ),
    );
  }
}
