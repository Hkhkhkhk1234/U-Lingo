import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pronunciation_practice_screen.dart';
import '../services/audio_player_service.dart';
import '../services/elevenlabs_service.dart';

class LevelDetailScreen extends StatefulWidget {
  final String levelDocId;
  final int levelId;
  final String levelTitle;

  const LevelDetailScreen({
    Key? key,
    required this.levelDocId,
    required this.levelId,
    required this.levelTitle,
  }) : super(key: key);

  @override
  State<LevelDetailScreen> createState() => _LevelDetailScreenState();
}

class _LevelDetailScreenState extends State<LevelDetailScreen> {
  int _currentQuizIndex = 0;
  int _score = 0;
  bool _showResult = false;
  String? _selectedAnswer;
  bool _isLoadingAudio = false;
  bool _isPlayingAudio = false;
  bool _isLoadingLevel = true;

  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> _pronunciations = [];

  @override
  void initState() {
    super.initState();
    _loadLevelData();
  }

  Future<void> _loadLevelData() async {
    try {
      final levelDoc = await FirebaseFirestore.instance
          .collection('levels')
          .doc(widget.levelDocId)
          .get();

      if (levelDoc.exists) {
        final data = levelDoc.data()!;
        setState(() {
          _quizzes = List<Map<String, dynamic>>.from(data['quizzes'] ?? []);
          _pronunciations = List<Map<String, dynamic>>.from(
            data['pronunciations'] ?? [],
          );
          _isLoadingLevel = false;
        });
      } else {
        setState(() => _isLoadingLevel = false);
      }
    } catch (e) {
      print('Error loading level data: $e');
      setState(() => _isLoadingLevel = false);
    }
  }

  Map<String, dynamic> get _currentQuiz {
    if (_quizzes.isEmpty) return {};
    return _quizzes[_currentQuizIndex];
  }

  Future<void> _playAudio() async {
    if (_isLoadingAudio || _isPlayingAudio || _quizzes.isEmpty) return;

    setState(() {
      _isLoadingAudio = true;
      _isPlayingAudio = true;
    });

    try {
      final audioText = _currentQuiz['audio'] as String;
      final audioBytes = await ElevenLabsService.textToSpeech(audioText);

      if (audioBytes != null) {
        await AudioPlayerService.playAudio(audioBytes);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load audio'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error playing audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
          _isPlayingAudio = false;
        });
      }
    }
  }

  void _selectAnswer(String answer) {
    setState(() {
      _selectedAnswer = answer;
    });
  }

  void _submitAnswer() {
    if (_selectedAnswer == null) return;

    final isCorrect = _selectedAnswer == _currentQuiz['correct'];
    if (isCorrect) {
      _score++;
    }

    if (_currentQuizIndex < _quizzes.length - 1) {
      setState(() {
        _currentQuizIndex++;
        _selectedAnswer = null;
      });
    } else {
      _completeLevel();
    }
  }

  Future<void> _completeLevel() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final userData = userDoc.data()!;
    final completedLevels = List<int>.from(userData['completedLevels'] ?? []);
    final currentLevel = userData['currentLevel'] ?? 1;

    if (!completedLevels.contains(widget.levelId)) {
      completedLevels.add(widget.levelId);

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'completedLevels': completedLevels,
        'currentLevel': widget.levelId == currentLevel ? currentLevel + 1 : currentLevel,
      });
    }

    setState(() {
      _showResult = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLevel) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF7F0),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAF7F0),
          elevation: 0,
          title: Text(widget.levelTitle),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_quizzes.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF7F0),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAF7F0),
          elevation: 0,
          title: Text(widget.levelTitle),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.quiz_outlined, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No quizzes available',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please contact the admin to add quizzes for this level',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_showResult) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF7F0),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAF7F0),
          elevation: 0,
          title: const Text('Quiz Results'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _score >= _quizzes.length * 0.7
                      ? Icons.celebration
                      : Icons.sentiment_satisfied,
                  size: 100,
                  color: _score >= _quizzes.length * 0.7
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(height: 24),
                Text(
                  _score >= _quizzes.length * 0.7
                      ? 'Great Job!'
                      : 'Good Effort!',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'You scored $_score out of ${_quizzes.length}',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4B896),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (_currentQuizIndex + 1) / _quizzes.length,
                minHeight: 12,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB347)),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  // Title
                  const Text(
                    'Listen Carefully',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),
                  // Audio button
                  Center(
                    child: GestureDetector(
                      onTap: _playAudio,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD4998C),
                            width: 8,
                          ),
                          color: const Color(0xFFFAF7F0),
                        ),
                        child: _isLoadingAudio
                            ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFD4998C),
                            ),
                          ),
                        )
                            : Icon(
                          _isPlayingAudio
                              ? Icons.volume_up
                              : Icons.volume_up_outlined,
                          size: 80,
                          color: const Color(0xFFD4998C),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Answer options
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(
                      (_currentQuiz['options'] as List?)?.length ?? 0,
                          (index) {
                        final options = _currentQuiz['options'] as List;
                        final option = options[index];
                        final isSelected = _selectedAnswer == option;

                        return GestureDetector(
                          onTap: () => _selectAnswer(option),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF8FAD88)
                                  : const Color(0xFFE8B4A0),
                              borderRadius: BorderRadius.circular(30),
                              border: isSelected
                                  ? Border.all(
                                color: const Color(0xFF6B8F63),
                                width: 3,
                              )
                                  : null,
                            ),
                            child: Text(
                              option,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Confirm button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _selectedAnswer == null ? null : _submitAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4B896),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                      child: Text(
                        _currentQuizIndex < _quizzes.length - 1
                            ? 'Confirm'
                            : 'Finish Quiz',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (_pronunciations.isNotEmpty) const SizedBox(height: 16),
                  if (_pronunciations.isNotEmpty)
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PronunciationPracticeScreen(
                                levelDocId: widget.levelDocId,
                                levelId: widget.levelId,
                                levelTitle: widget.levelTitle,
                                pronunciations: _pronunciations,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.mic, color: Colors.black),
                        label: const Text(
                          'Pronunciation Practice',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4B896),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: const BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}