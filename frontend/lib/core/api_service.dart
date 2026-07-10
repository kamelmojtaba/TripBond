import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParams,
    String? token,
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      final response = await http
          .get(
            uri,
            headers: ApiConfig.headers(token: token),
          )
          .timeout(ApiConfig.requestTimeout);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on TimeoutException {
      throw ApiException('Request timed out. Please check backend connection.');
    } on http.ClientException {
      throw ApiException('Failed to connect to server');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final uri = _buildUri(path);
      print('POST request to: $uri'); // Debug
      print('Request body: ${jsonEncode(body)}'); // Debug

      final response = await http
          .post(
            uri,
            headers: ApiConfig.headers(token: token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.requestTimeout);

      print('Response status: ${response.statusCode}'); // Debug
      print('Response body: ${response.body}'); // Debug

      return _handleResponse(response);
    } on SocketException {
      print('SocketException: No internet connection'); // Debug
      throw ApiException('No internet connection');
    } on TimeoutException {
      throw ApiException('Request timed out. Please check backend connection.');
    } on http.ClientException catch (e) {
      print('ClientException: $e'); // Debug
      throw ApiException('Failed to connect to server');
    } catch (e) {
      print('Unexpected error: $e'); // Debug
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final uri = _buildUri(path);
      final response = await http
          .put(
            uri,
            headers: ApiConfig.headers(token: token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.requestTimeout);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on TimeoutException {
      throw ApiException('Request timed out. Please check backend connection.');
    } on http.ClientException {
      throw ApiException('Failed to connect to server');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<dynamic> delete(
    String path, {
    String? token,
  }) async {
    try {
      final uri = _buildUri(path);
      final response = await http
          .delete(
            uri,
            headers: ApiConfig.headers(token: token),
          )
          .timeout(ApiConfig.requestTimeout);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on TimeoutException {
      throw ApiException('Request timed out. Please check backend connection.');
    } on http.ClientException {
      throw ApiException('Failed to connect to server');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: ${e.toString()}');
    }
  }

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final url = '${ApiConfig.baseUrl}$path';
    final uri = Uri.parse(url);

    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }

    return uri;
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {'success': true};
      }
      try {
        return jsonDecode(response.body);
      } catch (e) {
        throw ApiException('Failed to parse response');
      }
    } else {
      String errorMessage = 'Request failed';
      try {
        final errorBody = jsonDecode(response.body);
        errorMessage =
            errorBody['detail'] ?? errorBody['message'] ?? errorMessage;
      } catch (e) {
        // Use default error message
      }

      throw ApiException(
        errorMessage,
        statusCode: response.statusCode,
      );
    }
  }
}
