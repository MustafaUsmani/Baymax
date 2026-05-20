class ApiResponse<T> {
  final T? data;
  final String? message;
  final int? code;
  final bool isSuccess;

  ApiResponse.success({required this.data})
      : isSuccess = true,
        message = null,
        code = null;

  ApiResponse.error({required this.message, required this.code})
      : isSuccess = false,
        data = null;

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(Object?) fromJsonT) {
    if (json.containsKey('data')) {
      return ApiResponse.success(data: fromJsonT(json['data']));
    } else {
      return ApiResponse.error(message: json['detail'] ?? 'Error', code: json['code'] ?? 0);
    }
  }
}
