import 'package:dio/dio.dart';

import '../api_proxy.dart';
import 'stt_service.dart';

enum GroqWhisperModel {
  largeV3(
    'whisper-large-v3',
    'Whisper Large v3',
    'Highest accuracy for challenging audio.',
  ),
  largeV3Turbo(
    'whisper-large-v3-turbo',
    'Whisper Large v3 Turbo',
    'Fastest and lower-cost option for real-time transcription.',
  );

  const GroqWhisperModel(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;
}

class WhisperStt implements SttService {
  WhisperStt({
    required ApiProxy apiProxy,
    this.model = GroqWhisperModel.largeV3,
    Dio? dio,
  }) : _apiProxy = apiProxy,
       _dio = dio;

  final ApiProxy _apiProxy;
  final GroqWhisperModel model;
  final Dio? _dio;

  @override
  Future<String> transcribe(
    String audioFilePath, {
    required String languageCode,
  }) async {
    if (!_apiProxy.headers.containsKey('Authorization')) {
      throw const SttRemoteException(
        message: 'Please add your Groq API key in Settings first.',
      );
    }

    final dio = _dio ?? _apiProxy.client();
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(audioFilePath),
        'model': model.id,
        'language': languageCode.split('-').first.toLowerCase(),
      });
      final response = await dio.post<Map<String, dynamic>>(
        '/audio/transcriptions',
        data: formData,
      );
      return (response.data?['text'] as String? ?? '').trim();
    } on DioException catch (error) {
      throw SttRemoteException(
        statusCode: error.response?.statusCode,
        message:
            error.response?.data?.toString() ??
            error.message ??
            'Unknown error',
      );
    }
  }

  Future<String> verifyConnection() async {
    _assertApiKey();

    final dio = _dio ?? _apiProxy.client();
    try {
      final response = await dio.get<Map<String, dynamic>>('/models');
      final data = response.data?['data'];
      final hasModel =
          data is List &&
          data.any((item) => item is Map && item['id'] == model.id);
      if (!hasModel) {
        throw SttRemoteException(
          message:
              'Groq connected, but ${model.label} is not available for this API key.',
        );
      }
      return 'Groq connected. ${model.label} is available.';
    } on DioException catch (error) {
      throw SttRemoteException(
        statusCode: error.response?.statusCode,
        message: _errorMessage(error),
      );
    }
  }

  @override
  Stream<String> streamPartial({required String languageCode}) =>
      const Stream<String>.empty();

  @override
  Future<void> stopStreaming() async {}

  void _assertApiKey() {
    if (!_apiProxy.headers.containsKey('Authorization')) {
      throw const SttRemoteException(
        message: 'Please add your Groq API key in Settings first.',
      );
    }
  }

  String _errorMessage(DioException error) {
    return error.response?.data?.toString() ?? error.message ?? 'Unknown error';
  }
}

class SttRemoteException implements Exception {
  const SttRemoteException({this.statusCode, required this.message});

  final int? statusCode;
  final String message;

  @override
  String toString() => message;
}
