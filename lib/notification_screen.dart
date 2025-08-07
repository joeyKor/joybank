
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  

  // 모든 알림 삭제
  Future<void> _deleteAllNotifications() async {
    if (_currentUser == null) return;

    final collection = _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('notifications');

    final snapshot = await collection.get();
    for (DocumentSnapshot doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('알림')),
        body: const Center(
          child: Text('로그인이 필요합니다.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever), // 작은 아이콘으로 변경
            onPressed: _deleteAllNotifications,
            tooltip: '모든 알림 삭제',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(_currentUser!.uid)
                  .collection('notifications')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('새로운 알림이 없습니다.'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final notification = doc.data() as Map<String, dynamic>;
                    final message = notification['message'] ?? '내용 없음';
                    final timestamp = (notification['timestamp'] as Timestamp).toDate();
                    final read = notification['read'] ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(
                          read ? Icons.notifications_none : Icons.notifications_active,
                          color: read ? Colors.grey : Theme.of(context).primaryColor,
                        ),
                        title: Text(message),
                        subtitle: Text(
                          '${timestamp.toLocal().year}-${timestamp.toLocal().month.toString().padLeft(2, '0')}-${timestamp.toLocal().day.toString().padLeft(2, '0')} ${timestamp.toLocal().hour.toString().padLeft(2, '0')}:${timestamp.toLocal().minute.toString().padLeft(2, '0')}',
                        ),
                        onTap: () async {
                          // 알림 읽음 처리
                          await doc.reference.update({'read': true});
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
