import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chivoice/services/api_proxy.dart';
import 'package:chivoice/services/stt/whisper_stt.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhisperStt', () {
    late _MockDio dio;
    late WhisperStt service;
    late File file;

    setUp(() async {
      dio = _MockDio();
      service = WhisperStt(
        apiProxy: ApiProxy(
          baseUrl: 'https://api.groq.com/openai/v1',
          headers: const {'Authorization': 'Bearer gsk_test'},
        ),
        dio: dio,
      );
      final dir = await Directory.systemTemp.createTemp('voxa_stt_test');
      file = File('${dir.path}/clip.m4a')..writeAsBytesSync([1, 2, 3]);
    });

    test('sends correct multipart fields', () async {
      late FormData captured;
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer((invocation) async {
        captured = invocation.namedArguments[#data] as FormData;
        return Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/audio/transcriptions'),
          data: {'text': 'Hello world'},
        );
      });

      final result = await service.transcribe(file.path, languageCode: 'en-US');

      expect(result, 'Hello world');
      expect(
        captured.fields.any(
          (field) =>
              field.key == 'model' &&
              field.value == GroqWhisperModel.largeV3.id,
        ),
        isTrue,
      );
      expect(
        captured.fields.any(
          (field) => field.key == 'language' && field.value == 'en',
        ),
        isTrue,
      );
      expect(
        captured.fields.any(
          (field) => field.key == 'temperature' && field.value == '0',
        ),
        isTrue,
      );
      expect(
        captured.fields.any(
          (field) =>
              field.key == 'prompt' &&
              field.value.contains('Transcribe only the words'),
        ),
        isTrue,
      );
      expect(captured.files.single.key, 'file');
    });

    test('treats known chinese promo phrase as hallucination', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/audio/transcriptions'),
          data: {'text': '请不吝点赞 订阅 转发 大赏支持明镜与点点栏目'},
        ),
      );

      expect(
        () => service.transcribe(file.path, languageCode: 'zh-CN'),
        throwsA(
          isA<SttRemoteException>().having(
            (error) => error.message,
            'message',
            contains('hallucinated'),
          ),
        ),
      );
    });

    test('handles 401 response', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/audio/transcriptions'),
          response: Response(
            requestOptions: RequestOptions(path: '/audio/transcriptions'),
            statusCode: 401,
            data: 'unauthorized',
          ),
        ),
      );

      expect(
        () => service.transcribe(file.path, languageCode: 'en-US'),
        throwsA(
          isA<SttRemoteException>().having(
            (error) => error.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test('handles 500 response', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/audio/transcriptions'),
          response: Response(
            requestOptions: RequestOptions(path: '/audio/transcriptions'),
            statusCode: 500,
            data: 'server error',
          ),
        ),
      );

      expect(
        () => service.transcribe(file.path, languageCode: 'en-US'),
        throwsA(
          isA<SttRemoteException>().having(
            (error) => error.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });

    test('throws when Groq API key is missing', () async {
      final withoutKey = WhisperStt(
        apiProxy: ApiProxy(baseUrl: 'https://api.groq.com/openai/v1'),
        dio: dio,
      );

      expect(
        () => withoutKey.transcribe(file.path, languageCode: 'en-US'),
        throwsA(
          isA<SttRemoteException>().having(
            (error) => error.message,
            'message',
            contains('Groq API key'),
          ),
        ),
      );
      verifyNever(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      );
    });

    test('uses selected turbo model when requested', () async {
      late FormData captured;
      final turboService = WhisperStt(
        apiProxy: ApiProxy(
          baseUrl: 'https://api.groq.com/openai/v1',
          headers: const {'Authorization': 'Bearer gsk_test'},
        ),
        model: GroqWhisperModel.largeV3Turbo,
        dio: dio,
      );
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer((invocation) async {
        captured = invocation.namedArguments[#data] as FormData;
        return Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/audio/transcriptions'),
          data: {'text': 'Hello world'},
        );
      });

      await turboService.transcribe(file.path, languageCode: 'en-US');

      expect(
        captured.fields.any(
          (field) =>
              field.key == 'model' &&
              field.value == GroqWhisperModel.largeV3Turbo.id,
        ),
        isTrue,
      );
    });

    test(
      'verifyConnection succeeds when selected model is available',
      () async {
        when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
          (_) async => Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/models'),
            data: {
              'data': [
                {'id': GroqWhisperModel.largeV3.id},
                {'id': GroqWhisperModel.largeV3Turbo.id},
              ],
            },
          ),
        );

        await expectLater(
          service.verifyConnection(),
          completion(contains('is available')),
        );
      },
    );

    test('verifyConnection fails when selected model is unavailable', () async {
      final turboService = WhisperStt(
        apiProxy: ApiProxy(
          baseUrl: 'https://api.groq.com/openai/v1',
          headers: const {'Authorization': 'Bearer gsk_test'},
        ),
        model: GroqWhisperModel.largeV3Turbo,
        dio: dio,
      );
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/models'),
          data: {
            'data': [
              {'id': GroqWhisperModel.largeV3.id},
            ],
          },
        ),
      );

      expect(
        () => turboService.verifyConnection(),
        throwsA(
          isA<SttRemoteException>().having(
            (error) => error.message,
            'message',
            contains('not available'),
          ),
        ),
      );
    });
  });
}
