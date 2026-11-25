import 'package:eco_collect/components/buttons/reusable_button.dart';
import 'package:eco_collect/constants/kenums.dart';
import 'package:eco_collect/services/geocampus_local_state.dart';
import 'package:eco_collect/services/geocampus_rewards.dart';
import 'package:eco_collect/utils/kloading.dart';
import 'package:flutter/material.dart';

class _QuizQuestion {
  final String question;
  final List<String> options;
  final String answer;

  const _QuizQuestion(this.question, this.options, this.answer);
}

class GeoCampusQuizScreen extends StatefulWidget {
  const GeoCampusQuizScreen({super.key});

  @override
  State<GeoCampusQuizScreen> createState() => _GeoCampusQuizScreenState();
}

class _GeoCampusQuizScreenState extends State<GeoCampusQuizScreen> {
  static const int _xpPerCorrect = 20;
  static const int _coinsPerCorrect = 10;

  static const List<_QuizQuestion> _quizzes = [
    _QuizQuestion(
      'Which plant is native to the Mediterranean campus region?',
      ['Oak Tree', 'Olive Tree', 'Pine Tree', 'Cherry Blossom'],
      'Olive Tree',
    ),
    _QuizQuestion(
      'What is the main SDG targeted by planting local vegetation?',
      ['SDG 4: Education', 'SDG 15: Life on Land', 'SDG 1: No Poverty'],
      'SDG 15: Life on Land',
    ),
    _QuizQuestion(
      'Roughly how much forest does the world lose each year (FAO)?',
      ['1 million ha', '10 million ha', '100 million ha'],
      '10 million ha',
    ),
  ];

  int _currentQuestionIndex = 0;
  int _correct = 0;
  bool _answered = false;
  bool? _alreadyDoneToday;

  @override
  void initState() {
    super.initState();
    GeocampusLocalState.isDailyQuizDone().then((done) {
      if (mounted) setState(() => _alreadyDoneToday = done);
    });
  }

  Future<void> _submitAnswer(String selectedOption) async {
    if (_answered) return; // ignore double taps
    final isCorrect = selectedOption == _quizzes[_currentQuestionIndex].answer;
    setState(() {
      _answered = true;
      if (isCorrect) _correct++;
    });

    KLoadingToast.showCustomDialog(
      message: isCorrect
          ? 'Correct! +$_xpPerCorrect XP'
          : 'Not quite: ${_quizzes[_currentQuestionIndex].answer}',
      toastType: isCorrect ? KenumToastType.success : KenumToastType.error,
    );

    if (_currentQuestionIndex < _quizzes.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _answered = false;
      });
      return;
    }

    // Finished: grant the reward once for the whole quiz.
    await GeocampusLocalState.markDailyQuizDone();
    if (_correct > 0 && mounted) {
      await GeocampusRewards.grantExplorationReward(
        context,
        xp: _correct * _xpPerCorrect,
        trophies: _correct * _coinsPerCorrect,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Sustainability Quiz'),
        backgroundColor: Colors.teal,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_alreadyDoneToday == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_alreadyDoneToday!) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'You already completed today\'s quiz.\nCome back tomorrow! 🌿',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    final quiz = _quizzes[_currentQuestionIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            'Question ${_currentQuestionIndex + 1}/${_quizzes.length}',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Text(
            quiz.question,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          for (final option in quiz.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: ReusableButton(
                label: option,
                mainAxisAlignment: MainAxisAlignment.center,
                onTap: () => _submitAnswer(option),
              ),
            ),
        ],
      ),
    );
  }
}
