import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/widgets.dart';
import '../data/geocoder.dart';
import 'widgets/location_map.dart';

/// Full-screen map with a fixed centre pin: move the map, the address
/// follows. Resolves to the confirmed [PickedAddress].
Future<PickedAddress?> pickDeliveryAddress(BuildContext context, {LatLng? initial}) {
  return Navigator.of(context, rootNavigator: true).push<PickedAddress>(
    MaterialPageRoute(builder: (_) => AddressPickerScreen(initial: initial), fullscreenDialog: true),
  );
}

class AddressPickerScreen extends ConsumerStatefulWidget {
  const AddressPickerScreen({super.key, this.initial});

  final LatLng? initial;

  @override
  ConsumerState<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends ConsumerState<AddressPickerScreen> {
  final _map = MapController();
  late LatLng _center = widget.initial ?? kDefaultMapCenter;
  PickedAddress? _address;
  bool _moving = false;
  bool _resolving = false;
  bool _locating = false;
  Timer? _debounce;
  int _lookup = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _onMoved(MapCamera camera, bool hasGesture) {
    _center = camera.center;
    if (!_moving) setState(() => _moving = true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _moving = false);
      _resolve();
    });
  }

  Future<void> _resolve() async {
    final id = ++_lookup;
    setState(() => _resolving = true);
    final result = await ref.read(geocoderProvider).reverse(_center.latitude, _center.longitude);
    if (!mounted || id != _lookup) return;
    setState(() {
      _address = result;
      _resolving = false;
    });
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack((l) => l.checkoutLocationOff);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _snack((l) => l.checkoutLocationDenied);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
      _map.move(LatLng(pos.latitude, pos.longitude), 17);
    } on TimeoutException {
      _snack((l) => l.checkoutLocationFailed);
    } catch (_) {
      _snack((l) => l.checkoutLocationFailed);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _snack(String Function(AppLocalizations l) msg) {
    if (mounted) showAppSnack(context, msg(context.l10n), error: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ready = _address != null && !_moving && !_resolving;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.checkoutMapTitle)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initial == null ? 12 : 16,
              minZoom: 5,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onPositionChanged: _onMoved,
            ),
            children: [
              dizzoTileLayer(),
              const SimpleAttributionWidget(source: Text('OpenStreetMap')),
            ],
          ),
          // The pin's tip sits on the map centre.
          IgnorePointer(
            child: Center(
              child: AnimatedSlide(
                duration: Motion.fast,
                offset: Offset(0, _moving ? -0.7 : -0.5),
                child: const MapPin(size: 52),
              ),
            ),
          ),
          Positioned(
            right: Insets.lg,
            bottom: Insets.lg,
            child: FloatingActionButton(
              heroTag: null,
              tooltip: context.l10n.checkoutMyLocation,
              backgroundColor: c.surface,
              foregroundColor: c.ink,
              onPressed: _locating ? null : _locate,
              child: _locating
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: EdgeInsets.fromLTRB(context.pagePadding, Insets.lg, context.pagePadding, Insets.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place_outlined, color: c.brand),
                        Gap.sm,
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: Motion.fast,
                            child: ready
                                ? Text(
                                    _address!.address,
                                    key: ValueKey(_address!.address),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.titleSmall,
                                  )
                                : const SkeletonScope(child: Skeleton.line(width: 200, height: 14)),
                          ),
                        ),
                      ],
                    ),
                    Gap.lg,
                    AppButton(
                      label: context.l10n.checkoutConfirm,
                      onPressed: ready ? () => Navigator.of(context).pop(_address) : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
