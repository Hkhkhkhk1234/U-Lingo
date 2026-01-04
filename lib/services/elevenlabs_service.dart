import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

/// Service class for integrating ElevenLabs Text-to-Speech API.
/// 
/// Provides high-quality, natural-sounding voice synthesis for the language
/// learning application, specifically configured for multilingual support
/// (Chinese and English) to serve pronunciation practice features.
/// 
/// Key features:
/// - Multilingual TTS with emphasis on Chinese pronunciation accuracy
/// - Configurable voice settings for optimal educational content
/// - Error handling for network failures and API issues
/// 
/// API Documentation: https://elevenlabs.io/docs/api-reference
/// 
/// SECURITY NOTE: API key is currently hardcoded. For production, this should
/// be moved to environment variables or secure cloud configuration.
class ElevenLabsService {
  /// ElevenLabs API authentication key.
  /// 
  /// WARNING: This API key should NOT be committed to version control in production.
  /// Current implementation is for development/testing only.
  /// 
  /// Production recommendation: Use Flutter's --dart-define or a secure
  /// configuration service like Firebase Remote Config or AWS Secrets Manager.
  static const String _apiKey = 'sk_7e3de4a39e5fe3a56dd15a95cb179fc9bb650bec268be441';
  
  /// Base URL for ElevenLabs API v1 endpoints.
  static const String _baseUrl = 'https://api.elevenlabs.io/v1';

  /// Default voice ID for multilingual support.
  /// 
  /// Using "Adam" voice which supports both Chinese and English with
  /// natural pronunciation and consistent quality across languages.
  /// This voice was selected for its clarity in educational contexts
  /// and accurate Chinese tone reproduction.
  static const String _voiceId = 'pNInz6obpgDQGcFmaJgB'; // Adam (multilingual)

  /// Converts text to speech audio using ElevenLabs API.
  /// 
  /// Returns audio data as raw bytes (MP3 format) that can be played
  /// directly through audio players like audioplayers package.
  /// 
  /// Parameters:
  /// - [text]: The text to convert to speech. Supports both Chinese and English.
  /// - [voiceId]: Optional custom voice ID. Defaults to Adam multilingual voice.
  /// 
  /// Returns:
  /// - [Uint8List]: Raw MP3 audio bytes ready for playback
  /// - [null]: If API call fails (network error, quota exceeded, invalid input)
  /// 
  /// Voice Settings Rationale:
  /// - stability (0.5): Balanced between consistency and expressiveness
  /// - similarity_boost (0.75): High fidelity to original voice character
  /// - style (0.0): Neutral delivery appropriate for educational content
  /// - use_speaker_boost (true): Enhanced clarity for language learning
  /// 
  /// Error handling: Returns null on failure with console logging for debugging.
  /// Callers should handle null gracefully (e.g., show cached audio or error message).
  static Future<Uint8List?> textToSpeech(String text, {String? voiceId}) async {
    try {
      final url = Uri.parse('$_baseUrl/text-to-speech/${voiceId ?? _voiceId}');

      final response = await http.post(
        url,
        headers: {
          // Request MP3 audio format for broad compatibility
          'Accept': 'audio/mpeg',
          'Content-Type': 'application/json',
          'xi-api-key': _apiKey,
        },
        body: jsonEncode({
          'text': text,
          // eleven_multilingual_v2 model chosen for superior Chinese pronunciation
          // and cross-language consistency compared to v1
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            // Stability: 0.5 provides natural variation without inconsistency
            // Lower = more expressive, Higher = more consistent
            'stability': 0.5,
            // Similarity boost: 0.75 maintains voice characteristics
            // Important for consistent user experience across lessons
            'similarity_boost': 0.75,
            // Style: 0.0 for neutral educational delivery
            // Non-zero values add dramatic emphasis inappropriate for learning
            'style': 0.0,
            // Speaker boost enhances vocal clarity for pronunciation practice
            'use_speaker_boost': true,
          },
        }),
      );

      if (response.statusCode == 200) {
        // Return raw audio bytes for immediate playback
        return response.bodyBytes;
      } else {
        // Log detailed error info for debugging API issues
        // Common errors: 401 (invalid key), 429 (quota exceeded), 400 (invalid text)
        print('ElevenLabs API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      // Catch network errors, timeouts, or malformed responses
      print('Error calling ElevenLabs API: $e');
      return null;
    }
  }

  /// Retrieves list of available voices from ElevenLabs.
  /// 
  /// Useful for allowing administrators to select different voices
  /// for various languages or content types. Each voice has different
  /// characteristics (age, gender, accent, language support).
  /// 
  /// Returns:
  /// - List of voice objects containing:
  ///   - voice_id: Unique identifier for use in textToSpeech()
  ///   - name: Human-readable voice name
  ///   - labels: Voice characteristics (language, gender, age, etc.)
  /// - Empty list on failure
  /// 
  /// Use case: Admin panel could display available voices and allow
  /// selection of different voices for different lesson types or languages.
  /// 
  /// Note: This endpoint doesn't consume generation quota, only counts
  /// toward API rate limits.
  static Future<List<Map<String, dynamic>>> getVoices() async {
    try {
      final url = Uri.parse('$_baseUrl/voices');

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'xi-api-key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Extract voices array from response, defaulting to empty if missing
        return List<Map<String, dynamic>>.from(data['voices'] ?? []);
      } else {
        print('Error fetching voices: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      // Network errors or JSON parsing failures
      print('Error fetching voices: $e');
      return [];
    }
  }
}
