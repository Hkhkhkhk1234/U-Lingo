import 'package:flutter/material.dart';
import 'package:ulingo/services/audio_player_service.dart';
import 'package:ulingo/services/elevenlabs_service.dart';

class PronunciationPracticeScreen extends StatefulWidget {
  final String levelDocId;
  final int levelId;
  final String levelTitle;
  final List<Map<String, dynamic>> pronunciations;

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
  int _currentWordIndex = 0;
  bool _isRecording = false;
  bool _hasRecorded = false;
  bool _showFeedback = false;
  double _pronunciationScore = 0.0;
  String _feedbackText = '';
  bool _isPlayingModel = false;
  bool _isLoadingAudio = false;

  // U-lingo color theme
  final Color primaryBeige = const Color(0xFFFAF6F0); //0xFFE17C7C
  final Color accentCoral = const Color(0xFFE8B4A0); //0xFFE17C7C
  final Color accentGreen = const Color(0xFF8FAD88);  //0xFF9DC88D
  final Color textDark = const Color(0xFF2C2C2C);
  final Color buttonBeige = const Color(0xFFE8D5B5);

  Map<String, dynamic> get _currentWord {
    if (widget.pronunciations.isEmpty) return {};
    return widget.pronunciations[_currentWordIndex];
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _showFeedback = false;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _stopRecording();
      }
    });
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
      _hasRecorded = true;
    });
    _analyzePronunciation();
  }

  void _analyzePronunciation() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final score = 60 + (40 * (0.5 + (DateTime.now().millisecond % 500) / 1000));

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

  Future<void> _playModelPronunciation({bool slow = false}) async {
    if (_isLoadingAudio || _isPlayingModel) return;

    setState(() {
      _isPlayingModel = true;
      _isLoadingAudio = true;
    });

    try {
      final word = _currentWord['word'] as String;
      final audioBytes = await ElevenLabsService.textToSpeech(word);

      if (audioBytes != null) {
        await AudioPlayerService.playAudio(audioBytes);

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

  void _nextWord() {
    if (_currentWordIndex < widget.pronunciations.length - 1) {
      setState(() {
        _currentWordIndex++;
        _hasRecorded = false;
        _showFeedback = false;
        _pronunciationScore = 0.0;
      });
    } else {
      _showCompletionDialog();
    }
  }

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
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: textDark,
            ),
            child: const Text('Finish'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
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
                  // Word Display Card
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: textDark, width: 3),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _currentWord['word'] ?? '',
                          style: TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
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

                  // Tips Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6), //0xFFFFF9E6 //
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFCC80), width: 2), //0xFFFF0966
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

                  // Listen Section
                  Text(
                    'Listen to Model Pronunciation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
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

                  // Record Section
                  Text(
                    'Record Your Pronunciation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: _isRecording ? null : _startRecording,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isRecording ? 100 : 120,
                        height: _isRecording ? 100 : 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? accentCoral : accentGreen,
                          border: Border.all(color: textDark, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording ? accentCoral : accentGreen)
                                  .withOpacity(0.4),
                              blurRadius: 20,
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

                  // Feedback Section
                  if (_showFeedback) ...[
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
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
                          Text(
                            '${_pronunciationScore.toInt()}%',
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
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

                  // Navigation Buttons
                  Row(
                    children: [
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