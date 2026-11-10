import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../services/packs.dart';
import 'handbook.dart';

String sizeLabel(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});
  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  List<Pack> catalog = [];
  String? message, active;
  double progress = 0;
  int used = 0;
  CancelDownload? cancel;
  @override
  void initState() {
    super.initState();
    _refresh(localOnly: true);
  }

  @override
  void dispose() {
    cancel?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool localOnly = false}) async {
    try {
      final service = ref.read(packServiceProvider);
      final bytes = await service.usedBytes();
      if (!localOnly) catalog = await service.catalog();
      if (mounted) setState(() => used = bytes);
      ref.read(revisionProvider.notifier).refresh();
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    }
  }

  Future<void> _download(Pack pack) async {
    final prefs = ref.read(preferencesProvider);
    setState(() {
      active = pack.id;
      progress = 0;
      message = null;
      cancel = CancelDownload();
    });
    try {
      await ref
          .read(packServiceProvider)
          .download(
            pack,
            budgetBytes: prefs.budgetMb * 1024 * 1024,
            cancel: cancel!,
            progress: (v) {
              if (mounted) setState(() => progress = v);
            },
            networkAllowed: () async {
              final types = await Connectivity().checkConnectivity();
              return !types.contains(ConnectivityResult.none) &&
                  (!prefs.wifiOnly || types.contains(ConnectivityResult.wifi));
            },
          );
      if (mounted) {
        setState(() => message = 'Installed and verified: ${pack.title}');
      }
    } on PackCancelled {
      if (mounted) {
        setState(() => message = 'Paused. Download again to resume.');
      }
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted) {
        setState(() => active = null);
        await _refresh(localOnly: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final installed = ref.watch(installedProvider).asData?.value ?? [];
    final prefs = ref.watch(preferencesProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr(ref, 'downloads'),
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${sizeLabel(used)} / ${prefs.budgetMb} MB',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: active != null
                      ? null
                      : () async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Clear unused download files?'),
                              content: const Text(
                                'Remove partial downloads and old pack versions. Active installed packs are kept. Paused downloads will restart from the beginning.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(tr(ref, 'cancel')),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Clear unused files'),
                                ),
                              ],
                            ),
                          );
                          if (yes == true) {
                            try {
                              final freed = await ref
                                  .read(packServiceProvider)
                                  .clearUnused();
                              if (mounted) {
                                setState(
                                  () => message =
                                      'Freed ${sizeLabel(freed)}. Installed packs were kept.',
                                );
                              }
                              await _refresh(localOnly: true);
                            } catch (e) {
                              if (mounted) setState(() => message = '$e');
                            }
                          }
                        },
                  child: const Text(
                    'Clear partial downloads and previous versions',
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (used / (prefs.budgetMb * 1024 * 1024)).clamp(0, 1),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Optional packs, partial downloads, and retained versions. Essential handbook is bundled separately.',
                ),
              ],
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(tr(ref, 'essential')),
            subtitle: const Text(
              'Bundled · permanent · all nine languages have starter cards',
            ),
          ),
        ),
        if (message != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(message!),
            ),
          ),
        SectionTitle(tr(ref, 'installed')),
        if (installed.isEmpty) const Text('No optional packs installed.'),
        ...installed.map(
          (item) => Card(
            child: Column(
              children: [
                ListTile(
                  title: Text('${item['id']}'),
                  subtitle: Text(
                    'v${item['version']} · ${sizeLabel(item['bytes'] as int)}',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final valid = await ref
                            .read(packServiceProvider)
                            .verifyInstalled(item['path'] as String);
                        if (mounted) {
                          setState(
                            () => message = valid
                                ? 'Files verified for ${item['id']}'
                                : 'Integrity check failed. Remove and reinstall ${item['id']}.',
                          );
                        }
                      },
                      child: const Text('Verify files'),
                    ),
                    TextButton(
                      onPressed: active != null
                          ? null
                          : () async {
                              final yes = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Remove ${item['id']}?'),
                                  content: const Text(
                                    'You will need a connection to download it again. Bookmarks remain.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(tr(ref, 'cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(tr(ref, 'remove')),
                                    ),
                                  ],
                                ),
                              );
                              if (yes == true) {
                                try {
                                  await ref
                                      .read(packServiceProvider)
                                      .remove(item['id'] as String);
                                  await _refresh(localOnly: true);
                                } catch (e) {
                                  if (mounted) setState(() => message = '$e');
                                }
                              }
                            },
                      child: Text(tr(ref, 'remove')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SectionTitle(tr(ref, 'available')),
        OutlinedButton.icon(
          onPressed: active == null ? () => _refresh() : null,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh catalog (internet required)'),
        ),
        if (catalog.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No published packs are configured. The bundled handbook remains available. A maintainer can publish reviewed packs using the local guide.',
            ),
          ),
        ...catalog.map(
          (pack) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pack.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(pack.description),
                  Text(
                    '${pack.language} · ${pack.kind} · ${sizeLabel(pack.downloadBytes)} download · ${sizeLabel(pack.installedBytes)} installed',
                  ),
                  if (active == pack.id) ...[
                    LinearProgressIndicator(value: progress),
                    TextButton(
                      onPressed: () => cancel?.cancel(),
                      child: Text(tr(ref, 'cancel')),
                    ),
                  ] else
                    FilledButton(
                      onPressed: active == null ? () => _download(pack) : null,
                      child: Text(tr(ref, 'download')),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
