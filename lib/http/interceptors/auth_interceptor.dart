import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // TODO: 从本地存储获取 Token
    // const String? token = StorageUtils.getToken();
    const String? token = null; // 模拟
    
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // TODO: 可以在这里处理 Token 过期等逻辑
    super.onResponse(response, handler);
  }
}



