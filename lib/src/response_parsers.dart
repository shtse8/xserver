import 'dart:convert';

class ResponseParsers {
  static String parseString(String response) => response;

  static int parseInt(String response) => int.parse(response);

  static double parseDouble(String response) => double.parse(response);

  static bool parseBool(String response) => bool.parse(response);

  static Map<String, dynamic> parseJson(String response) =>
      json.decode(response);

  static List<T> parseList<T>(String response, T Function(dynamic) fromJson) {
    final List<dynamic> jsonList = json.decode(response);
    return jsonList.map((item) => fromJson(item)).toList();
  }

  static T parseObject<T>(
      String response, T Function(Map<String, dynamic>) fromJson) {
    final Map<String, dynamic> jsonMap = json.decode(response);
    return fromJson(jsonMap);
  }
}
