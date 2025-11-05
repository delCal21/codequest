import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/challenges/data/repositories/challenges_repository_impl.dart';
import 'package:codequest/features/challenges/domain/models/challenge_model.dart';
import 'package:codequest/features/users/data/repositories/users_repository_impl.dart';
import 'package:codequest/features/users/domain/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final challengesRepository =
        ChallengesRepositoryImpl(FirebaseFirestore.instance);
    final usersRepository = UsersRepositoryImpl(FirebaseFirestore.instance);
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: FutureBuilder<UserModel?>(
        future: usersRepository.getUser(userId),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (userSnapshot.hasError) {
            return Center(
                child: Text('Error: ${userSnapshot.error.toString()}'));
          } else if (!userSnapshot.hasData || userSnapshot.data == null) {
            return const Center(child: Text('No profile data.'));
          }
          final user = userSnapshot.data!;
          return FutureBuilder<List<ChallengeModel>>(
            future: challengesRepository.getChallengesByUser(userId),
            builder: (context, challengeSnapshot) {
              if (challengeSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (challengeSnapshot.hasError) {
                return Center(
                    child:
                        Text('Error: ${challengeSnapshot.error.toString()}'));
              }
              final challenges = challengeSnapshot.data ?? [];
              final double progress = challenges.isEmpty
                  ? 0.0
                  : challenges.where((c) => c.isCompleted).length /
                      challenges.length;
              final List<dynamic> recentActivities = user.recentActivities;
              final int challengeScore = challenges.fold<int>(
                  0, (total, c) => total + c.score.toInt());
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Your Progress',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: progress),
                            const SizedBox(height: 8),
                            Text(
                                '${(progress * 100).toStringAsFixed(0)}% completed'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_events,
                                size: 40, color: Colors.amber),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Challenge Score',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text('$challengeScore',
                                    style: const TextStyle(fontSize: 24)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Recent Activity',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (recentActivities.isEmpty)
                      const Center(child: Text('No recent activity.'))
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recentActivities.length,
                        itemBuilder: (context, index) {
                          final activity = recentActivities[index];
                          return ListTile(
                            leading: const Icon(Icons.check_circle,
                                color: Colors.green),
                            title: Text(activity['title'] ?? ''),
                            subtitle: Text(activity['description'] ?? ''),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
