import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/challenges/data/repositories/challenges_repository_impl.dart';
import 'package:codequest/features/challenges/domain/models/challenge_model.dart';
import 'package:codequest/features/challenges/presentation/widgets/challenge_form.dart';

class CreateChallengePage extends StatelessWidget {
  const CreateChallengePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Challenge')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ChallengeForm(),
      ),
    );
  }
}

class ChallengesPage extends StatelessWidget {
  const ChallengesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final challengesRepository =
        ChallengesRepositoryImpl(FirebaseFirestore.instance);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coding Challenges'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create Challenges',
                  style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateChallengePage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<ChallengeModel>>(
        future: challengesRepository.getChallenges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error.toString()}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No challenges available.'));
          }
          final challenges = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.only(top: 16),
            children: [
              ...challenges.map((challenge) => Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const Icon(Icons.code, size: 48),
                      title: Text(challenge.title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(challenge.description,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () {
                          // TODO: Start/take challenge
                        },
                      ),
                      onTap: () {
                        // TODO: Navigate to challenge details/results
                      },
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}
