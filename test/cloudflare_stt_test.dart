import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chivoice/services/api_proxy.dart';
import 'package:chivoice/services/stt/cloudflare_stt.dart';
import 'package:chivoice/services/stt/whisper_stt.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late File file;
  late RequestOptions unused;
  late Object? payload;
  late String url;
  late Options options;
  Map<String, dynamic> response = {};

  CloudflareStt service({
    String model = '@cf/openai/whisper-large-v3-turbo',
    String account = '0123456789abcdef0123456789abcdef',
  }) => CloudflareStt(
    apiProxy: ApiProxy(
      baseUrl: 'https://api.cloudflare.com/client/v4/',
      headers: {'Authorization': 'Bearer test-token'},
    ),
    accountId: account,
    modelId: model,
    dio: dio,
  );

  setUp(() async {
    dio = _MockDio();
    final dir = await Directory.systemTemp.createTemp('cloudflare_stt');
    addTearDown(() => dir.delete(recursive: true));
    file = File('${dir.path}/audio.m4a');
    await file.writeAsBytes([1, 2, 3]);
    unused = RequestOptions(path: '');
    response = {
      'success': true,
      'result': {'text': '  你好  '},
    };
    when(
      () => dio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((call) async {
      payload = call.namedArguments[#data];
      url = call.positionalArguments.first as String;
      options = call.namedArguments[#options] as Options;
      return Response(requestOptions: unused, data: response);
    });
  });

  test(
    'turbo uses base64 JSON, locale and Cloudflare response envelope',
    () async {
      expect(
        await service().transcribe(file.path, languageCode: 'zh-CN'),
        '你好',
      );
      expect(
        url,
        'https://api.cloudflare.com/client/v4/accounts/0123456789abcdef0123456789abcdef/ai/run/@cf/openai/whisper-large-v3-turbo',
      );
      expect(payload, {
        'audio': base64Encode([1, 2, 3]),
        'language': 'zh',
        'task': 'transcribe',
      });
      expect(options.headers?['Authorization'], 'Bearer test-token');
    },
  );

  test('original Whisper uploads binary audio', () async {
    await service(
      model: '@cf/openai/whisper',
    ).transcribe(file.path, languageCode: 'en');
    expect(payload, [1, 2, 3]);
    expect(options.contentType, 'application/octet-stream');
  });

  test('connection test sends a valid one-second WAV', () async {
    await service().verifyConnection();
    final wav = base64Decode((payload as Map)['audio'] as String);
    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    expect(wav.length, 32044);
    expect(ByteData.sublistView(wav).getUint32(24, Endian.little), 16000);
  });

  test('rejects invalid account before accessing audio', () async {
    await expectLater(
      service(account: '').transcribe('missing', languageCode: 'zh'),
      throwsA(isA<SttRemoteException>()),
    );
    verifyZeroInteractions(dio);
  });

  test('surfaces API errors and malformed success results', () async {
    response = {
      'success': false,
      'errors': [
        {'message': 'Unauthorized'},
      ],
    };
    await expectLater(
      service().transcribe(file.path, languageCode: 'zh'),
      throwsA(isA<SttRemoteException>()),
    );
    response = {'success': true, 'result': {}};
    await expectLater(
      service().transcribe(file.path, languageCode: 'zh'),
      throwsA(isA<SttRemoteException>()),
    );
  });
}
