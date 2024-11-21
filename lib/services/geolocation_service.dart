import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class GeolocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Position?> getCurrentLocation() async {
    var permissionStatus = await Permission.location.request();

    if (permissionStatus.isGranted) {
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } else {
      return null;
    }
  }

  Future<List<Placemark>> getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      return placemarks; // Return the fetched placemarks
    } catch (e) {
      print("Error fetching address: $e");
      return []; // Return an empty list instead of null
    }
  }

  // Add location change listener
  void listenToLocationChanges(String collectionId, Function(String) onLocationUpdate) {
    LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
      if (position != null) {
        Map<String, dynamic> locationData = {
          'busLocation': {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
          'timestamp': FieldValue.serverTimestamp(),
        };

        // Update Firestore with the latitude and longitude
        await _firestore.collection('Conductors').doc(collectionId).update(locationData);

        // Fetch the new address based on the updated position
        List<Placemark> placemarks = await getAddressFromLatLng(position);
        if (placemarks.isNotEmpty) {
          String address = 'Location: ${placemarks.first.name}, ${placemarks.first.locality}';

          // Update Firestore with the geocoded address
          await _firestore.collection('Conductors').doc(collectionId).update({
            'address': address,
          });

          onLocationUpdate(address);
        } else {
          onLocationUpdate('Could not find address');
        }
      }
    });
  }
}
