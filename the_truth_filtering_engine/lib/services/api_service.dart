import 'package:dio/dio.dart';
import '../models/search_result.dart';
import '../models/review_item.dart';

class ApiService {
  final _dio = Dio(BaseOptions(
    baseUrl: 'http://172.30.1.19:8000/api',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60), // LLM 응답 오래 걸릴 수 있음
  ));

  Future<SearchResult> search(String query) async {
    final res = await _dio.get('/search', queryParameters: {'query': query});
    return SearchResult.fromJson(res.data);
  }
}
