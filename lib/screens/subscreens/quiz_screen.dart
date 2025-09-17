import 'package:flutter/material.dart';
import 'dart:async';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestion = 0;
  int _score = 0;
  int _timeLeft = 10;
  Timer? _timer;
  int? _selectedAnswerIndex;
  bool _showHint = false;

  final List<QuizQuestion> _questions = [
    // Earthquake Preparedness
    QuizQuestion(
      question: "What should you do during an earthquake?",
      options: ["Run outside", "Drop, Cover, and Hold", "Stand near windows"],
      correctIndex: 1,
      hint: "Think about protecting yourself from falling objects.",
    ),
    QuizQuestion(
      question: "Where is the safest place during an earthquake?",
      options: ["Under a sturdy table", "Next to a window", "In an elevator"],
      correctIndex: 0,
      hint: "You need protection from falling debris.",
    ),
    QuizQuestion(
      question: "Which emergency supply is most important after an earthquake?",
      options: ["Water", "Smartphone", "Laptop"],
      correctIndex: 0,
      hint: "Survival depends on hydration.",
    ),
    QuizQuestion(
      question: "What should you do if you're outside during an earthquake?",
      options: [
        "Run to a building",
        "Stay away from buildings and trees",
        "Go under a bridge",
      ],
      correctIndex: 1,
      hint: "Falling objects are dangerous.",
    ),
    QuizQuestion(
      question: "What should you do after an earthquake?",
      options: [
        "Turn off gas supply",
        "Use elevators",
        "Go back inside immediately",
      ],
      correctIndex: 0,
      hint: "Gas leaks can cause fires.",
    ),

    // Science & Measurement
    QuizQuestion(
      question: "What instrument measures earthquake magnitude?",
      options: ["Barometer", "Seismometer", "Thermometer"],
      correctIndex: 1,
      hint: "It records ground motion.",
    ),
    QuizQuestion(
      question: "Which scale is commonly used to measure earthquake magnitude?",
      options: ["Richter Scale", "Beaufort Scale", "Fahrenheit Scale"],
      correctIndex: 0,
      hint: "It was developed in 1935 by Charles Richter.",
    ),
    QuizQuestion(
      question:
          "What is the point underground where an earthquake starts called?",
      options: ["Hypocenter", "Epicenter", "Fault Line"],
      correctIndex: 0,
      hint: "It's deep beneath the Earth's surface.",
    ),
    QuizQuestion(
      question:
          "What is the name of the outermost layer of the Earth where earthquakes occur?",
      options: ["Mantle", "Crust", "Core"],
      correctIndex: 1,
      hint: "It's the thinnest but most active layer.",
    ),
    QuizQuestion(
      question: "What causes most earthquakes?",
      options: ["Volcanic eruptions", "Tectonic plate movement", "Hurricanes"],
      correctIndex: 1,
      hint: "The Earth's plates are constantly moving.",
    ),

    // Historical Earthquakes
    QuizQuestion(
      question:
          "Which country experienced the largest earthquake ever recorded (9.5 magnitude)?",
      options: ["Japan", "Chile", "Indonesia"],
      correctIndex: 1,
      hint: "It occurred in 1960 in South America.",
    ),
    QuizQuestion(
      question:
          "What year did the devastating earthquake hit Haiti, killing over 200,000 people?",
      options: ["2010", "2004", "1995"],
      correctIndex: 0,
      hint: "It was a major disaster in the 21st century.",
    ),
    QuizQuestion(
      question: "Which U.S. state is most prone to earthquakes?",
      options: ["Texas", "California", "Florida"],
      correctIndex: 1,
      hint: "It's along the San Andreas Fault.",
    ),
    QuizQuestion(
      question: "Which city was destroyed by a massive earthquake in 1906?",
      options: ["Los Angeles", "San Francisco", "New York"],
      correctIndex: 1,
      hint: "It caused fires that lasted for days.",
    ),
    QuizQuestion(
      question:
          "Which Asian country was hit by a 9.0 magnitude earthquake and tsunami in 2011?",
      options: ["Thailand", "Japan", "India"],
      correctIndex: 1,
      hint: "It led to the Fukushima nuclear disaster.",
    ),

    // Myth vs. Fact
    QuizQuestion(
      question: "Can animals predict earthquakes?",
      options: [
        "Yes, always",
        "No, but they may sense vibrations",
        "No, it's impossible",
      ],
      correctIndex: 1,
      hint: "Animals can feel ground vibrations before humans do.",
    ),
    QuizQuestion(
      question: "Will California fall into the ocean due to earthquakes?",
      options: ["Yes, soon", "No, but land may shift", "Yes, in 100 years"],
      correctIndex: 1,
      hint: "Tectonic plates slide, but don’t sink into the ocean.",
    ),
    QuizQuestion(
      question: "Is it safe to stand in a doorway during an earthquake?",
      options: [
        "Yes",
        "No, it's not safer than other places",
        "Only in old buildings",
      ],
      correctIndex: 1,
      hint: "Modern doorways don’t provide much protection.",
    ),
    QuizQuestion(
      question: "Do small earthquakes prevent big ones?",
      options: ["Yes", "No", "Sometimes"],
      correctIndex: 1,
      hint: "Smaller quakes don’t release enough energy.",
    ),
    QuizQuestion(
      question: "Can earthquakes be predicted accurately?",
      options: ["Yes", "No, only probabilities", "Only with advanced AI"],
      correctIndex: 1,
      hint: "Scientists can estimate risks but not exact times.",
    ),
  ];

  // Initialize state and start the timer
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  // Start or restart the countdown timer
  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _timeLeft = 10;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _timer?.cancel();
        _moveToNextQuestion();
      }
    });
  }

  // Check the selected answer and update score
  void _checkAnswer(int selectedIndex) {
    if (_selectedAnswerIndex != null) return;

    setState(() {
      _selectedAnswerIndex = selectedIndex;
      if (selectedIndex == _questions[_currentQuestion].correctIndex) {
        _score++;
      }
    });

    Future.delayed(const Duration(seconds: 1), () {
      _moveToNextQuestion();
    });
  }

  // Move to the next question or show completion dialog
  void _moveToNextQuestion() {
    if (_currentQuestion < _questions.length - 1) {
      setState(() {
        _currentQuestion++;
        _selectedAnswerIndex = null;
        _showHint = false;
      });
      _startTimer();
    } else {
      _timer?.cancel();
      _showQuizCompletedDialog();
    }
  }

  // Show dialog when quiz is completed
  void _showQuizCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Quiz Completed!"),
          content: Text("Your Score: $_score/${_questions.length}"),
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

  // Reset the quiz to initial state
  void _resetQuiz() {
    setState(() {
      _currentQuestion = 0;
      _score = 0;
      _selectedAnswerIndex = null;
      _showHint = false;
    });
    Navigator.of(context).pop();
    _startTimer();
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
            // Progress Bar
            LinearProgressIndicator(
              value: (_currentQuestion + 1) / _questions.length,
              backgroundColor: Colors.grey.shade300,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),

            // Timer Display
            Text(
              "Time Left: $_timeLeft sec",
              style: TextStyle(
                color:
                    _timeLeft <= 3
                        ? Colors.red
                        : Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Question
            Text(
              currentQuestionData.question,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Options List
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
                    backgroundColor:
                        _selectedAnswerIndex == null
                            ? Colors.blue
                            : index == currentQuestionData.correctIndex
                            ? Colors.green
                            : index == _selectedAnswerIndex
                            ? Colors.red
                            : Colors.blue,
                  ),
                  child: Text(
                    currentQuestionData.options[index],
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),

            // Show Hint Button
            TextButton(
              onPressed: () {
                setState(() {
                  _showHint = !_showHint;
                });
              },
              child: const Text("Show Hint"),
            ),

            // Display Hint
            if (_showHint)
              Text(
                currentQuestionData.hint,
                style: TextStyle(
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),

            const Spacer(),

            // Question Count
            Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                "Question ${_currentQuestion + 1}/${_questions.length}",
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Clean up the timer when the widget is disposed
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String hint;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.hint,
  });
}
