class HttpException implements Exception {
  final int code;
  final String? message;

  HttpException({required this.code, this.message});

  @override
  String toString() {
    return 'HttpException{code: $code, message: $message}';
  }
}

class BadRequestException extends HttpException {
  BadRequestException({String? message}) : super(code: 400, message: message);
}

class UnauthorizedException extends HttpException {
  UnauthorizedException({String? message}) : super(code: 401, message: message);
}

class ForbiddenException extends HttpException {
  ForbiddenException({String? message}) : super(code: 403, message: message);
}

class NotFoundException extends HttpException {
  NotFoundException({String? message}) : super(code: 404, message: message);
}

class InternalServerErrorException extends HttpException {
  InternalServerErrorException({String? message})
    : super(code: 500, message: message);
}

class NetworkException extends HttpException {
  NetworkException({String? message})
    : super(code: -1, message: message ?? "网络连接异常，请检查网络设置");
}


