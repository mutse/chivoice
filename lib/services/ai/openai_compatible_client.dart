import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../api_proxy.dart';

class AiRemoteException implements Exception {
  const AiRemoteException({this.statusCode, required this.message});

  final int? statusCode;
  final String message;

  @override
  String toString() => message;
}

class OpenAiCompatibleClient {
  OpenAiCompatibleClient({
    required ApiProxy apiProxy,
    required this.model,
    Dio? dio,
  }) : _apiProxy = apiProxy,
       _dio = dio;

  final ApiProxy _apiProxy;
  final String model;
  final Dio? _dio;

  Future<String> complete({
    required String systemPrompt,
    required String userText,
    double temperature = 0.3,
    int maxTokens = 1024,
  }) async {
    _assertApiKey();
    final dio = _dio ?? _apiProxy.client();
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/chat/completions',
        data: {
          'model': model,
          'temperature': temperature,
          'max_tokens': maxTokens,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userText},
          ],
        },
      );
      final content = _extractContent(response.data);
      if (content.isEmpty) {
        throw const AiRemoteException(
          message: 'AI provider returned an empty response.',
        );
      }
      return content;
    } on DioException catch (error) {
      throw AiRemoteException(
        statusCode: error.response?.statusCode,
        message: _errorMessage(error),
      );
    }
  }

  Stream<String> completeStream({
    required String systemPrompt,
    required String userText,
    double temperature = 0.3,
    int maxTokens = 1024,
  }) async* {
    _assertApiKey();
    final dio = _dio ?? _apiProxy.client();
    final Response<ResponseBody> response;
    try {
      response = await dio.post<ResponseBody>(
        '/chat/completions',
        data: {
          'model': model,
          'temperature': temperature,
          'max_tokens': maxTokens,
          'stream': true,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userText},
          ],
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );
    } on DioException catch (error) {
      throw AiRemoteException(
        statusCode: error.response?.statusCode,
        message: _errorMessage(error),
      );
    }

    final body = response.data;
    if (body == null) {
      throw const AiRemoteException(
        message: 'AI provider returned no streaming body.',
      );
    }

    final lines = body.stream
        .map(utf8.decode)
        .transform(const LineSplitter());
    await for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || !line.startsWith('data:')) {
        continue;
      }
      final payload = line.substring(5).trim();
      if (payload == '[DONE]') {
        break;
      }
      try {
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        final delta = _extractDelta(decoded);
        if (delta.isNotEmpty) {
          yield delta;
        }
      } on FormatException {
        continue;
      }
    }
  }

  Future<String> verifyConnection() async {
    _assertApiKey();
    final dio = _dio ?? _apiProxy.client();
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/chat/completions',
        data: {
          'model': model,
          'max_tokens': 8,
          'messages': [
            {'role': 'user', 'content': 'ping'},
          ],
        },
      );
      final content = _extractContent(response.data);
      if (content.isEmpty) {
        throw const AiRemoteException(
          message: 'Provider reachable but returned empty content.',
        );
      }
      return 'AI 已联通，模型 $model 可用。';
    } on DioException catch (error) {
      throw AiRemoteException(
        statusCode: error.response?.statusCode,
        message: _errorMessage(error),
      );
    }
  }

  void _assertApiKey() {
    if (!_apiProxy.headers.containsKey('Authorization')) {
      throw const AiRemoteException(
        message: '请先在设置中填入 AI API Key。',
      );
    }
  }

  static String _extractContent(Map<String, dynamic>? data) {
    if (data == null) {
      return '';
    }
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      return '';
    }
    final first = choices.first;
    if (first is! Map) {
      return '';
    }
    final message = first['message'];
    if (message is! Map) {
      return '';
    }
    final content = message['content'];
    if (content is String) {
      return content.trim();
    }
    return '';
  }

  static String _extractDelta(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      return '';
    }
    final first = choices.first;
    if (first is! Map) {
      return '';
    }
    final delta = first['delta'];
    if (delta is! Map) {
      return '';
    }
    final content = delta['content'];
    return content is String ? content : '';
  }

  static String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final inner = data['error'] as Map;
      final msg = inner['message'];
      if (msg is String) {
        return msg;
      }
    }
    return data?.toString() ?? error.message ?? 'Unknown error';
  }
}
