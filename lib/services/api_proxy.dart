import 'package:dio/dio.dart';

class ApiProxy {
  ApiProxy({required this.baseUrl, this.headers = const {}});

  final String baseUrl;
  final Map<String, String> headers;

  Dio client() {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: headers,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 40),
      ),
    );
  }
}
