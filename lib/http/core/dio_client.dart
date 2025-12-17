import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../exception/http_exception.dart';
import '../interceptors/auth_interceptor.dart';
import '../model/api_response.dart';
import 'http_options.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();

  factory DioClient() => _instance;

  late Dio _dio;

  DioClient._internal() {
    BaseOptions options = BaseOptions(
      baseUrl: HttpOptions.baseUrl,
      connectTimeout: HttpOptions.connectTimeout,
      receiveTimeout: HttpOptions.receiveTimeout,
      sendTimeout: HttpOptions.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    _dio = Dio(options);

    // 日志拦截器
    _dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        compact: true,
      ),
    );

    // 认证拦截器
    _dio.interceptors.add(AuthInterceptor());
  }

  Dio get dio => _dio;

  /// GET 请求
  Future<T?> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final Response response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// POST 请求
  Future<T?> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    T? Function(dynamic)? fromJson,
  }) async {
    try {
      final Response response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT 请求
  Future<T?> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final Response response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE 请求
  Future<T?> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final Response response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 响应处理
  T? _handleResponse<T>(Response response, T? Function(dynamic)? fromJson) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final dynamic responseData = response.data;

      // 1. 判断是否符合 BaseResult 结构 (含有 code 字段)
      if (responseData is Map<String, dynamic> &&
          responseData.containsKey('code')) {
        // 先解析最外层的 BaseResult
        final baseResult = BaseResult<dynamic>.fromJson(
          responseData,
          (data) => data, // 暂时不转换 data 内容，只取出来
        );

        // 2. 检查业务状态码
        if (baseResult.code != 0) {
          throw HttpException(
            code: baseResult.code,
            message: baseResult.message,
          );
        }

        // 3. 提取 data 并进行转换
        final data = baseResult.data;
        // if (fromJson != null) {
        return fromJson?.call(data);
        // }
        // return data as T;
      }

      // 非标准结构，直接处理整个 body
      if (fromJson != null) {
        return fromJson(responseData);
      }
      return responseData as T;
    } else {
      throw HttpException(
        code: response.statusCode ?? -1,
        message: response.statusMessage,
      );
    }
  }

  /// 错误处理
  Exception _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return NetworkException(message: "网络连接超时");
        case DioExceptionType.badResponse:
          final int? statusCode = error.response?.statusCode;
          switch (statusCode) {
            case 400:
              return BadRequestException(message: "请求语法错误");
            case 401:
              return UnauthorizedException(message: "没有权限");
            case 403:
              return ForbiddenException(message: "服务器拒绝执行");
            case 404:
              return NotFoundException(message: "无法连接服务器");
            case 500:
              return InternalServerErrorException(message: "服务器内部错误");
            default:
              return NetworkException(message: "网络错误: $statusCode");
          }
        case DioExceptionType.cancel:
          return NetworkException(message: "请求被取消");
        case DioExceptionType.unknown:
          if (error.error is Exception) {
            return error.error as Exception;
          }
          return NetworkException(message: "网络异常，请检查网络");
        default:
          return NetworkException(message: "未知网络错误");
      }
    } else if (error is HttpException) {
      return error;
    } else {
      return NetworkException(message: "未知错误: $error");
    }
  }
}
