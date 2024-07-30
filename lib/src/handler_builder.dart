import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:xserver/src/endpoint_util.dart';
import 'package:xserver/xserver.dart';

class XServerGenerator extends GeneratorForAnnotation<Handler> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final functionElement = _validateElement(element);
    final functionName = functionElement.name;
    final isAsync = functionElement.returnType.isDartAsyncFuture;

    return _generateHandlerFunction(functionName, isAsync);
  }

  FunctionElement _validateElement(Element element) {
    if (element is! FunctionElement) {
      throw InvalidGenerationSourceError(
        'Handler annotation can only be applied to functions.',
        element: element,
      );
    }
    return element;
  }

  String _generateHandlerFunction(String functionName, bool isAsync) {
    final returnType = isAsync ? 'Future<Response>' : 'Response';
    final asyncKeyword = isAsync ? 'async ' : '';
    final awaitKeyword = isAsync ? 'await ' : '';

    return '''
    $returnType ${functionName}Handler(Request request) $asyncKeyword{
      return handleResult($awaitKeyword$functionName(request));
    }
    ''';
  }
}

Builder handlerBuilder(BuilderOptions options) =>
    SharedPartBuilder([XServerGenerator()], 'handler');
