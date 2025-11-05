import 'package:flutter/material.dart';
import 'package:codequest/features/challenges/domain/models/challenge_model.dart';

class ChallengeDetailsPage extends StatefulWidget {
  final ChallengeModel challenge;

  const ChallengeDetailsPage({super.key, required this.challenge});

  @override
  State<ChallengeDetailsPage> createState() => _ChallengeDetailsPageState();
}

class _ChallengeDetailsPageState extends State<ChallengeDetailsPage> {
  final _solutionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _solutionController.dispose();
    super.dispose();
  }

  void _submitSolution() {
    if (_solutionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your solution')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // TODO: Implement solution submission logic
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solution submitted successfully!')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.challenge.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getDifficultyColor(widget.challenge.difficulty),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    widget.challenge.lesson == 0
                        ? 'Summative'
                        : 'Module: ${widget.challenge.lesson}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Module: ${widget.challenge.lesson}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Description', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.challenge.description),
            const SizedBox(height: 24),
            Text('Lessons', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.challenge.instructions),
            const SizedBox(height: 24),
            Text(
              'Your Solution',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _solutionController,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: 'Enter your solution here...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitSolution,
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('Submit Solution'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDifficultyColor(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return Colors.green;
      case ChallengeDifficulty.medium:
        return Colors.orange;
      case ChallengeDifficulty.hard:
        return Colors.red;
    }
  }
}
