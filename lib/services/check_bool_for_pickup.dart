import 'package:cloud_firestore/cloud_firestore.dart';

class CheckBoolForPickup {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<int> countUncheckedPickups(String collectionId) async {
    QuerySnapshot querySnapshot = await _firestore
        .collection("For_Pick_Up")
        .where("check", isEqualTo: "False")
        .where("busId", isEqualTo: collectionId) // Updated parameter
        .get();

    return querySnapshot.docs.length; // Count the documents
  }
}
