import 'package:dio/dio.dart';

import '../api_proxy.dart';
import 'stt_service.dart';

const groqWhisperModel = 'whisper-large-v3';

class WhisperStt implements SttService {
  WhisperStt({required ApiProxy apiProxy, Dio? dio})
    : _apiProxy = apiProxy,
      _dio = dio;

  final ApiProxy _apiProxy;
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
        'model': groqWhisperModel,
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

  @override
  Stream<String> streamPartial({required String languageCode}) =>
      const Stream<String>.empty();

  @override
  Future<void> stopStreaming() async {}
}

class SttRemoteException implements Exception {
  const SttRemoteException({this.statusCode, required this.message});

  final int? statusCode;
  final String message;

  @override
  String toString() => message;
}
