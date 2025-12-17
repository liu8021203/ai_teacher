class BaseResult<T> {
  final int code;
  final String message;
  final T? data;

  BaseResult({required this.code, required this.message, this.data});

  factory BaseResult.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    return BaseResult<T>(
      code: json['code'] as int? ?? -1,
      message: json['message'] as String? ?? '',
      data: json['data'] != null ? fromJsonT(json['data']) : null,
    );
  }

  bool get isSuccess => code == 0;
}
