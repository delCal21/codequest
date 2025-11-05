import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> createFirstAdmin({
  required String email,
  required String password,
  required String fullName,
}) async {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  final userCredential = await auth.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );

  await firestore.collection('users').doc(userCredential.user!.uid).set({
    'fullName': fullName,
    'email': email,
    'role': 'admin',
  });
}
