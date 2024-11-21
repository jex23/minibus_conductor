import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapWidget extends StatefulWidget {
  final LatLng initialPosition;
  final Stream<LatLng> positionStream;
  final String collectionId;

  MapWidget({required this.initialPosition, required this.positionStream, required this.collectionId});

  @override
  _MapWidgetState createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _mapController;
  Marker? _busMarker;
  Set<Marker> _passengerMarkers = {};
  BitmapDescriptor? _customBusMarkerIcon;
  BitmapDescriptor? _customPassengerMarkerIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
    _loadPassengerMarker();
    _busMarker = Marker(
      markerId: MarkerId('busLocation'),
      position: widget.initialPosition,
      infoWindow: InfoWindow(title: 'Bus Location'),
      icon: _customBusMarkerIcon ?? BitmapDescriptor.defaultMarker,
    );

    widget.positionStream.listen((LatLng newPosition) {
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(newPosition),
        );

        setState(() {
          _busMarker = _busMarker!.copyWith(
            positionParam: newPosition,
          );
        });
      }
    });

    // Listen to Firestore updates
    _listenToPassengerUpdates();
  }

  // Load the custom marker icon for the bus
  Future<void> _loadCustomMarker() async {
    _customBusMarkerIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(48, 48)),
      'images/bus2.png',
    );

    setState(() {
      _busMarker = _busMarker?.copyWith(iconParam: _customBusMarkerIcon);
    });
  }

  // Load the custom marker for passengers
  Future<void> _loadPassengerMarker() async {
    _customPassengerMarkerIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(48, 48)),
      'images/arm-up.png',
    );
  }

  // Listen to Firestore updates for passengers
  void _listenToPassengerUpdates() {
    FirebaseFirestore.instance
        .collection('Passengers')
        .where('pickup_status', isEqualTo: 'yes') // Only listen to passengers with "yes" pickup status
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      Set<String> currentPassengerIds = _passengerMarkers.map((marker) => marker.markerId.value).toSet();

      // Add or update markers for passengers with "yes" pickup status
      snapshot.docs.forEach((doc) {
        double latitude = doc['latitude'];
        double longitude = doc['longitude'];
        String fullName = doc['fullName'];
        String docId = doc.id;
        String pickupStatus = doc['pickup_status'];

        // If the passenger's pickup_status is "yes" and not already on the map, add a marker
        if (pickupStatus == 'yes' && !currentPassengerIds.contains(docId)) {
          setState(() {
            _passengerMarkers.add(
              Marker(
                markerId: MarkerId(docId),
                position: LatLng(latitude, longitude),
                infoWindow: InfoWindow(title: fullName),
                icon: _customPassengerMarkerIcon ?? BitmapDescriptor.defaultMarker,
              ),
            );
          });
        }

        // If the pickup status is "yes", update the marker position if coordinates change
        if (pickupStatus == 'yes') {
          setState(() {
            // Remove the old marker and add a new one with updated coordinates
            _passengerMarkers.removeWhere((marker) => marker.markerId.value == docId);

            _passengerMarkers.add(
              Marker(
                markerId: MarkerId(docId),
                position: LatLng(latitude, longitude),
                infoWindow: InfoWindow(title: fullName),
                icon: _customPassengerMarkerIcon ?? BitmapDescriptor.defaultMarker,
              ),
            );
          });
        }
      });

      // Remove markers for passengers whose pickup_status is no longer "yes"
      snapshot.docs.forEach((doc) {
        String docId = doc.id;
        String pickupStatus = doc['pickup_status'];

        // Remove the marker if pickup_status is "no"
        if (pickupStatus == 'no' && currentPassengerIds.contains(docId)) {
          setState(() {
            _passengerMarkers.removeWhere((marker) => marker.markerId.value == docId);
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
      initialCameraPosition: CameraPosition(
        target: widget.initialPosition,
        zoom: 12,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      markers: {
        if (_busMarker != null) _busMarker!,
        ..._passengerMarkers, // Add all passenger markers to the map
      },
    );
  }
}
