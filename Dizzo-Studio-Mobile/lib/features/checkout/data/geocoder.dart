import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_language.dart';

/// A picked delivery point with its readable address.
class PickedAddress {
  const PickedAddress({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.city = '',
    this.state = '',
  });

  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String state;
}

/// Reverse geocoding with OpenStreetMap Nominatim, as the web does (no API
/// key). Nominatim asks for an identifying User-Agent and at most one
/// request per second; the picker only asks when the map stops moving.
class Geocoder {
  Geocoder([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://nominatim.openstreetmap.org',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'User-Agent': 'Dizzo/1.0 (uz.dizzo.studio; dizzo.uz)'},
            ));

  final Dio _dio;

  /// Falls back to "lat, lon" when the lookup fails.
  Future<PickedAddress> reverse(double lat, double lon, {String city = 'Toshkent', String state = 'Toshkent'}) async {
    final fallback = PickedAddress(
      latitude: lat,
      longitude: lon,
      address: '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
      city: city,
      state: state,
    );
    try {
      final res = await _dio.get<Object?>('/reverse', queryParameters: {
        'format': 'jsonv2',
        'lat': lat,
        'lon': lon,
        'accept-language': AppLanguage.current.code,
      });
      final data = res.data;
      if (data is! Map) return fallback;
      final a = data['address'] is Map ? data['address'] as Map : const {};
      String s(Object? v) => v is String ? v : '';
      final street = [s(a['road']), s(a['house_number'])].where((p) => p.isNotEmpty).join(' ');
      final display = s(data['display_name']);
      return PickedAddress(
        latitude: lat,
        longitude: lon,
        address: street.isNotEmpty ? street : (display.isNotEmpty ? display : fallback.address),
        city: [s(a['city']), s(a['town']), s(a['county'])].firstWhere((v) => v.isNotEmpty, orElse: () => city),
        state: [s(a['state']), s(a['region'])].firstWhere((v) => v.isNotEmpty, orElse: () => state),
      );
    } catch (_) {
      return fallback;
    }
  }
}

final geocoderProvider = Provider<Geocoder>((ref) => Geocoder());
