import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voxa/services/api_proxy.dart';
import 'package:voxa/services/stt/whisper_stt.dart';

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
          (field) => field.key == 'model' && field.value == groqWhisperModel,
        ),
        isTrue,
      );
      expect(
        captured.fields.any(
          (field) => field.key == 'language' && field.value == 'en',
        ),
        isTrue,
      );
      expect(captured.files.single.key, 'file');
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
  });
}
