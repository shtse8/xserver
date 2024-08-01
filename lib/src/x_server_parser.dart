import 'dart:convert';

class XServerParser {
  static T parseParameter<T>(
      dynamic value, String paramName, bool isNullable, String sourceType,
      [T Function(Map<String, dynamic>)? fromJson]) {
    if (value == null) {
      if (isNullable) return null as T;
      throw BadRequestException(
          'Required $sourceType parameter "$paramName" is missing');
    }

    try {
      if (T == String) {
        return value.toString() as T;
      } else if (T == int) {
        return int.parse(value.toString()) as T;
      } else if (T == double) {
        return double.parse(value.toString()) as T;
      } else if (T == bool) {
        return bool.parse(value.toString()) as T;
      } else if (fromJson != null) {
        // For complex types with fromJson constructor
        final jsonData = value is String ? jsonDecode(value) : value;
        return fromJson(jsonData as Map<String, dynamic>);
      } else {
        // For other complex types, assume JSON
        final jsonData = value is String ? jsonDecode(value) : value;
        return jsonData as T;
      }
    } catch (e) {
      throw BadRequestException('Failed to parse $paramName as $T: $e');
    }
  }
}

class BadRequestException implements Exception {
  final String message;
  BadRequestException(this.message);
}
