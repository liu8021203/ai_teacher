//
// class BaseResult<T> {
//   late int code;
//   late String message;
//   T? data;
//
//   BaseResult();
//
//   // factory BaseResult.fromJson(Map<String, dynamic> json) =>
//   //     _$BaseResultFromJson(json);
//
//   factory BaseResult.fromJson(Map<String, dynamic> json) {
//     BaseResult<T> baseResult = BaseResult();
//     final int? code = json['code'];
//     if (code != null) {
//       baseResult.code = code;
//     }
//     final String? message = json['message'];
//     if (message != null) {
//       baseResult.message = message;
//     }
//     if (T == Null) {
//       baseResult.data = null;
//     } else {
//       final T? data = JsonConvert.fromJsonAsT<T>(json['data']);
//       if (data != null) {
//         baseResult.data = data;
//       }
//     }
//
//     return baseResult;
//   }
//
//   // Map<String, dynamic> toJson() => _$BaseResultToJson(this);
//
//   //
//   // @override
//   // String toString() {
//   //   return jsonEncode(this);
//   // }
// }
