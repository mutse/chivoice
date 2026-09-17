import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../api_proxy.dart';
import 'stt_service.dart';
import 'whisper_stt.dart';

class CloudflareStt implements SttService {
  CloudflareStt({
    required this.apiProxy,
    required this.accountId,
    required this.modelId,
    Dio? dio,
  }) : _dio = dio;

  final ApiProxy apiProxy;
  final String accountId;
  final String modelId;
  final Dio? _dio;

  static const models = [
    '@cf/openai/whisper-large-v3-turbo',
    '@cf/openai/whisper',
  ];

  void _validate() {
    final uri = Uri.tryParse(apiProxy.baseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const SttRemoteException(
        message: '请填写有效的 Cloudflare HTTPS API 地址。',
      );
    }
    if (!RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(accountId.trim())) {
      throw const SttRemoteException(
        message: '请填写 32 位 Cloudflare Account ID。',
      );
    }
    final authorization = apiProxy.headers['Authorization'] ?? '';
    if (!authorization.startsWith('Bearer ') ||
        authorization.substring(7).trim().isEmpty) {
      throw const SttRemoteException(message: '请先填写 Cloudflare API Token。');
    }
    if (!models.contains(modelId)) {
      throw const SttRemoteException(message: '请选择支持的 Cloudflare Whisper 模型。');
    }
  }

  @override
  Future<String> transcribe(
    String audioFilePath, {
    required String languageCode,
  }) async {
    _validate();
    return _transcribeBytes(
      await File(audioFilePath).readAsBytes(),
      languageCode,
    );
  }

  Future<String> _transcribeBytes(Uint8List bytes, String languageCode) async {
    final turbo = modelId == models.first;
    final dio = _dio ?? apiProxy.client();
    final baseUrl = apiProxy.baseUrl.replaceFirst(RegExp(r'/+$'), '');
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '$baseUrl/accounts/${accountId.trim()}/ai/run/$modelId',
        data: turbo
            ? {
                'audio': base64Encode(bytes),
                'language': languageCode
                    .split(RegExp('[-_]'))
                    .first
                    .toLowerCase(),
                'task': 'transcribe',
              }
            : bytes,
        options: Options(
          headers: apiProxy.headers,
          contentType: turbo
              ? Headers.jsonContentType
              : 'application/octet-stream',
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      final data = response.data;
      if (data?['success'] == false) {
        throw SttRemoteException(message: 'Cloudflare 转写失败：${data?['errors']}');
      }
      final result = data?['result'];
      if (result is! Map || result['text'] is! String) {
        throw const SttRemoteException(message: 'Cloudflare 返回了无效的转写结果。');
      }
      return (result['text'] as String).trim();
    } on DioException catch (error) {
      throw SttRemoteException(
        statusCode: error.response?.statusCode,
        message: 'Cloudflare 请求失败：${error.response?.data ?? error.message}',
      );
    }
  }

  /// A real inference verifies account, token permissions, and the selected model.
  Future<String> verifyConnection() async {
    _validate();
    final wav = Uint8List(44 + 32000);
    final header = ByteData.sublistView(wav);
    wav.setRange(0, 4, ascii.encode('RIFF'));
    header.setUint32(4, wav.length - 8, Endian.little);
    wav.setRange(8, 16, ascii.encode('WAVEfmt '));
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, 16000, Endian.little);
    header.setUint32(28, 32000, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    wav.setRange(36, 40, ascii.encode('data'));
    header.setUint32(40, 32000, Endian.little);
    await _transcribeBytes(wav, 'en');
    return 'Cloudflare 连接成功，$modelId 可用。';
  }

  @override
  Stream<String> streamPartial({required String languageCode}) =>
      const Stream.empty();

  @override
  Future<void> stopStreaming() async {}
}
