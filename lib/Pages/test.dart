import 'dart:async';
import 'dart:convert'; // For JSON parsing
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Maps Routes Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MapsRoutesExample(title: 'GMR Demo Home'),
    );
  }
}

class MapsRoutesExample extends StatefulWidget {
  MapsRoutesExample({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MapsRoutesExampleState createState() => _MapsRoutesExampleState();
}

class _MapsRoutesExampleState extends State<MapsRoutesExample> {
  Completer<GoogleMapController> _controller = Completer();

  LatLng? startLocation;
  LatLng? destinationLocation;

  String startAddress = '';
  String destinationAddress = '';

  String googleApiKey = 'AIzaSyBly05xJh1T5SndGug6XBzDNZ6c94qAJL4'; // Replace with your actual API key
  String totalDistance = 'No route';
  Set<Polyline> polylines = {}; // Set to store polylines

  @override
  void initState() {
    super.initState();
    getInitialCoordinates(); // Get initial coordinates on startup
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: GoogleMap(
              zoomControlsEnabled: false,
              polylines: polylines, // Include polylines in the map
              initialCameraPosition: const CameraPosition(
                zoom: 15.0,
                target: LatLng(45.82917150748776, 14.63705454546316), // Initial position until geocoding is done
              ),
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  // Start Address Input
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      onChanged: (value) {
                        startAddress = value;
                      },
                      decoration: InputDecoration(
                        labelText: 'Start Address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  // Destination Address Input
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      onChanged: (value) {
                        destinationAddress = value;
                      },
                      decoration: InputDecoration(
                        labelText: 'Destination Address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  // Calculate Route Button
                  ElevatedButton(
                    onPressed: () async {
                      await getCoordinates();
                    },
                    child: Text('Calculate Route'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 200,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    totalDistance,
                    style: TextStyle(fontSize: 25.0),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () async {
              await getRoute();
            },
            child: Icon(Icons.directions),
          ),
          SizedBox(height: 16), // Spacing between buttons
          FloatingActionButton(
            onPressed: () async {
              if (startLocation != null) {
                GoogleMapController controller = await _controller.future;
                // Reset the map camera to the initial start location with zoom level 16
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: startLocation!, // Recenter to the geocoded start location
                      zoom: 16, // Zoom level
                    ),
                  ),
                );
              }
            },
            child: Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Future<void> getCoordinates() async {
    try {
      List<Location> startLocations = await locationFromAddress(startAddress);
      List<Location> destinationLocations = await locationFromAddress(destinationAddress);

      if (startLocations.isNotEmpty && destinationLocations.isNotEmpty) {
        setState(() {
          startLocation = LatLng(startLocations.first.latitude, startLocations.first.longitude);
          destinationLocation = LatLng(destinationLocations.first.latitude, destinationLocations.first.longitude);
          totalDistance = 'Coordinates fetched: Start - $startLocation, Destination - $destinationLocation';
        });

        // Move the camera to the start location after fetching coordinates
        GoogleMapController controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: startLocation!,
              zoom: 16, // Set the desired zoom level
            ),
          ),
        );
      } else {
        setState(() {
          totalDistance = 'Could not fetch coordinates.';
        });
      }
    } catch (e) {
      print('Error fetching coordinates: $e');
      setState(() {
        totalDistance = 'Error: $e';
      });
    }
  }

  Future<void> getRoute() async {
    if (startLocation == null || destinationLocation == null) return;

    // Build the URL for the Directions API
    String url = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${startLocation!.latitude},${startLocation!.longitude}'
        '&destination=${destinationLocation!.latitude},${destinationLocation!.longitude}'
        '&key=$googleApiKey&mode=driving';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Check for routes in the response
        if (data['routes'].isNotEmpty) {
          // Get the polyline points
          String encodedPolyline = data['routes'][0]['overview_polyline']['points'];
          List<LatLng> polylinePoints = decodePolyline(encodedPolyline);

          setState(() {
            polylines.add(
              Polyline(
                polylineId: PolylineId('route'),
                points: polylinePoints,
                color: Colors.blue,
                width: 5,
              ),
            );

            // Get the distance in meters and convert to kilometers
            totalDistance = '${(data['routes'][0]['legs'][0]['distance']['value'] / 1000).toStringAsFixed(2)} km';
          });

          // Move the camera to the start location after fetching the route
          GoogleMapController controller = await _controller.future;
          controller.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(
                  data['routes'][0]['legs'][0]['start_location']['lat'],
                  data['routes'][0]['legs'][0]['start_location']['lng'],
                ),
                northeast: LatLng(
                  data['routes'][0]['legs'][0]['end_location']['lat'],
                  data['routes'][0]['legs'][0]['end_location']['lng'],
                ),
              ),
              100.0, // Padding around the bounds
            ),
          );
        } else {
          setState(() {
            totalDistance = 'No route found';
          });
        }
      } else {
        setState(() {
          totalDistance = 'Error fetching route: ${response.reasonPhrase}';
        });
      }
    } catch (e) {
      print('Error fetching route: $e');
      setState(() {
        totalDistance = 'Error: $e';
      });
    }
  }

  List<LatLng> decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> getInitialCoordinates() async {
    // Initial coordinates to focus the map
    startLocation = LatLng(45.82917150748776, 14.63705454546316);
    destinationLocation = LatLng(45.82917150748776, 14.63705454546316);
  }
}
