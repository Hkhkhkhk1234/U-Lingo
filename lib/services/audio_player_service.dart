import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Singleton service for managing audio playback in the language learning app.
/// 
/// Provides a centralized audio player to handle pronunciation playback from
/// TTS services (like ElevenLabs). Using a single static instance prevents
/// multiple simultaneous audio streams and ensures clean playback transitions.
/// 
/// Key features:
/// - Automatic stop of previous audio when new audio starts
/// - Playback state tracking to prevent overlapping audio
/// - Memory-efficient playback from byte streams (no file writing required)
/// - Proper resource cleanup via dispose method
/// 
/// Use case: When a student taps the pronunciation button for "你好",
/// any currently playing audio stops immediately before the new audio plays,
/// preventing confusing audio overlap during rapid successive taps.
class AudioPlayerService {
  /// Single shared AudioPlayer instance for entire app.
  /// 
  /// Static instance ensures:
  /// 1. Only one audio stream plays at a time across all screens
  /// 2. No resource waste from creating multiple player instances
  /// 3. Consistent audio behavior throughout the app
  /// 
  /// Trade-off: Cannot play multiple audio sources simultaneously,
  /// which is actually desired behavior for pronunciation practice.
  static final AudioPlayer _player = AudioPlayer();
  
  /// Tracks whether audio is currently playing.
  /// 
  /// Prevents race conditions where rapid button taps might cause
  /// overlapping audio playback before the player's internal state updates.
  /// Updated synchronously for immediate state reflection.
  static bool _isPlaying = false;

  /// Plays audio from raw byte data (typically MP3 from TTS service).
  /// 
  /// Automatically stops any currently playing audio before starting new playback
  /// to prevent audio overlap and ensure clean transitions between pronunciations.
  /// 
  /// Implementation details:
  /// - Uses BytesSource for direct memory playback (no temporary files)
  /// - Listens for completion to update state automatically
  /// - Handles errors gracefully by resetting playback state
  /// 
  /// Parameters:
  /// - [audioBytes]: Raw audio data (MP3/WAV format) from TTS service
  /// 
  /// Common usage:
  /// ```dart
  /// final audioBytes = await ElevenLabsService.textToSpeech("你好");
  /// if (audioBytes != null) {
  ///   await AudioPlayerService.playAudio(audioBytes);
  /// }
  /// ```
  /// 
  /// Note: Each new call to playAudio() stops previous audio, so rapid
  /// successive calls will interrupt earlier pronunciations. This is
  /// intentional for responsive UI during pronunciation practice.
  static Future<void> playAudio(Uint8List audioBytes) async {
    try {
      // Stop any currently playing audio to prevent overlap
      // Critical for educational apps where clarity is paramount
      if (_isPlaying) {
        await _player.stop();
      }

      // Set state immediately to prevent race conditions from rapid taps
      _isPlaying = true;
      
      // BytesSource plays audio directly from memory without file I/O
      // More efficient than writing to temp file first
      await _player.play(BytesSource(audioBytes));

      // Listen for natural completion (not manual stop)
      // Stream subscription automatically cleaned up when player stopped
      _player.onPlayerComplete.listen((_) {
        _isPlaying = false;
      });
    } catch (e) {
      // Catch decoder errors, unsupported formats, or platform issues
      print('Error playing audio: $e');
      _isPlaying = false; // Reset state to prevent stuck "playing" status
    }
  }

  /// Immediately stops any currently playing audio.
  /// 
  /// Useful for:
  /// - User clicking a "stop" button during playback
  /// - Navigating away from a screen with active audio
  /// - Implementing pause functionality
  /// 
  /// Always resets playback state to prevent UI showing incorrect status.
  static Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
  }

  /// Returns current playback state.
  /// 
  /// Useful for UI elements that need to show play/stop button states
  /// or disable interactions during audio playback.
  /// 
  /// Example:
  /// ```dart
  /// IconButton(
  ///   icon: Icon(AudioPlayerService.isPlaying ? Icons.stop : Icons.play),
  ///   onPressed: () => playPronunciation(),
  /// )
  /// ```
  static bool get isPlaying => _isPlaying;

  /// Releases audio player resources.
  /// 
  /// CRITICAL: Must be called when the service is no longer needed to prevent
  /// memory leaks and release platform audio resources.
  /// 
  /// Recommended usage: Call in app's dispose() or when switching to a mode
  /// that doesn't need audio (though typically kept alive for app lifecycle).
  /// 
  /// Warning: After dispose(), the player cannot be used again without
  /// recreating the service. Since this is a static singleton, disposal
  /// should only happen on app termination or major state changes.
  static Future<void> dispose() async {
    await _player.dispose();
  }
}
