import 'package:flutter/material.dart';
import 'package:minibus_conductor/Pages/Login.dart';
import 'package:minibus_conductor/components/edit.dart'; // Import the EditScreen

class Sidebar extends StatelessWidget {
  final String userName; // Accept the user's name as a parameter
  final String collectionId; // Accept the collectionId as a parameter

  Sidebar({required this.userName, required this.collectionId}); // Constructor to initialize values

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $userName', // Display the user's name
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Collection ID: $collectionId', // Optionally display the collectionId
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          // Replacing old ListTile entries with "Update Info"
          ListTile(
            leading: Icon(Icons.edit),
            title: Text('Update Info'),
            onTap: () {
              // Navigate to the EditScreen and pass the collectionId
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditScreen(collectionId: collectionId), // Pass collectionId
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
            onTap: () {
              // Navigate to the login screen by popping all previous routes
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => Login()),
                    (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
