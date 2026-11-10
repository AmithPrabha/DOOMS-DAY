import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path/path.dart' as p;
import '../core/models.dart';
import '../core/providers.dart';
import '../services/navigation.dart';
import 'handbook.dart';
import '../widgets/compass_dial.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  late final NavigationService navigation;
  Position? position;
  String? error, style, selected;
  MapLibreMapController? map;
  bool locating = false;
  LatLng initialCenter = const LatLng(0, 0);
  double initialZoom = 2;
  List<SavedPlace> places = [];
  List<Map<String, Object?>> maps = [];
  Stream<CompassReading>? compass;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    navigation = ref.read(navigationProvider);
    compass = navigation.compass;
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(
        () => compass = state == AppLifecycleState.resumed
            ? navigation.compass
            : const Stream<CompassReading>.empty(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await ref.read(databaseProvider).places();
    final installed = (await ref.read(databaseProvider).installedPacks())
        .where((e) => e['kind'] == 'map')
        .toList();
    if (!mounted) return;
    setState(() {
      places = saved;
      maps = installed;
    });
    if (installed.isNotEmpty && selected == null) {
      await _select(installed.first);
    }
  }

  Future<void> _select(Map<String, Object?> pack) async {
    try {
      final root = pack['path'] as String;
      final manifest = jsonDecode(
        await File(p.join(root, 'manifest.json')).readAsString(),
      );
      if (!await ref.read(packServiceProvider).verifyInstalled(root)) {
        throw StateError('Map integrity check failed. Reinstall this pack.');
      }
      final j =
          jsonDecode(await File(p.join(root, 'style.json')).readAsString())
              as Map<String, dynamic>;
      for (final source in (j['sources'] as Map).values) {
        source['url'] = 'pmtiles://${Uri.file(p.join(root, 'map.pmtiles'))}';
      }
      if (j.containsKey('glyphs')) {
        j['glyphs'] = '${Uri.directory(root)}glyphs/{fontstack}/{range}.pbf';
      }
      if (j.containsKey('sprite')) {
        j['sprite'] = '${Uri.directory(root)}sprites/sprite';
      }
      final bounds = manifest['bounds'] as List?;
      if (mounted) {
        setState(() {
          if (bounds != null && bounds.length == 4) {
            initialCenter = LatLng(
              ((bounds[1] as num) + (bounds[3] as num)) / 2,
              ((bounds[0] as num) + (bounds[2] as num)) / 2,
            );
            initialZoom = ((manifest['max_zoom'] as num?)?.toDouble() ?? 10)
                .clamp(2, 10);
          }
          selected = pack['id'] as String;
          style = jsonEncode(j);
          error = null;
        });
      }
      if (bounds != null && bounds.length == 4) {
        await map?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(
              ((bounds[1] as num) + (bounds[3] as num)) / 2,
              ((bounds[0] as num) + (bounds[2] as num)) / 2,
            ),
            10,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          style = null;
        });
      }
    }
  }

  Future<void> _locate() async {
    setState(() {
      locating = true;
      error = null;
    });
    try {
      final fix = await navigation.locate();
      if (!mounted) return;
      setState(() => position = fix);
      await map?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(fix.latitude, fix.longitude), 13),
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> _savePlace() async {
    final name = TextEditingController();
    final lat = TextEditingController(
      text: position?.latitude.toStringAsFixed(6),
    );
    final lon = TextEditingController(
      text: position?.longitude.toStringAsFixed(6),
    );
    String? formError;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(tr(ref, 'save_place')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: lat,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
                TextField(
                  controller: lon,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
                if (formError != null) Text(formError!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(ref, 'cancel')),
            ),
            FilledButton(
              onPressed: () {
                final a = double.tryParse(lat.text),
                    b = double.tryParse(lon.text);
                if (name.text.trim().isEmpty ||
                    a == null ||
                    b == null ||
                    !a.isFinite ||
                    !b.isFinite ||
                    a.abs() > 90 ||
                    b.abs() > 180) {
                  update(
                    () => formError = 'Enter a name and valid coordinates.',
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      await ref
          .read(databaseProvider)
          .savePlace(name.text, double.parse(lat.text), double.parse(lon.text));
      await _load();
    }
    name.dispose();
    lat.dispose();
    lon.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        tr(ref, 'map'),
        style: Theme.of(
          context,
        ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 16),
      if (maps.isNotEmpty)
        DropdownButton<String>(
          isExpanded: true,
          value: maps.any((m) => m['id'] == selected) ? selected : null,
          hint: const Text('Select installed region'),
          items: maps
              .map(
                (m) => DropdownMenuItem(
                  value: m['id'] as String,
                  child: Text(m['id'] as String),
                ),
              )
              .toList(),
          onChanged: (id) => _select(maps.firstWhere((m) => m['id'] == id)),
        ),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: style == null ? null : 300,
          child: style == null
              ? Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.all(24),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 58),
                      SizedBox(height: 14),
                      Text(
                        'No verified offline map loaded',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Install a regional map pack from Downloads. Compass and saved coordinates work independently.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : MapLibreMap(
                  key: ValueKey(style),
                  styleString: style!,
                  initialCameraPosition: CameraPosition(
                    target: initialCenter,
                    zoom: initialZoom,
                  ),
                  onMapCreated: (controller) => map = controller,
                  myLocationEnabled: position != null,
                  compassEnabled: false,
                ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'Downloaded maps do not show live road closures or facility availability.',
        ),
      ),
      if (error != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(error!),
          ),
        ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: locating ? null : _locate,
            icon: const Icon(Icons.my_location),
            label: Text(locating ? 'Locating…' : tr(ref, 'locate')),
          ),
          OutlinedButton.icon(
            onPressed: _savePlace,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(tr(ref, 'save_place')),
          ),
        ],
      ),
      if (position != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SelectableText(
            '${position!.latitude.toStringAsFixed(6)}, ${position!.longitude.toStringAsFixed(6)}\n'
            'Accuracy ±${position!.accuracy.toStringAsFixed(0)} m · fix ${position!.timestamp.toLocal()}\n'
            'Position may become stale; tap Locate to refresh.',
          ),
        ),
      SectionTitle(tr(ref, 'compass')),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: StreamBuilder<CompassReading>(
            key: ValueKey(compass),
            stream: compass,
            builder: (context, snapshot) {
              final heading = snapshot.data?.heading;
              return Column(
                children: [
                  CompassDial(
                    heading: snapshot.hasError ? null : heading,
                    unreliable:
                        snapshot.data?.unreliable == true ||
                        (snapshot.data?.accuracy ?? 0) > 45,
                    magneticLabel: tr(ref, 'magnetic'),
                    unavailableLabel: tr(ref, 'compass_unavailable'),
                    unreliableLabel: tr(ref, 'compass_unreliable'),
                  ),
                  Text(tr(ref, 'compass_advice')),
                ],
              );
            },
          ),
        ),
      ),
      const SectionTitle('Saved places'),
      ...places.map(
        (place) => Card(
          child: ListTile(
            title: Text(place.name),
            subtitle: Text(
              '${place.latitude.toStringAsFixed(5)}, ${place.longitude.toStringAsFixed(5)}'
              '${position == null ? '' : '\n${(NavigationService.distance(position!.latitude, position!.longitude, place.latitude, place.longitude) / 1000).toStringAsFixed(2)} km · ${NavigationService.bearing(position!.latitude, position!.longitude, place.latitude, place.longitude).toStringAsFixed(0)}° true bearing (straight line)'}',
            ),
            onTap: () => map?.animateCamera(
              CameraUpdate.newLatLng(LatLng(place.latitude, place.longitude)),
            ),
            trailing: IconButton(
              tooltip: 'Delete saved place',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await ref.read(databaseProvider).deletePlace(place.id);
                await _load();
              },
            ),
          ),
        ),
      ),
    ],
  );
}
