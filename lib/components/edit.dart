import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditScreen extends StatefulWidget {
  final String collectionId; // Receive collectionId from the previous screen

  EditScreen({required this.collectionId}); // Constructor to get collectionId

  @override
  _EditScreenState createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  // Text controllers for the fields we will edit
  TextEditingController _busNumberController = TextEditingController();
  TextEditingController _nameController = TextEditingController();

  // Variable for Bus Type Dropdown
  String? _selectedBusType;

  // List of bus types to show in the dropdown
  List<String> _busTypes = ['Bulan', 'Matnog'];

  // A flag to check if the data exists
  bool _dataExists = false;

  @override
  void initState() {
    super.initState();
    _loadDataFromFirestore();
  }

  // Fetch conductor data from Firestore using the collectionId
  Future<void> _loadDataFromFirestore() async {
    DocumentSnapshot conductorDoc = await FirebaseFirestore.instance
        .collection('Conductors')
        .doc(widget.collectionId)
        .get();

    if (conductorDoc.exists) {
      // If the document exists, populate the fields with the data
      var data = conductorDoc.data() as Map<String, dynamic>;
      setState(() {
        _dataExists = true;
        _busNumberController.text = data['busNumber'].toString();
        _selectedBusType = data['busType']; // Set selected bus type
        _nameController.text = data['name'];
      });
    } else {
      // If the document doesn't exist, set _dataExists to false
      setState(() {
        _dataExists = false;
      });
    }
  }

  // Function to update data in Firestore
  Future<void> _updateDataInFirestore() async {
    try {
      await FirebaseFirestore.instance
          .collection('Conductors')
          .doc(widget.collectionId)
          .update({
        'busNumber': int.parse(_busNumberController.text), // Convert to int
        'busType': _selectedBusType,
        'name': _nameController.text,
      });

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Data updated successfully!'),
      ));
    } catch (e) {
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error updating data: $e'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Information'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _dataExists
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit the information for conductor with ID: ${widget.collectionId}'),
            SizedBox(height: 20),

            // Editable text fields with the current data
            TextFormField(
              controller: _busNumberController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Bus Number'),
            ),
            SizedBox(height: 20),

            // Bus Type Dropdown
            DropdownButtonFormField<String>(
              value: _selectedBusType, // Initially selected value
              onChanged: (String? newValue) {
                setState(() {
                  _selectedBusType = newValue; // Update selected bus type
                });
              },
              decoration: InputDecoration(labelText: 'Bus Type'),
              items: _busTypes.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            SizedBox(height: 20),

            // Editable text field for conductor name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Conductor Name'),
            ),
            SizedBox(height: 20),

            // Save Button
            ElevatedButton(
              onPressed: _updateDataInFirestore,
              child: Text('Save Changes'),
            ),
          ],
        )
            : Center(
          child: Text('No data found for this conductor.'),
        ),
      ),
    );
  }
}
