import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final Dio _dio = Dio();

  /// Ambil token dari SharedPreferences
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// GET request dengan token
  static Future get(
    String url, {
    Map<String, dynamic>? params,
    Map<String, dynamic>? headers,
    ResponseType? responseType, // Sudah ada
  }) async {
    final token = await getToken();
    final combinedHeaders = {
      'accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };
    return _dio.get(
      url,
      queryParameters: params,
      options: Options(
        headers: combinedHeaders,
        responseType: responseType ?? ResponseType.json, // Sudah benar
      ),
    );
  }

  /// POST request dengan token
  static Future<Response> post(
    String url, {
    dynamic data,
    Map<String, dynamic>? headers,
    String? contentType,
    ResponseType? responseType,
    ValidateStatus? validateStatus,
  }) async {
    final token = await getToken();
    final combinedHeaders = {
      'Accept': 'application/json',
      if (contentType != null) 'Content-Type': contentType,
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };
    return _dio.post(
      url,
      data: data,
      options: Options(
        headers: combinedHeaders,
        responseType: responseType ?? ResponseType.json,
        validateStatus: validateStatus,
      ),
    );
  }

  /// PUT request dengan token
  static Future<Response> put(
    String url, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    final token = await getToken();
    final combinedHeaders = {
      'accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };
    return _dio.put(
      url,
      data: data,
      options: Options(headers: combinedHeaders),
    );
  }

  /// DELETE request dengan token
  static Future<Response> delete(
    String url, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    final token = await getToken();
    final combinedHeaders = {
      'accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };
    return _dio.delete(
      url,
      data: data,
      options: Options(headers: combinedHeaders),
    );
  }

  /// Mendapatkan headers dengan token (misal untuk upload, export, dst)
  static Future<Map<String, String>> getHeaders(
      {Map<String, String>? extra}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final headers = {
      if (token != null) 'Authorization': 'Bearer $token',
      ...?extra,
    };
    return headers;
  }
}
