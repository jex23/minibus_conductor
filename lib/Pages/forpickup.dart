import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForPickupPage extends StatefulWidget {
  final String collectionId;

  ForPickupPage({required this.collectionId});

  @override
  _ForPickupPageState createState() => _ForPickupPageState();
}

class _ForPickupPageState extends State<ForPickupPage> {
  @override
  void initState() {
    super.initState();
    _updateCheckField(); // Call to update the check field
  }

  Future<void> _updateCheckField() async {
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('For_Pick_Up')
        .where('busId', isEqualTo: widget.collectionId)
        .where('check', isEqualTo: 'False') // Update only unchecked pickups
        .get();

    for (final DocumentSnapshot document in snapshot.docs) {
      await document.reference.update({'check': 'True'}); // Update the check field
    }
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    // Update the status of the document
    await FirebaseFirestore.instance
        .collection('For_Pick_Up')
        .doc(docId)
        .update({'status': newStatus});

    // If the status is set to 'Denied', wait for 1 second, then delete the document
    if (newStatus == 'Denied') {
      await Future.delayed(Duration(seconds: 1));
      await FirebaseFirestore.instance
          .collection('For_Pick_Up')
          .doc(docId)
          .delete();
    }
  }

  Future<String?> _fetchFullName(String uid) async {
    // Fetch the fullName from the Passengers collection using the uid
    final DocumentSnapshot passengerDoc = await FirebaseFirestore.instance
        .collection('Passengers')
        .doc(uid)
        .get();

    if (passengerDoc.exists) {
      final data = passengerDoc.data() as Map<String, dynamic>;
      return data['fullName'] ?? 'N/A'; // Return the fullName or 'N/A' if not found
    }
    return null; // Return null if the document doesn't exist
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('For Pickup'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('For_Pick_Up')
            .where('busId', isEqualTo: widget.collectionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No pickups available for this bus.'));
          }

          return ListView(
            children: snapshot.data!.docs.map((document) {
              final data = document.data() as Map<String, dynamic>;
              final uid = data['uid']; // Get the uid

              return Card(
                margin: EdgeInsets.all(10),
                child: ListTile(
                  title: FutureBuilder<String?>(
                    future: _fetchFullName(uid), // Fetch fullName using uid
                    builder: (context, nameSnapshot) {
                      if (nameSnapshot.connectionState == ConnectionState.waiting) {
                        return Text('Loading name...');
                      }
                      if (nameSnapshot.hasError) {
                        return Text('Error: ${nameSnapshot.error}');
                      }
                      return Text(
                        'Name: ${nameSnapshot.data ?? 'N/A'}',
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Destination: ${data['destination'] ?? 'N/A'}'),
                      Text('Distance: ${data['distance'] ?? 'N/A'} km'),
                      Text('Fare: ₱${data['fare']?.toStringAsFixed(2) ?? 'N/A'}'),
                      Text('Status: ${data['status'] ?? 'N/A'}'),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () => _updateStatus(document.id, 'Accepted'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            child: Text('Accept'),
                          ),
                          SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => _updateStatus(document.id, 'Denied'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            child: Text('Deny'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
