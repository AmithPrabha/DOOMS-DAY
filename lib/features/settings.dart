import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models.dart';
import '../core/providers.dart';
import 'handbook.dart';

class SettingsScreen extends ConsumerWidget {
  final WidgetBuilder? developerTools;
  const SettingsScreen({super.key, this.developerTools});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    Future<void> save(AppPreferences next) async {
      try {
        await ref.read(preferencesProvider.notifier).update(next);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings could not be saved. Check free storage.'),
            ),
          );
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr(ref, 'settings'),
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        SectionTitle(tr(ref, 'language')),
        DropdownButtonFormField<String>(
          key: ValueKey(prefs.language),
          initialValue: prefs.language,
          isExpanded: true,
          items: languages.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => save(prefs.copyWith(language: v)),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Core navigation and starter cards are translated. Expanded reference and some controls remain English pending translation review.',
          ),
        ),
        SectionTitle(tr(ref, 'appearance')),
        Wrap(
          spacing: 8,
          children: ['system', 'light', 'dark']
              .map(
                (mode) => ChoiceChip(
                  label: Text(tr(ref, mode)),
                  selected: prefs.theme == mode,
                  onSelected: (_) => save(prefs.copyWith(theme: mode)),
                ),
              )
              .toList(),
        ),
        SectionTitle(tr(ref, 'text_size')),
        Slider(
          value: prefs.textScale,
          min: 1,
          max: 2,
          divisions: 4,
          label: '${(prefs.textScale * 100).round()}%',
          onChanged: (v) => save(prefs.copyWith(textScale: v)),
        ),
        Text(
          '${(prefs.textScale * 100).round()}% · Also respects your device text size.',
        ),
        SectionTitle(tr(ref, 'storage')),
        FutureBuilder<int>(
          future: () async {
            final packs = ref.read(packServiceProvider);
            return (await packs.diskBytes() + await packs.usedBytes()) ~/
                (1024 * 1024);
          }(),
          builder: (context, snapshot) {
            final capacity = snapshot.data;
            final options = <int>{
              prefs.budgetMb,
              for (var n = 64; capacity != null && n <= capacity; n *= 2) n,
              if (capacity != null && capacity >= 64) capacity,
            }.toList()..sort();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  key: ValueKey('${prefs.budgetMb}/$capacity'),
                  initialValue: prefs.budgetMb,
                  isExpanded: true,
                  items: options
                      .map(
                        (n) => DropdownMenuItem(
                          value: n,
                          child: Text(
                            n < 1024
                                ? '$n MB'
                                : '${(n / 1024).toStringAsFixed(1)} GB',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: capacity == null
                      ? null
                      : (v) => save(prefs.copyWith(budgetMb: v)),
                ),
                Text(
                  capacity == null
                      ? (snapshot.hasError
                            ? 'Device capacity is unavailable. Your saved budget is unchanged.'
                            : 'Checking device capacity…')
                      : 'Available for offline content: $capacity MB. Installations also require temporary space.',
                ),
              ],
            );
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr(ref, 'wifi_only')),
          value: prefs.wifiOnly,
          onChanged: (v) => save(prefs.copyWith(wifiOnly: v)),
        ),
        const Text(
          'Lowering your budget does not delete existing packs. Downloads also reserve room for safe updates.',
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(tr(ref, 'privacy')),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Dooms Day App',
              applicationVersion: '0.1.0',
              children: const [
                Text(
                  'Reference information, not a medical device. No diagnosis or dose calculations. Seek qualified medical advice before making medical decisions.',
                ),
                SizedBox(height: 12),
                Text(
                  'Bookmarks, preferences and saved places stay on this device. Location is requested only when you tap Locate. No account, advertising or analytics SDK is included. Download hosts receive network metadata such as IP addresses. Opening a source uses your external browser.',
                ),
                SizedBox(height: 12),
                Text(
                  'Draft content is visible only in development builds. Public privacy and support URLs must be configured before release.',
                ),
              ],
            ),
          ),
        ),
        if (developerTools != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.science_outlined),
              title: Text(tr(ref, 'test_center')),
              subtitle: const Text('Development build only'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: developerTools!),
              ),
            ),
          ),
        const SizedBox(height: 20),
        const Text(
          'Dooms Day App / 0.1.0\nMade to work when the network does not.',
        ),
      ],
    );
  }
}
