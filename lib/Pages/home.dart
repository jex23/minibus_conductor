import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:minibus_conductor/services/geolocation_service.dart';
import 'package:minibus_conductor/services/map_page.dart';
import 'package:minibus_conductor/components/sidebar.dart'; // Import the sidebar component
import 'package:minibus_conductor/components/draggable_sheet.dart'; // Import the draggable sheet component
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:minibus_conductor/Pages/messages.dart';
import 'package:minibus_conductor/Pages/forpickup.dart';
import 'package:minibus_conductor/services/check_bool_for_pickup.dart';
import 'package:badges/badges.dart' as badges;

class Home extends StatefulWidget {
  final String userName;
  final String collectionId;

  Home({required this.userName, required this.collectionId});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final GeolocationService _geoService = GeolocationService();
  String _locationMessage = 'Fetching location...';
  LatLng _initialPosition = LatLng(0, 0); // Default location until fetched
  StreamController<LatLng> _positionStreamController = StreamController<LatLng>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // GlobalKey for Scaffold

  // Dropdown menu related state
  bool _isDropdownVisible = false; // State variable to toggle dropdown visibility
  String? _selectedRoute; // Variable to store the selected route
  List<String> _routes = []; // Initialize with empty routes

  // Placeholder data for seat selection
  List<int> _availableSeats = List.generate(28, (index) => index); // Available seat numbers
  List<int> _occupiedSeats = []; // Occupied seat numbers
  int? _seatSelected; // Store selected seat number
  int availableSeatCount = 0; // To hold the count of available seats
  int occupiedSeatCount = 0; // To hold the count of occupied seats
  int pickupCount = 5; // Example count, you can replace it with your dynamic count
  int messageCount = 2; // Initialize message count

  @override
  void initState() {
    super.initState();
    _getLocationAndAddress();
    _geoService.listenToLocationChanges(widget.collectionId, _handleLocationUpdate);
    _fetchBusType(); // Fetch bus type from Firestore
    _fetchSeatsFromFirestore(); // Fetch seat data from Firestore
    _fetchPickupCount();
    _fetchMessageCount(); // Fetch message count
  }

  void _fetchPickupCount() {
    FirebaseFirestore.instance
        .collection("For_Pick_Up")
        .where("check", isEqualTo: "False") // Filter for unchecked pickups
        .where("busId", isEqualTo: widget.collectionId) // Use provided collectionId
        .snapshots() // Listen for real-time updates
        .listen((QuerySnapshot querySnapshot) {
      setState(() {
        pickupCount = querySnapshot.docs.length; // Update the pickup count state
      });
    });
  }

  void _fetchMessageCount() {
    FirebaseFirestore.instance
        .collection("Messages")
        .where("busId", isEqualTo: widget.collectionId) // Use provided collectionId
        .where("check", isEqualTo: "False") // Filter for unchecked messages
        .snapshots() // Listen for real-time updates
        .listen((QuerySnapshot querySnapshot) {
      setState(() {
        messageCount = querySnapshot.docs.length; // Update the message count state
      });
    });
  }

  Future<void> _fetchSeatsFromFirestore() async {
    try {
      DocumentSnapshot conductorDoc = await FirebaseFirestore.instance.collection('Conductors').doc(widget.collectionId).get();
      if (conductorDoc.exists) {
        setState(() {
          // Populate seat data from Firestore fields
          _availableSeats = List<int>.from(conductorDoc['availableSeats'] ?? []);
          _occupiedSeats = List<int>.from(conductorDoc['occupiedSeats'] ?? []);
        });
      }
    } catch (e) {
      print('Error fetching seats from Firestore: $e');
    }
  }

  Future<void> _fetchBusType() async {
    try {
      DocumentSnapshot conductorDoc = await FirebaseFirestore.instance.collection('Conductors').doc(widget.collectionId).get();
      String busType = conductorDoc['busType']; // Get busType from document

      setState(() {
        if (busType == "Bulan") {
          _routes = ["Bulan to Sorsogon", "Sorsogon to Bulan"];
        } else if (busType == "Matnog") {
          _routes = ["Matnog to Sorsogon", "Sorsogon to Matnog"];
        } else {
          _routes = []; // Default or empty routes if busType is unknown
        }
      });
    } catch (e) {
      print('Error fetching bus type: $e');
    }
  }

  Future<void> _getLocationAndAddress() async {
    Position? position = await _geoService.getCurrentLocation();
    if (position != null) {
      List<Placemark> placemarks = await _geoService.getAddressFromLatLng(position);
      if (placemarks.isNotEmpty) {
        setState(() {
          _locationMessage = 'Location: ${placemarks.first.name}, ${placemarks.first.locality}';
          _initialPosition = LatLng(position.latitude, position.longitude); // Set initial position for map
          _positionStreamController.add(_initialPosition); // Send the initial position to the map
        });
      } else {
        setState(() {
          _locationMessage = 'Could not find address';
        });
      }
    } else {
      setState(() {
        _locationMessage = 'Location permission denied';
      });
    }
  }

  // Callback to update location message and stream to the map
  void _handleLocationUpdate(String address) async {
    setState(() {
      _locationMessage = address;
    });

    Position? newPosition = await _geoService.getCurrentLocation();
    if (newPosition != null) {
      LatLng updatedPosition = LatLng(newPosition.latitude, newPosition.longitude);
      _positionStreamController.add(updatedPosition); // Send updated position to the map
    }
  }

  @override
  void dispose() {
    _positionStreamController.close(); // Close stream when widget is disposed
    super.dispose();
  }

  void _recenterMap() {
    // Recenter the map to the initial position
    _positionStreamController.add(_initialPosition);
  }

  // Function to update Firestore with available and occupied seats
  Future<void> _updateSeatsInFirestore() async {
    try {
      CollectionReference conductors = FirebaseFirestore.instance.collection('Conductors');
      await conductors.doc(widget.collectionId).set({
        'availableSeats': _availableSeats,
        'occupiedSeats': _occupiedSeats,
      }, SetOptions(merge: true)); // Merge true to avoid overwriting existing fields

      // Update counts after Firestore update
      availableSeatCount = _availableSeats.length; // Count of available seats
      occupiedSeatCount = _occupiedSeats.length;   // Count of occupied seats

      print('Seats updated in Firestore successfully');
    } catch (e) {
      print('Error updating seats in Firestore: $e');
    }
  }

  // Function to send selected route to Firestore
  Future<void> _sendRouteToFirestore(String route) async {
    try {
      CollectionReference conductors = FirebaseFirestore.instance.collection('Conductors');
      await conductors.doc(widget.collectionId).set({
        'selectedRoute': route, // Store the selected route
      }, SetOptions(merge: true)); // Merge true to avoid overwriting existing fields
      print('Route sent to Firestore successfully');
    } catch (e) {
      print('Error sending route to Firestore: $e');
    }
  }

  // Callback for handling seat selection
  void _onSeatTapped(int seatNumber) {
    setState(() {
      // Move seat between available and occupied based on selection
      if (_availableSeats.contains(seatNumber)) {
        _availableSeats.remove(seatNumber);
        _occupiedSeats.add(seatNumber);
      } else if (_occupiedSeats.contains(seatNumber)) {
        _occupiedSeats.remove(seatNumber);
        _availableSeats.add(seatNumber);
      }
      _seatSelected = seatNumber; // Set the selected seat

      // Update counts after selection change
      availableSeatCount = _availableSeats.length; // Count of available seats
      occupiedSeatCount = _occupiedSeats.length;   // Count of occupied seats
    });
    _updateSeatsInFirestore(); // Call the function to update Firestore
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, // Use scaffold key for controlling the drawer
      drawer: Sidebar(userName: widget.userName, collectionId: widget.collectionId), // Pass userName and collectionId to Sidebar
      body: Stack(
        children: [
          // Fullscreen Google Map with position stream
          Positioned.fill(
            child: MapWidget(
              initialPosition: _initialPosition,
              positionStream: _positionStreamController.stream, // Pass position updates to map
              collectionId: widget.collectionId, // Pass collectionId to MapWidget
            ),
          ),

          // Location card overlay at the top of the screen
          Positioned(
            top: 100, // Adjust this value as necessary for padding from the top
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              color: Colors.white.withOpacity(0.8), // Slight transparency to show map behind
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  _locationMessage,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // Route card overlay below the location card
          Positioned(
            top: 150, // Position below the location card
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              color: Colors.white.withOpacity(0.8), // Slight transparency
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedRoute ?? 'No route selected', // Display selected route or default message
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Recenter button below the card
          Positioned(
            top: 50, // Position just below the card
            right: 16, // Align to the right
            child: FloatingActionButton(
              onPressed: _recenterMap,
              child: Icon(Icons.my_location), // Use location icon
              mini: true, // Smaller size to fit below the card
              backgroundColor: Colors.orangeAccent,
            ),
          ),

          // Sidebar button (hamburger menu) below the location card
          Positioned(
            top: 51, // Adjust this value as necessary for padding below the card
            left: 10, // Align to the left
            child: FloatingActionButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(), // Open drawer when tapped
              child: Icon(Icons.menu), // Hamburger icon
              mini: true, // Smaller size to fit below the card
              backgroundColor: Colors.orangeAccent, // Optional color for visibility
            ),
          ),

          // Messages button with badge
          Positioned(
            top: 51,
            left: 70,
            child: Stack(
              alignment: Alignment.center, // Center the badge on the button
              children: [
                FloatingActionButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MessagesPage(collectionId: widget.collectionId),
                    ),
                  ),
                  child: Icon(Icons.message),
                  mini: true,
                  backgroundColor: Colors.orangeAccent,
                ),
                Positioned(
                  top: -5,
                  right: 10,
                  child: badges.Badge(
                    showBadge: messageCount > 0, // Show badge only if count > 0
                    badgeContent: Text(
                      '$messageCount', // Display the badge count
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // For Pickup button
          Align(
            alignment: Alignment.topCenter, // Aligns the widget horizontally centered, but keeps it at the top
            child: Padding(
              padding: const EdgeInsets.only(top: 50), // Adjust the vertical position
              child: Stack(
                alignment: Alignment.center, // Center aligns the badge with the button
                children: [
                  // Floating Action Button
                  SizedBox(
                    height: 40,
                    child: FloatingActionButton.extended(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ForPickupPage(collectionId: widget.collectionId),
                        ),
                      ),
                      label: Text("For Pick Up", style: TextStyle(fontSize: 10)),
                      backgroundColor: Colors.orangeAccent,
                      icon: Icon(Icons.people_alt_rounded, size: 16),
                    ),
                  ),
                  // Badge on top of the button
                  Positioned(
                    top: -5, // Adjust this value for badge position
                    right: 10, // Adjust this value for badge position
                    child: badges.Badge(
                      showBadge: pickupCount > 0, // Show badge only if count > 0
                      badgeContent: Text(
                        '$pickupCount', // Display the badge count
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Route selection dropdown button
          Positioned(
            top: 50, // Adjust this position as needed
            right: 70, // Align to the right
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isDropdownVisible = !_isDropdownVisible; // Toggle dropdown visibility
                });
              },
              child: Icon(Icons.arrow_drop_down), // Dropdown arrow icon
              mini: true, // Smaller size to fit below the card
              backgroundColor: Colors.orangeAccent, // Optional color for visibility
            ),
          ),

          // Dropdown menu
          if (_isDropdownVisible) ...[
            Positioned(
              top: 300, // Adjust based on the dropdown height and previous widget position
              left: 10,
              right: 10,
              child: Card(
                elevation: 4,
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _routes.map((route) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRoute = route; // Update selected route
                          _isDropdownVisible = false; // Close dropdown
                        });
                        _sendRouteToFirestore(route); // Send selected route to Firestore
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Text(
                          route,
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          // Draggable sheet component for seat selection
          DraggableSheet(
            availableSeats: _availableSeats, // Provide available seats
            occupiedSeats: _occupiedSeats, // Provide occupied seats
            onSeatTapped: _onSeatTapped, // Pass the seat tapped callback
            seatSelected: _seatSelected, // Pass the selected seat
          ),
        ],
      ),
    );
  }
}
