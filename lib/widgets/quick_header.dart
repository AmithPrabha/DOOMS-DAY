import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models.dart';
import '../core/providers.dart';

/// Uses the same persisted controller as Settings. Wrap expands vertically;
/// controls never shrink when the title or accessibility text needs more room.
class QuickHeader extends ConsumerWidget {
  const QuickHeader({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    Future<void> save(AppPreferences next) async {
      try {
        await ref.read(preferencesProvider.notifier).update(next);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(ref, 'settings_save_error'))),
          );
        }
      }
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 12, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 560 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final title = Semantics(
            header: true,
            child: Text(
              'Dooms Day App',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: tr(ref, 'offline'),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.cloud_off_outlined,
                    semanticLabel: tr(ref, 'offline'),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('quick-theme'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: tr(ref, dark ? 'switch_light' : 'switch_dark'),
                icon: Icon(
                  dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
                onPressed: () => save(
                  ref
                      .read(preferencesProvider)
                      .copyWith(theme: dark ? 'light' : 'dark'),
                ),
              ),
              PopupMenuButton<String>(
                key: const ValueKey('quick-language'),
                constraints: const BoxConstraints(minWidth: 220),
                tooltip: tr(ref, 'language'),
                icon: const Icon(Icons.translate),
                iconSize: 24,
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                onSelected: (value) => save(
                  ref.read(preferencesProvider).copyWith(language: value),
                ),
                itemBuilder: (_) => [
                  for (final entry in languages.entries)
                    CheckedPopupMenuItem(
                      value: entry.key,
                      checked: entry.key == prefs.language,
                      child: Text(
                        entry.value,
                        textDirection: entry.key == 'ar'
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                      ),
                    ),
                ],
              ),
            ],
          );
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: controls,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: title),
                    controls,
                  ],
                );
        },
      ),
    );
  }
}
