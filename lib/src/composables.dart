import 'package:xserver/src/x_server_context.dart';
import 'package:xserver/xserver.dart';

Request useRequest() {
  return XServerContext.currentRequest;
}
