import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;

  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng _center = const LatLng(19.0760, 72.8777);
  String _fullAddress = 'Move the pin to your location';
  String _shortAddress = 'Select location';
  bool _loadingAddress = false;
  bool _loadingGps = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _center = LatLng(widget.initialLat!, widget.initialLng!);
      if (widget.initialAddress != null) {
        _fullAddress = widget.initialAddress!;
      }
    } else {
      _detectCurrentLocation();
    }
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _loadingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _loadingGps = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _loadingGps = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _center = latLng;
        _loadingGps = false;
      });
      if (_mapReady) {
        _mapController.move(latLng, 16);
      }
      await _reverseGeocode(latLng);
    } catch (e) {
      setState(() => _loadingGps = false);
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() {
      _loadingAddress = true;
      _fullAddress = 'Fetching address...';
    });
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'shoplane-app/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addr = data['address'] as Map<String, dynamic>? ?? {};

        final short = (addr['suburb'] ??
                addr['neighbourhood'] ??
                addr['quarter'] ??
                addr['village'] ??
                addr['town'] ??
                'Current Location')
            as String;

        final parts = <String>[];
        if (addr['road'] != null) {
          parts.add(addr['road'] as String);
        }
        if (addr['suburb'] != null) {
          parts.add(addr['suburb'] as String);
        } else if (addr['neighbourhood'] != null) {
          parts.add(addr['neighbourhood'] as String);
        }
        if (addr['city'] != null) {
          parts.add(addr['city'] as String);
        } else if (addr['town'] != null) {
          parts.add(addr['town'] as String);
        }
        if (addr['state'] != null) {
          parts.add(addr['state'] as String);
        }

        setState(() {
          _shortAddress = short;
          _fullAddress =
              parts.isNotEmpty ? parts.join(', ') : data['display_name'] ?? '';
          _loadingAddress = false;
        });
      } else {
        setState(() {
          _fullAddress = 'Could not fetch address';
          _loadingAddress = false;
        });
      }
    } catch (e) {
      setState(() {
        _fullAddress = 'Could not fetch address. Check internet.';
        _loadingAddress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16.0,
              onMapReady: () {
                setState(() => _mapReady = true);
                if (_center !=
                    const LatLng(19.0760, 72.8777)) {
                  _mapController.move(_center, 16);
                }
              },
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && position.center != null) {
                  setState(() => _center = position.center!);
                }
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _reverseGeocode(_center);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.shoplane',
              ),
            ],
          ),

          // Fixed center pin — stays in middle while map moves
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_loadingAddress)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4)
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0F7B6C),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text('Locating...',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF2C2C2C))),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F7B6C),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6)
                        ],
                      ),
                      child: Text(
                        _shortAddress,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(height: 2),
                  const Icon(
                    Icons.location_pin,
                    color: Color(0xFFE85A2B),
                    size: 52,
                  ),
                  Container(
                    width: 10,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12, blurRadius: 6)
                          ],
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Color(0xFF2C2C2C), size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12, blurRadius: 6)
                          ],
                        ),
                        child: const Text(
                          'Select delivery location',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF2C2C2C)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // GPS button
          Positioned(
            right: 16,
            bottom: 210,
            child: GestureDetector(
              onTap: _detectCurrentLocation,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8)
                  ],
                ),
                child: _loadingGps
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0F7B6C),
                        ),
                      )
                    : const Icon(Icons.my_location_rounded,
                        color: Color(0xFF0F7B6C), size: 22),
              ),
            ),
          ),

          // Bottom confirm card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(context).padding.bottom + 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 16)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE85A2B)
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on_rounded,
                            color: Color(0xFFE85A2B), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _shortAddress,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF2C2C2C)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _fullAddress,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loadingAddress
                          ? null
                          : () => Navigator.pop(context, {
                                'lat': _center.latitude,
                                'lng': _center.longitude,
                                'address': _fullAddress,
                                'shortAddress': _shortAddress,
                              }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F7B6C),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _loadingAddress
                            ? 'Fetching address...'
                            : 'Confirm Location',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}