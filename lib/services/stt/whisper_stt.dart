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
  static const String _antiHallucinationPrompt =
      'Transcribe only the words that are actually spoken in the audio. '
      'If there is no clear speech, return an empty string. '
      'Do not add promotional endings, captions, or imagined content.';
  static const Set<String> _knownHallucinationPhrases = {
    '请不吝点赞订阅转发打赏支持明镜与点点栏目',
    '请不吝点赞订阅转发大赏支持明镜与点点栏目',
    '請不吝點讚訂閱轉發打賞支持明鏡與點點欄目',
    '請不吝點讚訂閱轉發大賞支持明鏡與點點欄目',
  };
  static const List<String> _hallucinationKeywords = [
    '点赞',
    '點讚',
    '订阅',
    '訂閱',
    '转发',
    '轉發',
    '打赏',
    '打賞',
    '大赏',
    '大賞',
    '明镜',
    '明鏡',
    '点点栏目',
    '點點欄目',
  ];

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
        'temperature': '0',
        'prompt': _antiHallucinationPrompt,
      });
      final response = await dio.post<Map<String, dynamic>>(
        '/audio/transcriptions',
        data: formData,
      );
      final text = (response.data?['text'] as String? ?? '').trim();
      if (_isLikelyHallucinatedPromo(text)) {
        throw const SttRemoteException(
          message:
              'Cloud transcription returned likely hallucinated promo content.',
        );
      }
      return text;
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

  bool _isLikelyHallucinatedPromo(String text) {
    if (text.isEmpty) {
      return false;
    }
    final normalized = _normalizeForMatch(text);
    if (_knownHallucinationPhrases.contains(normalized)) {
      return true;
    }
    if (normalized.length > 40) {
      return false;
    }
    final hitCount = _hallucinationKeywords
        .where((keyword) => normalized.contains(keyword))
        .length;
    return hitCount >= 4;
  }

  String _normalizeForMatch(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[，。！？；：,.!?;:、"“”‘’()（）\[\]{}]'), '')
        .trim();
  }
}

class SttRemoteException implements Exception {
  const SttRemoteException({this.statusCode, required this.message});

  final int? statusCode;
  final String message;

  @override
  String toString() => message;
}
