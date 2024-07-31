import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:xserver/src/endpoint_util.dart';
import 'package:xserver/xserver.dart';

class XServerGenerator extends GeneratorForAnnotation<Handler> {
  static const TypeChecker _queryChecker = TypeChecker.fromRuntime(Query);
  static const TypeChecker _bodyChecker = TypeChecker.fromRuntime(Body);
  static const TypeChecker _headerChecker = TypeChecker.fromRuntime(Header);
  static const TypeChecker _requestChecker = TypeChecker.fromRuntime(Request);

  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final function = _validateElement(element);
    final parameters = _analyzeParameters(function);
    final isOriginalFunctionAsync = function.returnType.isDartAsyncFuture;
    final isHandlerAsync =
        isOriginalFunctionAsync || parameters.any((p) => p.isAsync);
    return _generateHandlerFunction(
        function.name, isHandlerAsync, isOriginalFunctionAsync, parameters);
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

  List<ParameterInfo> _analyzeParameters(FunctionElement function) {
    bool hasBodyParameter = false;
    return function.parameters.map((param) {
      final paramInfo = ParameterInfo.fromElement(param);

      if (_requestChecker.isExactlyType(param.type)) {
        return paramInfo..injectionCode = 'request';
      }

      if (_queryChecker.hasAnnotationOf(param)) {
        final queryName = _queryChecker
                .firstAnnotationOf(param)
                ?.getField('name')
                ?.toStringValue() ??
            param.name;
        paramInfo.injectionCode =
            _generateInjectionCode('query', queryName, param);
        return paramInfo;
      }

      if (_headerChecker.hasAnnotationOf(param)) {
        final headerName = _headerChecker
                .firstAnnotationOf(param)
                ?.getField('name')
                ?.toStringValue() ??
            param.name;
        paramInfo.injectionCode =
            _generateInjectionCode('header', headerName, param);
        return paramInfo;
      }

      if (_bodyChecker.hasAnnotationOf(param)) {
        if (hasBodyParameter) {
          throw InvalidGenerationSourceError(
            'Only one @Body parameter is allowed per function.',
            element: param,
          );
        }
        hasBodyParameter = true;
        paramInfo.injectionCode = _generateInjectionCode('body', 'body', param);
        paramInfo.isAsync = true;
        return paramInfo;
      }

      throw InvalidGenerationSourceError(
        'Unsupported parameter type. Use @Query, @Header, @Body annotations, or Request type.',
        element: param,
      );
    }).toList();
  }

  String _generateInjectionCode(
      String sourceType, String sourceName, ParameterElement param) {
    final isNullable =
        param.type.nullabilitySuffix == NullabilitySuffix.question;
    final typeName = param.type.getDisplayString(withNullability: false);

    String sourceCode;
    switch (sourceType) {
      case 'query':
        sourceCode = "request.url.queryParameters['$sourceName']";
        break;
      case 'header':
        sourceCode = "request.headers['$sourceName']";
        break;
      case 'body':
        sourceCode = "await request.readAsString()";
        break;
      default:
        throw ArgumentError('Invalid source type: $sourceType');
    }

    return '''
      XServerParser.parseParameter<$typeName>(
        $sourceCode,
        '$sourceName',
        ${isNullable ? 'true' : 'false'},
        '$sourceType',
        ${_hasFromJsonConstructor(param.type) ? '${typeName}.fromJson' : 'null'}
      )
    ''';
  }

  bool _hasFromJsonConstructor(DartType type) {
    if (type is InterfaceType) {
      return type.element.constructors
          .any((c) => c.name == 'fromJson' && c.parameters.length == 1);
    }
    return false;
  }

  String _generateHandlerFunction(String functionName, bool isHandlerAsync,
      bool isOriginalFunctionAsync, List<ParameterInfo> parameters) {
    final returnType = isHandlerAsync ? 'Future<Response>' : 'Response';
    final asyncKeyword = isHandlerAsync ? 'async ' : '';
    final awaitKeyword = isOriginalFunctionAsync ? 'await ' : '';

    final parameterInjections = parameters
        .map((p) => '${p.type} ${p.name} = ${p.injectionCode};')
        .join('\n    ');

    final functionCallParams = parameters
        .map((p) => p.isNamed ? '${p.name}: ${p.name}' : p.name)
        .join(', ');

    return '''
    $returnType ${functionName}Handler(Request request) $asyncKeyword{
      $parameterInjections
      return handleResult($awaitKeyword$functionName($functionCallParams));
    }
    ''';
  }
}

class ParameterInfo {
  final String name;
  final String type;
  final bool isNamed;
  final bool isOptional;
  final String? defaultValueCode;
  String injectionCode = '';
  bool isAsync = false;

  ParameterInfo({
    required this.name,
    required this.type,
    required this.isNamed,
    required this.isOptional,
    this.defaultValueCode,
  });

  factory ParameterInfo.fromElement(ParameterElement element) {
    return ParameterInfo(
      name: element.name,
      type: element.type.getDisplayString(withNullability: true),
      isNamed: element.isNamed,
      isOptional: element.isOptional,
      defaultValueCode: element.defaultValueCode,
    );
  }
}

Builder handlerBuilder(BuilderOptions options) =>
    SharedPartBuilder([XServerGenerator()], 'handler');
