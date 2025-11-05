import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/challenges/data/repositories/challenges_repository_impl.dart';
import 'package:codequest/features/challenges/domain/models/challenge_model.dart';
import 'package:codequest/features/challenges/presentation/widgets/challenge_form.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  late ChallengesRepositoryImpl challengesRepository;
  late Future<List<ChallengeModel>> _challengesFuture;
  int? _selectedLesson;

  @override
  void initState() {
    super.initState();
    challengesRepository = ChallengesRepositoryImpl(FirebaseFirestore.instance);
    _refreshChallenges();
  }

  void _refreshChallenges() {
    setState(() {
      _challengesFuture = _selectedLesson == null
          ? challengesRepository.getChallenges()
          : challengesRepository.getChallengesByLesson(_selectedLesson!);
    });
  }

  void _showChallengeForm({ChallengeModel? challenge}) async {
    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 500,
          child: ChallengeForm(
            challenge: challenge,
            isEditing: challenge != null,
          ),
        ),
      ),
    );
    if (result != null) {
      _refreshChallenges();
    }
  }

  void _deleteChallenge(String id) async {
    await challengesRepository.deleteChallenge(id);
    _refreshChallenges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coding Challenges')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Text('Filter by Module: '),
                DropdownButton<int?>(
                  value: _selectedLesson,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All'),
                    ),
                    ...List.generate(10, (i) => i + 1)
                        .map((lesson) => DropdownMenuItem<int?>(
                              value: lesson,
                              child: Text('Module $lesson'),
                            ))
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedLesson = val;
                    });
                    _refreshChallenges();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ChallengeModel>>(
              future: _challengesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error.toString()}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No challenges available.'));
                }
                final challenges = snapshot.data!;
                return ListView.builder(
                  itemCount: challenges.length,
                  itemBuilder: (context, index) {
                    final challenge = challenges[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.code, size: 48),
                        title: Text(challenge.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(challenge.description,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text('Module: ${challenge.lesson}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _showChallengeForm(challenge: challenge),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteChallenge(challenge.id),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                        onTap: () => _showChallengeForm(challenge: challenge),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showChallengeForm(),
        child: const Icon(Icons.add),
        tooltip: 'Add Challenge',
      ),
    );
  }
}
