import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pronunciation_practice_screen.dart';
import '../services/audio_player_service.dart';
import '../services/elevenlabs_service.dart';

/// Interactive quiz screen with audio-based questions for language learning.
/// 
/// Implements listening comprehension exercises where:
/// 1. User listens to audio (text-to-speech from ElevenLabs API)
/// 2. User selects answer from multiple choice options
/// 3. Quiz auto-advances through all questions
/// 4. Progress is saved upon completion
/// 
/// Critical features:
/// - Sequential question flow prevents skipping ahead
/// - Audio playback uses external TTS service (requires internet)
/// - Level completion triggers currentLevel increment for progression unlocking
/// - Optional pronunciation practice available after quiz
/// 
/// State management approach:
/// - Local state tracks quiz progress (_currentQuizIndex, _score)
/// - Firestore updated only on completion (reduces write operations)
/// - Loading states prevent duplicate API calls during audio generation
class LevelDetailScreen extends StatefulWidget {
  final String levelDocId; // Firestore document ID for level data
  final int levelId; // Numeric level identifier for progression tracking
  final String levelTitle; // Display name for user context

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
  int _currentQuizIndex = 0; // Tracks which question is currently displayed
  int _score = 0; // Running total of correct answers
  bool _showResult = false; // Toggles between quiz and results screen
  String? _selectedAnswer; // Currently selected answer option
  bool _isLoadingAudio = false; // True while TTS API generates audio
  bool _isPlayingAudio = false; // True during audio playback
  bool _isLoadingLevel = true; // True while fetching level data from Firestore

  // Level content loaded once during initialization
  // Stored locally to avoid repeated Firestore reads during quiz
  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> _pronunciations = [];

  @override
  void initState() {
    super.initState();
    _loadLevelData();
  }

  /// Fetches quiz and pronunciation data for this level from Firestore.
  /// 
  /// Data structure loaded once at initialization rather than streaming
  /// because quiz content shouldn't change mid-session. This approach:
  /// - Reduces Firestore read costs
  /// - Prevents UI disruption if admin modifies content during user session
  /// - Simplifies state management (no StreamBuilder needed)
  Future<void> _loadLevelData() async {
    try {
      final levelDoc = await FirebaseFirestore.instance
          .collection('levels')
          .doc(widget.levelDocId)
          .get();

      if (levelDoc.exists) {
        final data = levelDoc.data()!;
        setState(() {
          // Cast to List<Map> to match quiz data structure
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

  /// Returns currently displayed quiz question data.
  /// 
  /// Computed getter provides clean access to current question without
  /// repeating array bounds checking throughout the code.
  Map<String, dynamic> get _currentQuiz {
    if (_quizzes.isEmpty) return {};
    return _quizzes[_currentQuizIndex];
  }

  /// Generates and plays audio for current quiz question using TTS service.
  /// 
  /// Multi-step process:
  /// 1. Extract audio text from quiz data
  /// 2. Call ElevenLabs API to generate speech (network request)
  /// 3. Play audio bytes through device speaker
  /// 
  /// Loading states prevent:
  /// - Duplicate API calls if user taps button repeatedly
  /// - Race conditions from overlapping audio requests
  /// - UI freezing during network operations
  /// 
  /// Error handling provides user feedback if:
  /// - Network request fails (no internet, API down)
  /// - Audio bytes are invalid/corrupted
  /// - Device audio playback fails
  Future<void> _playAudio() async {
    // Guard against multiple simultaneous audio requests
    if (_isLoadingAudio || _isPlayingAudio || _quizzes.isEmpty) return;

    setState(() {
      _isLoadingAudio = true;
      _isPlayingAudio = true;
    });

    try {
      final audioText = _currentQuiz['audio'] as String;
      
      // Network request to ElevenLabs TTS API
      // This is the most likely failure point (requires internet)
      final audioBytes = await ElevenLabsService.textToSpeech(audioText);

      if (audioBytes != null) {
        // Play audio through device speaker
        await AudioPlayerService.playAudio(audioBytes);
      } else {
        // API returned null - likely service error or rate limit
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
      // Reset loading states regardless of success/failure
      // Mounted check prevents setState after navigation
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
          _isPlayingAudio = false;
        });
      }
    }
  }

  /// Records user's answer selection without submitting.
  /// 
  /// Separating selection from submission allows users to change their
  /// mind before confirming. Submit button remains disabled until
  /// selection is made, providing clear visual feedback.
  void _selectAnswer(String answer) {
    setState(() {
      _selectedAnswer = answer;
    });
  }

  /// Validates answer, updates score, and advances to next question.
  /// 
  /// No answer feedback is shown immediately - this design choice:
  /// - Reduces anxiety by not highlighting mistakes
  /// - Maintains quiz momentum and engagement
  /// - Shows cumulative results at the end instead
  /// 
  /// Auto-advances to keep flow moving without requiring extra button tap.
  void _submitAnswer() {
    if (_selectedAnswer == null) return;

    // Check correctness and update score
    final isCorrect = _selectedAnswer == _currentQuiz['correct'];
    if (isCorrect) {
      _score++;
    }

    // Either advance to next question or complete quiz
    if (_currentQuizIndex < _quizzes.length - 1) {
      setState(() {
        _currentQuizIndex++;
        _selectedAnswer = null; // Reset selection for next question
      });
    } else {
      // Last question - trigger completion flow
      _completeLevel();
    }
  }

  /// Updates user's progress in Firestore upon level completion.
  /// 
  /// Critical progression logic:
  /// - Adds levelId to completedLevels array (tracks history)
  /// - Increments currentLevel only if this was the current level
  ///   (prevents skipping ahead if user revisits old level)
  /// 
  /// This approach allows:
  /// - Users to replay completed levels without affecting progression
  /// - Sequential unlocking of new content
  /// - Accurate completion tracking for achievements/stats
  Future<void> _completeLevel() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final userData = userDoc.data()!;
    final completedLevels = List<int>.from(userData['completedLevels'] ?? []);
    final currentLevel = userData['currentLevel'] ?? 1;

    // Only update if this level hasn't been completed before
    // Prevents duplicate entries in completedLevels array
    if (!completedLevels.contains(widget.levelId)) {
      completedLevels.add(widget.levelId);

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'completedLevels': completedLevels,
        // Unlock next level only if completing current level
        // If replaying old level, currentLevel stays unchanged
        'currentLevel': widget.levelId == currentLevel ? currentLevel + 1 : currentLevel,
      });
    }

    // Show results screen
    setState(() {
      _showResult = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Loading state: Show spinner while fetching level data
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

    // Empty state: No quiz content available
    // This occurs if admin hasn't added quizzes to this level yet
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

    // Results screen: Shows score and pass/fail feedback
    // 70% threshold determines success messaging
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
                // Visual feedback based on performance
                // Green celebration for passing, orange smile for needs improvement
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
                // Positive messaging even for lower scores
                // Encourages continued effort without being discouraging
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
                // Continue button returns to roadmap
                // Level completion already saved, so safe to navigate back
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

    // Main quiz interface
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F0),
        elevation: 0,
        // Close button instead of back button suggests modal-like interaction
        // Clicking exits quiz without saving progress (intentional design)
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // Progress bar shows quiz completion percentage
          // Visual feedback helps users gauge time commitment
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
                  // Instruction text sets context for audio interaction
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
                  
                  // Audio playback button - primary interaction element
                  // Large circular design makes it obvious and easy to tap
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
                          // Icon changes subtly during playback
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
                  
                  // Answer options in flexible wrap layout
                  // Adapts to varying answer lengths and screen sizes
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
                              // Color changes on selection for clear visual feedback
                              color: isSelected
                                  ? const Color(0xFF8FAD88) // Green for selected
                                  : const Color(0xFFE8B4A0), // Peach for unselected
                              borderRadius: BorderRadius.circular(30),
                              // Border adds extra emphasis to selected state
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
                  
                  // Confirm button - disabled until answer selected
                  // Button text changes on last question to signal quiz completion
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
                  
                  // Optional pronunciation practice button
                  // Only shown if level includes pronunciation exercises
                  // Allows bypassing quiz to go directly to speaking practice
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
