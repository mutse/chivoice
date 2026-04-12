import 'package:dio/dio.dart';

import '../api_proxy.dart';
import 'whisper_stt.dart';
import 'stt_service.dart';

class GoogleStt implements SttService {
  GoogleStt({required ApiProxy apiProxy, Dio? dio})
    : _dio = dio ?? apiProxy.client();

  final Dio _dio;

  @override
  Future<String> transcribe(
    String audioFilePath, {
    required String languageCode,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(audioFilePath),
        'languageCode': languageCode,
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/google/speech-to-text',
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
