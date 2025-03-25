import 'package:flutter/material.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestion = 0;
  int _score = 0;

  final List<QuizQuestion> _questions = [
    QuizQuestion(
      question: "What should you do during an earthquake?",
      options: ["Run outside", "Drop, Cover, and Hold", "Stand near windows"],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: "Where is the safest place during an earthquake?",
      options: ["Under a sturdy table", "Next to a window", "In an elevator"],
      correctIndex: 0,
    ),
  ];

  void _checkAnswer(int selectedIndex) {
    final bool isCorrect =
        selectedIndex == _questions[_currentQuestion].correctIndex;

    setState(() {
      if (isCorrect) _score++;

      if (_currentQuestion < _questions.length - 1) {
        _currentQuestion++;
      } else {
        _showQuizCompletedDialog();
      }
    });
  }

  void _showQuizCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Quiz Completed"),
          content: Text(
            "Your Score: $_score/${_questions.length}",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          actions: [
            TextButton(onPressed: _resetQuiz, child: const Text("Restart")),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  void _resetQuiz() {
    setState(() {
      _currentQuestion = 0;
      _score = 0;
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final QuizQuestion currentQuestionData = _questions[_currentQuestion];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Earthquake Quiz"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                "Score: $_score",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              currentQuestionData.question,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ...List.generate(
              currentQuestionData.options.length,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton(
                  onPressed: () => _checkAnswer(index),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    currentQuestionData.options[index],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                "Question ${_currentQuestion + 1}/${_questions.length}",
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Data model for quiz questions
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}
