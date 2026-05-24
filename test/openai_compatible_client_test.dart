import 'package:chivoice/services/ai/openai_compatible_client.dart';
import 'package:chivoice/services/api_proxy.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OpenAiCompatibleClient', () {
    late _MockDio dio;
    late OpenAiCompatibleClient client;

    setUp(() {
      dio = _MockDio();
      client = OpenAiCompatibleClient(
        apiProxy: ApiProxy(
          baseUrl: 'https://api.groq.com/openai/v1',
          headers: const {'Authorization': 'Bearer test'},
        ),
        model: 'llama-3.3-70b-versatile',
        dio: dio,
      );
    });

    test('complete returns choices[0].message.content', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/chat/completions'),
          data: {
            'choices': [
              {
                'message': {'content': '清理后的文本'},
              },
            ],
          },
        ),
      );

      final result = await client.complete(
        systemPrompt: 'system',
        userText: 'user',
      );
      expect(result, '清理后的文本');
    });

    test('complete sends correct payload structure', () async {
      Map<String, dynamic>? capturedData;
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer((invocation) async {
        capturedData = invocation.namedArguments[#data] as Map<String, dynamic>;
        return Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/chat/completions'),
          data: {
            'choices': [
              {
                'message': {'content': 'ok'},
              },
            ],
          },
        );
      });

      await client.complete(
        systemPrompt: 'sys',
        userText: 'usr',
        temperature: 0.7,
      );

      expect(capturedData?['model'], 'llama-3.3-70b-versatile');
      expect(capturedData?['temperature'], 0.7);
      final messages = capturedData?['messages'] as List;
      expect(messages.length, 2);
      expect(messages[0], {'role': 'system', 'content': 'sys'});
      expect(messages[1], {'role': 'user', 'content': 'usr'});
    });

    test('complete throws AiRemoteException with message when 401', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/chat/completions'),
          response: Response(
            requestOptions: RequestOptions(path: '/chat/completions'),
            statusCode: 401,
            data: {
              'error': {'message': 'Invalid API key'},
            },
          ),
        ),
      );

      expect(
        () => client.complete(systemPrompt: 's', userText: 'u'),
        throwsA(
          isA<AiRemoteException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Invalid API key'),
        ),
      );
    });

    test('complete throws when API key missing', () async {
      final noKey = OpenAiCompatibleClient(
        apiProxy: ApiProxy(baseUrl: 'https://api.groq.com/openai/v1'),
        model: 'm',
        dio: dio,
      );
      expect(
        () => noKey.complete(systemPrompt: 's', userText: 'u'),
        throwsA(isA<AiRemoteException>()),
      );
      verifyNever(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      );
    });

    test('complete throws when content is empty', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/chat/completions'),
          data: {
            'choices': [
              {
                'message': {'content': '   '},
              },
            ],
          },
        ),
      );
      expect(
        () => client.complete(systemPrompt: 's', userText: 'u'),
        throwsA(
          isA<AiRemoteException>().having(
            (e) => e.message,
            'message',
            contains('empty'),
          ),
        ),
      );
    });
  });
}
