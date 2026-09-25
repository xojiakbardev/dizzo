import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/widgets.dart';

/// Toshkent, where the map opens without a saved point (as on the web).
const kDefaultMapCenter = LatLng(41.311081, 69.240562);

/// OpenStreetMap tiles, as the web's DeliveryAddressMap uses (no API key).
///
/// TODO(owner): OSM's public tile servers are for light use only
/// (https://operations.osmfoundation.org/policies/tiles/). Before a large
/// rollout switch [urlTemplate] to a commercial tile provider (MapTiler,
/// Stadia, Mapbox…) and pass its key via --dart-define.
TileLayer dizzoTileLayer() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'uz.dizzo.studio',
      maxZoom: 19,
    );

/// The map pin.
class MapPin extends StatelessWidget {
  const MapPin({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Icon(
      Icons.location_on_rounded,
      size: size,
      color: c.brandStrong,
      shadows: const [Shadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2))],
    );
  }
}

/// A small, non-interactive map with a pin (checkout, order details).
class LocationPreview extends StatelessWidget {
  const LocationPreview({super.key, required this.point, this.height = 140, this.onTap});

  final LatLng point;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: Radii.brMd,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            IgnorePointer(
              child: FlutterMap(
                key: ValueKey(point),
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  dizzoTileLayer(),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const MapPin(size: 40),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(onTap: onTap),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
