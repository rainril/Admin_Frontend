import 'package:flutter/foundation.dart';

class AdminApiEndpoints {
  static const String baseUrl = String.fromEnvironment(
    'ADMIN_API_URL',
    defaultValue: kReleaseMode
        ? 'https://admin-primefit-backend.onrender.com/api'
        : 'http://127.0.0.1:8000/api',
  );
}
