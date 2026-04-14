import 'package:dio/dio.dart';

import '../api_proxy.dart';
import 'whisper_stt.dart';
import 'stt_service.dart';

class GoogleStt implements SttService {
  GoogleStt({required ApiProxy apiProxy, Dio? dio})
    : _apiProxy = apiProxy,
      _dio = dio;

  final ApiProxy _apiProxy;
  final Dio? _dio;

  @override
  Future<String> transcribe(
    String audioFilePath, {
    required String languageCode,
  }) async {
    if (_apiProxy.baseUrl.trim().isEmpty) {
      throw const SttRemoteException(
        message: 'Please add your Google STT proxy URL in Settings first.',
      );
    }

    final dio = _dio ?? _apiProxy.client();
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(audioFilePath),
        'languageCode': languageCode,
      });
      final response = await dio.post<Map<String, dynamic>>(
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
