import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class AudioStorageService {
  final FirebaseStorage _storage;

  AudioStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Upload call audio (PCM data) to Firebase Storage.
  /// Returns the download URL.
  /// Path: voice-calls/{uid}/{date}/{timestamp}.pcm
  Future<String> uploadCallAudio({
    required String uid,
    required String date,
    required Uint8List audioData,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('voice-calls/$uid/$date/$timestamp.pcm');

    final metadata = SettableMetadata(
      contentType: 'audio/pcm',
      customMetadata: {
        'sampleRate': '16000',
        'channels': '1',
        'bitDepth': '16',
      },
    );

    await ref.putData(audioData, metadata);
    return await ref.getDownloadURL();
  }

  /// Delete call audio from Firebase Storage.
  Future<void> deleteCallAudio(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Failed to delete audio: $e');
    }
  }
}
