import 'package:codequest/features/challenges/domain/models/challenge_model.dart';

abstract class ChallengesRepository {
  Future<List<ChallengeModel>> getChallenges({
    String? difficulty,
    String? category,
  });

  Future<ChallengeModel> getChallenge(String id);

  Future<void> createChallenge(ChallengeModel challenge);

  Future<void> updateChallenge(ChallengeModel challenge);

  Future<void> deleteChallenge(String id);
}
