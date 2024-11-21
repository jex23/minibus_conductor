import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MessagesPage extends StatefulWidget {
  final String collectionId;

  MessagesPage({required this.collectionId});

  @override
  _MessagesPageState createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  Map<String, String> _passengerNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPassengerDetails();
  }

  Future<void> _fetchPassengerDetails() async {
    final passengersSnapshot = await FirebaseFirestore.instance.collection('Passengers').get();
    final passengerData = passengersSnapshot.docs;

    setState(() {
      _passengerNames = {
        for (var doc in passengerData) doc.id: doc.data()['fullName'] ?? 'Unknown Name',
      };
      _isLoading = false;
    });
  }

  Future<Map<String, dynamic>> _getSessionData(DocumentSnapshot sessionDoc) async {
    final sessionId = sessionDoc.id;
    final uid = sessionDoc['uid'] ?? 'Unknown UID';
    final checkStatus = sessionDoc['check'] ?? 'False';
    final fullName = _passengerNames[uid] ?? 'Unknown Name';

    final lastMessageSnapshot = await FirebaseFirestore.instance
        .collection('Messages')
        .doc(sessionId)
        .collection('chatMessages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    Timestamp? lastTimestamp;
    if (lastMessageSnapshot.docs.isNotEmpty) {
      lastTimestamp = lastMessageSnapshot.docs.first['timestamp'];
    }
    return {
      'sessionId': sessionId,
      'uid': uid,
      'checkStatus': checkStatus,
      'fullName': fullName,
      'lastTimestamp': lastTimestamp,
    };
  }

  Future<void> _updateCheckStatus(DocumentReference messageRef, String currentCheck) async {
    if (currentCheck == "False") {
      await messageRef.update({'check': "True"});
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return "No messages yet";
    }
    return DateFormat('MM/dd/yyyy hh:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Messages')
            .where('busId', isEqualTo: widget.collectionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No messages found.'));
          }

          final sessions = snapshot.data!.docs;

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Future.wait(sessions.map(_getSessionData)),
            builder: (context, sessionSnapshots) {
              if (!sessionSnapshots.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final sessionDataList = sessionSnapshots.data!;
              sessionDataList.sort((a, b) {
                final timestampA = a['lastTimestamp'] as Timestamp?;
                final timestampB = b['lastTimestamp'] as Timestamp?;
                if (timestampA == null && timestampB == null) return 0;
                if (timestampA == null) return 1;
                if (timestampB == null) return -1;
                return timestampB.compareTo(timestampA);
              });

              return ListView.builder(
                itemCount: sessionDataList.length,
                itemBuilder: (context, index) {
                  final sessionData = sessionDataList[index];
                  final sessionId = sessionData['sessionId'];
                  final uid = sessionData['uid'];
                  final checkStatus = sessionData['checkStatus'];
                  final fullName = sessionData['fullName'];
                  final lastTimestamp = sessionData['lastTimestamp'];
                  final formattedTime = _formatTimestamp(lastTimestamp);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ConversationPage(busId: widget.collectionId, uid: uid),
                        ),
                      );
                      _updateCheckStatus(FirebaseFirestore.instance.collection('Messages').doc(sessionId), checkStatus);
                    },
                    child: Card(
                      color: checkStatus == "False" ? Colors.blue[100] : Colors.white,
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            fullName.isNotEmpty ? fullName[0] : '?',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                        title: Text(fullName),
                        subtitle: Text(formattedTime), // Displaying the formatted timestamp
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ConversationPage extends StatefulWidget {
  final String busId;
  final String uid;

  ConversationPage({required this.busId, required this.uid});

  @override
  _ConversationPageState createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = "${widget.busId}_${widget.uid}";
    _initializeChatSession();
  }

  void _initializeChatSession() async {
    DocumentReference chatSessionRef = _firestore.collection('Messages').doc(_sessionId);
    DocumentSnapshot chatDoc = await chatSessionRef.get();

    if (!chatDoc.exists) {
      await chatSessionRef.set({
        'uid': widget.uid,
        'busId': widget.busId,
        'check': "False",
      });
    }
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      CollectionReference chatMessagesRef = _firestore.collection('Messages').doc(_sessionId).collection('chatMessages');
      String sender = widget.uid == "PassengerID" ? "Passenger" : "Conductor";

      chatMessagesRef.add({
        'uid': widget.uid,
        'busId': widget.busId,
        'message': _messageController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'sender': sender,
      });
      _messageController.clear();
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return "Just now";
    }
    return DateFormat('MM/dd/yyyy hh:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('Messages')
                  .doc(_sessionId)
                  .collection('chatMessages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No messages yet.'));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index];
                    Timestamp? timestamp = messageData['timestamp'] as Timestamp?;
                    String formattedTime = _formatTimestamp(timestamp);
                    final sender = messageData['sender'];
                    bool isPassenger = sender == "Conductor";

                    return Align(
                      alignment: isPassenger ? Alignment.centerRight : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                        child: Column(
                          crossAxisAlignment: isPassenger ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isPassenger ? Colors.blue : Colors.grey[300],
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: EdgeInsets.all(10.0),
                              child: Text(
                                messageData['message'],
                                style: TextStyle(
                                  color: isPassenger ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
