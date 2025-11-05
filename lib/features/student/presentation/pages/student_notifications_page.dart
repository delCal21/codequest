import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentNotificationsPage extends StatelessWidget {
  const StudentNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('You must be logged in.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: currentUser.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Center(child: Text('No notifications.'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final notif = docs[i];
              return ListTile(
                leading: Icon(Icons.forum,
                    color: notif['read'] ? Colors.grey : Colors.blue),
                title: Text(notif['title'] ?? ''),
                subtitle: Text(notif['message'] ?? ''),
                trailing: notif['read']
                    ? null
                    : const Icon(Icons.fiber_new, color: Colors.red, size: 18),
                onTap: () async {
                  // Mark as read
                  await notif.reference.update({'read': true});
                  // Optionally, navigate to the forum post
                },
              );
            },
          );
        },
      ),
    );
  }
}
