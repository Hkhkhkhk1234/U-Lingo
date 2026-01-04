import 'package:flutter/material.dart';
import 'package:ulingo/services/audio_player_service.dart';
import 'package:ulingo/services/elevenlabs_service.dart';

/// Interactive pronunciation practice screen for language learning.
/// 
/// Implements listen-and-repeat methodology:
/// 1. User views word with phonetic guide (pinyin) and translation
/// 2. User listens to model pronunciation (TTS audio)
/// 3. User records their own pronunciation attempt
/// 4. System provides simulated scoring feedback
/// 
/// Current limitations (MVP implementation):
/// - Recording is simulated (no actual audio capture yet)
/// - Scoring is randomized (no speech recognition analysis)
/// - Feedback is generated based on score ranges, not actual pronunciation quality
/// 
/// Design choice: Simulated scoring allows testing UX flow and engagement
/// patterns before implementing expensive speech recognition API integration.
/// 
/// Future enhancement: Replace simulated recording with actual speech-to-text
/// comparison for accurate pronunciation assessment.
class PronunciationPracticeScreen extends StatefulWidget {
  final String levelDocId;
  final int levelId;
  final String levelTitle;
  final List<Map<String, dynamic>> pronunciations; // Pre-loaded from parent to avoid re-fetching

  const PronunciationPracticeScreen({
    Key? key,
    required this.levelDocId,
    required this.levelId,
    required this.levelTitle,
    required this.pronunciations,
  }) : super(key: key);

  @override
  State<PronunciationPracticeScreen> createState() =>
      _PronunciationPracticeScreenState();
}

class _PronunciationPracticeScreenState
    extends State<PronunciationPracticeScreen> {
  int _currentWordIndex = 0; // Tracks which word user is practicing
  bool _isRecording = false; // True during 2-second recording simulation
  bool _hasRecorded = false; // Tracks if user has attempted current word
  bool _showFeedback = false; // Controls feedback card visibility
  double _pronunciationScore = 0.0; // Simulated accuracy score (60-100%)
  String _feedbackText = ''; // Contextual message based on score
  bool _isPlayingModel = false; // True during model audio playback
  bool _isLoadingAudio = false; // True while generating TTS audio

  // Brand color palette centralized for consistency
  // These match the visual identity across all U-Lingo screens
  final Color primaryBeige = const Color(0xFFFAF6F0);
  final Color accentCoral = const Color(0xFFE8B4A0);
  final Color accentGreen = const Color(0xFF8FAD88);
  final Color textDark = const Color(0xFF2C2C2C);
  final Color buttonBeige = const Color(0xFFE8D5B5);

  /// Returns currently displayed word data.
  /// 
  /// Expected structure from Firestore:
  /// {
  ///   'word': '你好',           // Target language word
  ///   'pinyin': 'nǐ hǎo',      // Pronunciation guide
  ///   'translation': 'hello',   // English meaning
  ///   'tips': 'Rising tone...' // Pronunciation guidance
  /// }
  Map<String, dynamic> get _currentWord {
    if (widget.pronunciations.isEmpty) return {};
    return widget.pronunciations[_currentWordIndex];
  }

  /// Initiates simulated recording with visual/state feedback.
  /// 
  /// MVP implementation: No actual audio capture occurs.
  /// 2-second timer mimics recording duration to establish UX flow.
  /// 
  /// This simulation approach allows:
  /// - Testing engagement without speech recognition API costs
  /// - Validating UI/UX patterns before technical implementation
  /// - Gathering user feedback on practice methodology
  /// 
  /// Future: Replace with actual microphone access and audio capture.
  void _startRecording() {
    setState(() {
      _isRecording = true;
      _showFeedback = false; // Hide previous attempt's feedback
    });

    // Simulate 2-second recording duration
    // Provides realistic timing for pronunciation attempt
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _stopRecording();
      }
    });
  }

  /// Ends recording simulation and triggers analysis.
  void _stopRecording() {
    setState(() {
      _isRecording = false;
      _hasRecorded = true; // Enables "record again" messaging
    });
    _analyzePronunciation();
  }

  /// Generates simulated pronunciation accuracy score and feedback.
  /// 
  /// Current implementation: Randomized score (60-100%) for UX testing.
  /// Score ranges map to feedback messages:
  /// - 90-100%: Excellent - reinforces success
  /// - 75-89%: Good - encourages with specific guidance
  /// - 60-74%: Keep practicing - constructive redirection
  /// - <60%: Try again - gentle prompt to retry
  /// 
  /// Randomization uses current millisecond to create variability
  /// without requiring external randomness library.
  /// 
  /// Future enhancement: Replace with actual speech recognition API
  /// comparing user audio to reference pronunciation for real accuracy.
  void _analyzePronunciation() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        // Generate score between 60-100%
        // Formula: 60 + (40 * random_factor) where random_factor is 0.5-1.0
        final score = 60 + (40 * (0.5 + (DateTime.now().millisecond % 500) / 1000));

        // Feedback messages calibrated for encouragement over criticism
        // Language learning requires positive reinforcement to maintain motivation
        String feedback;
        if (score >= 90) {
          feedback = 'Excellent! Your pronunciation is very accurate!';
        } else if (score >= 75) {
          feedback = 'Good job! Pay attention to the tone.';
        } else if (score >= 60) {
          feedback = 'Keep practicing! Focus on the rising tone.';
        } else {
          feedback = 'Try again. Listen carefully to the model.';
        }

        setState(() {
          _pronunciationScore = score;
          _feedbackText = feedback;
          _showFeedback = true;
        });
      }
    });
  }

  /// Plays TTS audio of current word for user to model.
  /// 
  /// Provides both normal and slow speed options:
  /// - Normal speed: Natural speaking pace for comprehension
  /// - Slow speed: Exaggerated pronunciation for detailed learning
  /// 
  /// Note: Current implementation doesn't actually vary speed (future enhancement).
  /// Both options play same audio but provide different UI feedback.
  /// 
  /// Error handling covers:
  /// - Network failures during TTS generation
  /// - Invalid audio bytes from API
  /// - Device audio playback issues
  Future<void> _playModelPronunciation({bool slow = false}) async {
    // Prevent overlapping audio requests
    if (_isLoadingAudio || _isPlayingModel) return;

    setState(() {
      _isPlayingModel = true;
      _isLoadingAudio = true;
    });

    try {
      final word = _currentWord['word'] as String;
      
      // Network request to ElevenLabs TTS API
      // Generates audio from text for model pronunciation
      final audioBytes = await ElevenLabsService.textToSpeech(word);

      if (audioBytes != null) {
        await AudioPlayerService.playAudio(audioBytes);

        // Visual feedback confirms audio is playing
        // Helps users understand system is responding
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                slow
                    ? 'Playing model pronunciation (slow)'
                    : 'Playing model pronunciation',
              ),
              duration: const Duration(seconds: 1),
              backgroundColor: accentCoral,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }
      } else {
        // API returned null - service error or rate limiting
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to load audio'),
              duration: const Duration(seconds: 2),
              backgroundColor: accentCoral,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
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
            backgroundColor: accentCoral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPlayingModel = false;
          _isLoadingAudio = false;
        });
      }
    }
  }

  /// Advances to next pronunciation word or shows completion.
  /// 
  /// Resets attempt-specific state (recording, feedback) but preserves
  /// navigation position. This allows users to review previous words
  /// without losing their progress through the exercise set.
  void _nextWord() {
    if (_currentWordIndex < widget.pronunciations.length - 1) {
      setState(() {
        _currentWordIndex++;
        _hasRecorded = false;
        _showFeedback = false;
        _pronunciationScore = 0.0;
      });
    } else {
      // Reached end of pronunciation list
      _showCompletionDialog();
    }
  }

  /// Returns to previous word for additional practice.
  /// 
  /// Allows non-linear navigation so users can focus on difficult words
  /// without being forced through entire sequence again.
  void _previousWord() {
    if (_currentWordIndex > 0) {
      setState(() {
        _currentWordIndex--;
        _hasRecorded = false;
        _showFeedback = false;
        _pronunciationScore = 0.0;
      });
    }
  }

  /// Shows completion dialog with restart or exit options.
  /// 
  /// Two-button design provides clear paths:
  /// - "Finish": Returns to level detail screen
  /// - "Practice Again": Restarts from first word for additional repetition
  /// 
  /// Repetition option supports spaced practice methodology -
  /// multiple passes through material improve retention.
  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: primaryBeige,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: textDark, width: 3),
        ),
        title: Text(
          'Practice Complete!',
          style: TextStyle(
            color: accentCoral,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        content: Text(
          'Great job completing the pronunciation practice. Keep practicing to improve your accent!',
          style: TextStyle(
            color: textDark,
            fontSize: 16,
          ),
        ),
        actions: [
          // Exit option - returns to previous screen
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit pronunciation screen
            },
            style: TextButton.styleFrom(
              foregroundColor: textDark,
            ),
            child: const Text('Finish'),
          ),
          // Restart option - resets to beginning for additional practice
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              setState(() {
                _currentWordIndex = 0;
                _hasRecorded = false;
                _showFeedback = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Practice Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Empty state: No pronunciation exercises available
    // Occurs if admin hasn't added pronunciation data to this level
    if (widget.pronunciations.isEmpty) {
      return Scaffold(
        backgroundColor: primaryBeige,
        appBar: AppBar(
          backgroundColor: primaryBeige,
          elevation: 0,
          title: Text(
            'Pronunciation Practice',
            style: TextStyle(
              color: accentCoral,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: IconThemeData(color: textDark),
        ),
        body: Center(
          child: Text(
            'No pronunciation exercises available for this level',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: primaryBeige,
      appBar: AppBar(
        backgroundColor: primaryBeige,
        elevation: 0,
        title: Text(
          'Pronunciation Practice',
          style: TextStyle(
            color: accentCoral,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        iconTheme: IconThemeData(color: textDark),
        actions: [
          // Progress indicator shows position in word list
          // Helps users gauge time commitment remaining
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: buttonBeige,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: textDark, width: 2),
              ),
              child: Text(
                '${_currentWordIndex + 1}/${widget.pronunciations.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Linear progress bar provides visual completion indicator
          // Complements numeric counter in app bar
          Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (_currentWordIndex + 1) / widget.pronunciations.length,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFFFCC80)),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Word Display Card - Primary focus element
                  // Large text ensures visibility and emphasizes importance
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: textDark, width: 3),
                    ),
                    child: Column(
                      children: [
                        // Target language word in large font
                        Text(
                          _currentWord['word'] ?? '',
                          style: TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Pinyin provides pronunciation guide for tonal languages
                        Text(
                          _currentWord['pinyin'] ?? '',
                          style: TextStyle(
                            fontSize: 32,
                            color: accentCoral,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Translation provides meaning context
                        Text(
                          _currentWord['translation'] ?? '',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tips Container - Pronunciation guidance
                  // Yellow background creates distinct visual separation
                  // from main content while maintaining friendly aesthetic
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFCC80), width: 2),
                    ),
                    child: Row(
                      children: [
                        const Text('Tips:', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _currentWord['tips'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Listen Section - Model audio playback
                  Text(
                    'Listen to Model Pronunciation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Dual speed buttons support different learning needs
                  // Normal speed: Natural comprehension and fluency
                  // Slow speed: Detailed phoneme analysis (future feature)
                  Row(
                    children: [
                      Expanded(
                        child: _buildStyledButton(
                          onPressed: (_isPlayingModel || _isLoadingAudio)
                              ? null
                              : () => _playModelPronunciation(),
                          icon: _isLoadingAudio
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Icon(
                            _isPlayingModel ? Icons.volume_up : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          label: 'Normal Speed',
                          isPrimary: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStyledButton(
                          onPressed: (_isPlayingModel || _isLoadingAudio)
                              ? null
                              : () => _playModelPronunciation(slow: true),
                          icon: Icon(Icons.slow_motion_video, color: textDark),
                          label: 'Slow',
                          isPrimary: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Record Section - User pronunciation capture
                  Text(
                    'Record Your Pronunciation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Large circular record button with pulsing animation
                  // Color changes and size animation provide clear recording feedback
                  Center(
                    child: GestureDetector(
                      onTap: _isRecording ? null : _startRecording,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isRecording ? 100 : 120,
                        height: _isRecording ? 100 : 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // Color shifts: green (ready) → coral (recording)
                          color: _isRecording ? accentCoral : accentGreen,
                          border: Border.all(color: textDark, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording ? accentCoral : accentGreen)
                                  .withOpacity(0.4),
                              blurRadius: 20,
                              // Glow intensifies during recording
                              spreadRadius: _isRecording ? 10 : 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Status text adapts to recording state
                  Center(
                    child: Text(
                      _isRecording
                          ? 'Recording...'
                          : _hasRecorded
                          ? 'Tap to record again'
                          : 'Tap to start recording',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Feedback Section - Shows scoring results
                  // Color-coded card indicates performance level
                  if (_showFeedback) ...[
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        // Color psychology:
                        // Green (75+%): Success, mastery
                        // Orange (60-74%): Improvement needed
                        // Coral (<60%): Encouragement to retry
                        color: _pronunciationScore >= 75
                            ? accentGreen
                            : _pronunciationScore >= 60
                            ? const Color(0xFFFFB74D)
                            : accentCoral,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: textDark, width: 3),
                      ),
                      child: Column(
                        children: [
                          // Large percentage creates visual impact
                          Text(
                            '${_pronunciationScore.toInt()}%',
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Contextual feedback provides actionable guidance
                          Text(
                            _feedbackText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Navigation Buttons - Word list traversal
                  Row(
                    children: [
                      // Previous button only shown when not on first word
                      if (_currentWordIndex > 0)
                        Expanded(
                          child: _buildStyledButton(
                            onPressed: _previousWord,
                            icon: Icon(Icons.arrow_back, color: textDark),
                            label: 'Previous',
                            isPrimary: false,
                          ),
                        ),
                      if (_currentWordIndex > 0) const SizedBox(width: 12),
                      // Next/Complete button always visible
                      // Takes more space (flex: 2) to emphasize forward progression
                      Expanded(
                        flex: 2,
                        child: _buildStyledButton(
                          onPressed: _nextWord,
                          icon: Icon(
                            _currentWordIndex < widget.pronunciations.length - 1
                                ? Icons.arrow_forward
                                : Icons.check,
                            color: Colors.white,
                          ),
                          label: _currentWordIndex < widget.pronunciations.length - 1
                              ? 'Next Word'
                              : 'Complete',
                          isPrimary: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Reusable button component with consistent styling.
  /// 
  /// Two visual variants:
  /// - Primary (coral): Main actions (play, record, next)
  /// - Secondary (beige): Optional actions (slow speed, previous)
  /// 
  /// This distinction guides users toward primary learning flow
  /// while keeping secondary options accessible.
  Widget _buildStyledButton({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
    required bool isPrimary,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? accentCoral : buttonBeige,
        foregroundColor: isPrimary ? Colors.white : textDark,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: textDark, width: 2),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isPrimary ? Colors.white : textDark,
            ),
          ),
        ],
      ),
    );
  }
}
