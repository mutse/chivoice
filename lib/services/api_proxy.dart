import 'package:dio/dio.dart';

class ApiProxy {
  ApiProxy({required this.proxyBaseUrl});

  final String proxyBaseUrl;

  Dio client() {
    return Dio(
      BaseOptions(
        baseUrl: proxyBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 40),
      ),
    );
  }
}
