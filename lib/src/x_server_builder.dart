import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:build/build.dart';
import 'package:collection/collection.dart';
import 'package:source_gen/source_gen.dart';
import 'package:xserver/xserver.dart';
import 'package:xserver/src/x_server_response_handler.dart';
import 'package:shelf/shelf.dart' show Request;

class XServerGenerator extends GeneratorForAnnotation<XServer> {
  static const TypeChecker _requestChecker = TypeChecker.fromRuntime(Request);
  static const TypeChecker _queryChecker = TypeChecker.fromRuntime(Query);
  static const TypeChecker _bodyChecker = TypeChecker.fromRuntime(Body);
  static const TypeChecker _headerChecker = TypeChecker.fromRuntime(Header);
  static const TypeChecker _pathChecker = TypeChecker.fromRuntime(Path);
  static const TypeChecker _allChecker = TypeChecker.fromRuntime(All);
  static const TypeChecker _getChecker = TypeChecker.fromRuntime(Get);
  static const TypeChecker _postChecker = TypeChecker.fromRuntime(Post);

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
          'XServer annotation can only be applied to classes.',
          element: element);
    }

    final className = element.name;
    final handlers = _findHandlers(element);
    final sharedInterface = _generateSharedInterface(className, handlers);
    final serverClass = _generateServerBaseClass(className, handlers);
    final clientClass = _generateClientClass(className, handlers);

    return '$sharedInterface\n\n$serverClass\n\n$clientClass';
  }

  String _generateSharedInterface(
      String className, List<HandlerInfo> handlers) {
    final buffer = StringBuffer();
    buffer.writeln('abstract class I$className {');
    for (var handler in handlers) {
      buffer.writeln(_generateInterfaceMethod(handler));
    }
    buffer.writeln('}');
    return buffer.toString();
  }

  String _generateInterfaceMethod(HandlerInfo handler) {
    final returnType =
        handler.returnType.getDisplayString(withNullability: true);
    final params = _generateMethodParameters(handler.parameters,
        excludeRequestParam: true);
    return '$returnType ${handler.name}$params;';
  }

  String _generateMethodParameters(List<ParameterElement> parameters,
      {bool excludeRequestParam = false}) {
    final positionalParams = <String>[];
    final optionalPositionalParams = <String>[];
    final namedParams = <String>[];

    for (var param in parameters) {
      if (excludeRequestParam && _isRequestParameter(param)) continue;

      final paramType = param.type.getDisplayString(withNullability: true);
      final paramString = '$paramType ${param.name}';

      if (param.isNamed) {
        namedParams.add(
            '${param.isRequired ? 'required ' : ''}$paramString${param.hasDefaultValue ? ' = ${param.defaultValueCode}' : ''}');
      } else if (param.isOptionalPositional) {
        optionalPositionalParams.add(paramString);
      } else {
        positionalParams.add(paramString);
      }
    }

    final sb = StringBuffer('(');
    sb.writeAll(positionalParams, ', ');
    if (optionalPositionalParams.isNotEmpty) {
      if (positionalParams.isNotEmpty) sb.write(', ');
      sb.write('[');
      sb.writeAll(optionalPositionalParams, ', ');
      sb.write(']');
    }
    if (namedParams.isNotEmpty) {
      if (positionalParams.isNotEmpty || optionalPositionalParams.isNotEmpty)
        sb.write(', ');
      sb.write('{');
      sb.writeAll(namedParams, ', ');
      sb.write('}');
    }
    sb.write(')');

    return sb.toString();
  }

  List<HandlerInfo> _findHandlers(ClassElement classElement) {
    final handlers = <HandlerInfo>[];
    for (var method in classElement.methods) {
      final handlerAnnotation = _getHandlerAnnotation(method);
      if (handlerAnnotation != null) {
        _validateHandlerMethod(method);
        final httpMethod = _getHttpMethod(handlerAnnotation);
        final path = _getPath(handlerAnnotation);
        handlers.add(HandlerInfo(method.name, httpMethod, path!,
            method.parameters, method.returnType));
      }
    }
    return handlers;
  }

  void _validateHandlerMethod(MethodElement method) {
    final returnType = method.returnType;
    if (!(returnType.isDartAsyncFuture || returnType.isDartAsyncStream)) {
      throw InvalidGenerationSourceError(
        'Handler methods must return Future or Stream.',
        element: method,
      );
    }

    final innerType = _getInnerType(returnType);
    if (!_isSerializable(innerType)) {
      throw InvalidGenerationSourceError(
        'Return type ${innerType.getDisplayString(withNullability: false)} must be serializable. '
        'Ensure it has a `toJson` method and a `fromJson` constructor.',
        element: method,
      );
    }

    for (var param in method.parameters) {
      if (!_queryChecker.hasAnnotationOf(param) &&
          !_bodyChecker.hasAnnotationOf(param) &&
          !_headerChecker.hasAnnotationOf(param) &&
          !_pathChecker.hasAnnotationOf(param)) {
        throw InvalidGenerationSourceError(
          'All parameters must have one of @Query, @Body, @Header, or @Path annotations.',
          element: param,
        );
      }
    }
  }

  bool _isSerializable(DartType type) {
    if (type.isDartCoreString ||
        type.isDartCoreInt ||
        type.isDartCoreDouble ||
        type.isDartCoreBool) {
      return true;
    }

    if (type is InterfaceType) {
      final classElement = type.element;

      // Check for fromJson constructor
      final hasFromJson = classElement.constructors.any((constructor) =>
          constructor.name == 'fromJson' && constructor.parameters.length == 1);

      // If fromJson exists, assume the type is serializable
      if (hasFromJson) {
        return true;
      }

      // As a fallback, check for toJson method
      final hasToJson =
          classElement.methods.any((method) => method.name == 'toJson');

      return hasToJson;
    }

    return false;
  }

  String _generateServerBaseClass(
      String className, List<HandlerInfo> handlers) {
    final buffer = StringBuffer();
    buffer.writeln(
        'abstract class _\$$className extends XServerBase implements I$className {');

    // Generate registerHandlers method
    buffer.writeln('@override');
    buffer.writeln('void registerHandlers(Router router) {');
    for (var handler in handlers) {
      buffer.writeln(
          "router.${handler.method.toLowerCase()}('${handler.path}', _${handler.name}Handler);");
    }
    buffer.writeln('}');

    // Generate handler wrapper methods
    for (var handler in handlers) {
      buffer.writeln(_generateHandlerWrapperMethod(handler));
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  String _generateClientClass(String className, List<HandlerInfo> handlers) {
    final buffer = StringBuffer();
    buffer.writeln(
        'class ${className}Client extends XServerClientBase implements I$className {');
    buffer.writeln(
        '  ${className}Client(super.baseUrl, {super.defaultHeaders = const {}, this.allMethod = \'POST\'});');
    buffer.writeln('  final String allMethod;');
    buffer.writeln();

    // Generate client methods
    for (var handler in handlers) {
      buffer.writeln(_generateClientMethod(handler));
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  String _generateHandlerWrapperMethod(HandlerInfo handler) {
    final buffer = StringBuffer();
    final methodName = '_${handler.name}Handler';
    final returnType = 'Future<Response>';

    buffer.writeln('$returnType $methodName(Request request) async {');

    // Generate parameter injection code
    final injectedParameters = <String>[];
    for (var param in handler.parameters) {
      final injectionCode = _generateParameterInjectionCode(param);
      buffer.writeln(injectionCode);
      injectedParameters.add(param.name);
    }

    // Determine if we need to use 'this.'
    final potentialConflicts = [...injectedParameters, 'result'];
    final needsThis = potentialConflicts.contains(handler.name);
    final methodCallPrefix = needsThis ? 'this.' : '';

    // Call the original method
    if (handler.returnType.isDartAsyncStream) {
      buffer.writeln('final result = $methodCallPrefix${handler.name}(');
    } else {
      buffer.writeln('final result = await $methodCallPrefix${handler.name}(');
    }
    buffer.write(_generateMethodCallParameters(handler.parameters));
    buffer.writeln(');');

    // Handle the result using XServerResponseHandler
    if (handler.returnType.isDartAsyncStream) {
      buffer
          .writeln('return XServerResponseHandler.handleStreamResult(result);');
    } else {
      buffer.writeln('return XServerResponseHandler.handleResult(result);');
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  String _generateClientMethod(HandlerInfo handler) {
    final buffer = StringBuffer();
    final returnType =
        handler.returnType.getDisplayString(withNullability: true);
    final methodName = handler.name;

    buffer.writeln('  @override');
    buffer.write('  $returnType $methodName(');

    final hasNamedParameters = handler.parameters.any((p) => p.isNamed);
    if (hasNamedParameters) {
      buffer.write('{');
    }

    // Generate method parameters
    final params = handler.parameters.map((p) {
      final paramType = p.type.getDisplayString(withNullability: true);
      if (p.isNamed) {
        return '${p.isRequired ? 'required ' : ''}$paramType ${p.name}';
      } else {
        return '$paramType ${p.name}';
      }
    }).join(', ');

    buffer.write(params);

    if (hasNamedParameters) {
      buffer.write('}');
    }

    buffer.writeln(') {');

    // Generate request
    buffer.writeln("    final Map<String, dynamic> pathParams = {");
    for (var param
        in handler.parameters.where((p) => _pathChecker.hasAnnotationOf(p))) {
      buffer.writeln("      '${param.name}': ${param.name},");
    }
    buffer.writeln("    };");

    buffer.writeln("    final Map<String, dynamic> queryParams = {");
    for (var param
        in handler.parameters.where((p) => _queryChecker.hasAnnotationOf(p))) {
      buffer.writeln("      '${param.name}': ${param.name},");
    }
    buffer.writeln("    };");

    buffer.writeln("    final Map<String, String> headers = {");
    for (var param
        in handler.parameters.where((p) => _headerChecker.hasAnnotationOf(p))) {
      buffer.writeln("      '${param.name}': ${param.name}.toString(),");
    }
    buffer.writeln("    };");

    final bodyParam = handler.parameters
        .firstWhereOrNull((p) => _bodyChecker.hasAnnotationOf(p));
    final bodyParamString = bodyParam != null ? bodyParam.name : 'null';

    final methodString =
        handler.method == 'ALL' ? 'allMethod' : "'${handler.method}'";

    if (handler.returnType.isDartAsyncStream) {
      buffer.writeln("    return eventSourceRequest(");
    } else {
      buffer.writeln("    return request(");
    }
    buffer.writeln("      $methodString,");
    buffer.writeln("      '${handler.path}',");
    buffer.writeln("      pathParams: pathParams,");
    buffer.writeln("      queryParams: queryParams,");
    buffer.writeln("      headers: headers,");
    buffer.writeln("      body: $bodyParamString,");
    buffer.writeln(
        "      parseResponse: (responseBody) => ${_generateParseResponse(handler.returnType)},");
    buffer.writeln("    );");

    buffer.writeln("  }");

    return buffer.toString();
  }

  String _generateParseResponse(DartType returnType) {
    final innerType = _getInnerType(returnType);

    if (innerType.isDartCoreString) {
      return 'responseBody';
    } else if (innerType.isDartCoreInt) {
      return 'int.parse(responseBody)';
    } else if (innerType.isDartCoreDouble) {
      return 'double.parse(responseBody)';
    } else if (innerType.isDartCoreBool) {
      return 'responseBody.toLowerCase() == \'true\'';
    } else {
      return '${innerType.getDisplayString(withNullability: false)}.fromJson(jsonDecode(responseBody))';
    }
  }

  DartType _getInnerType(DartType type) {
    if (type is ParameterizedType) {
      final typeArguments = type.typeArguments;
      if (typeArguments.isNotEmpty) {
        return typeArguments.first;
      }
    }
    return type;
  }

  String _generateParameterInjectionCode(ParameterElement param) {
    String sourceCode;
    String sourceType;

    if (_queryChecker.hasAnnotationOf(param)) {
      final queryName = _queryChecker
              .firstAnnotationOf(param)
              ?.getField('name')
              ?.toStringValue() ??
          param.name;
      sourceCode = "request.url.queryParameters['$queryName']";
      sourceType = 'query';
    } else if (_pathChecker.hasAnnotationOf(param)) {
      final pathName = _pathChecker
              .firstAnnotationOf(param)
              ?.getField('name')
              ?.toStringValue() ??
          param.name;
      sourceCode = "request.params['$pathName']";
      sourceType = 'path';
    } else if (_bodyChecker.hasAnnotationOf(param)) {
      sourceCode = "await request.readAsString()";
      sourceType = 'body';
    } else if (_headerChecker.hasAnnotationOf(param)) {
      final headerName = _headerChecker
              .firstAnnotationOf(param)
              ?.getField('name')
              ?.toStringValue() ??
          param.name;
      sourceCode = "request.headers['$headerName']";
      sourceType = 'header';
    } else {
      // For unknown types, we'll pass the entire request object
      return "final ${param.name} = request;";
    }

    return "final ${param.name} = XServerParser.parseParameter<${param.type}>("
        "$sourceCode, '${param.name}', ${!param.isRequired}, '$sourceType');";
  }

  String _generateMethodCallParameters(List<ParameterElement> parameters) {
    final namedParams =
        parameters.where((p) => p.isNamed).map((p) => '${p.name}: ${p.name}');
    final positionalParams =
        parameters.where((p) => !p.isNamed).map((p) => p.name);
    return [...positionalParams, ...namedParams].join(', ');
  }

  bool _isRequestParameter(ParameterElement param) {
    return _requestChecker.isExactlyType(param.type);
  }

  bool _hasFromJsonConstructor(DartType type) {
    if (type is InterfaceType) {
      return type.element.constructors
          .any((c) => c.name == 'fromJson' && c.parameters.length == 1);
    }
    return false;
  }

  DartObject? _getHandlerAnnotation(MethodElement method) {
    for (final checker in [_allChecker, _getChecker, _postChecker]) {
      final annotation = checker.firstAnnotationOf(method);
      if (annotation != null) return annotation;
    }
    return null;
  }

  String _getHttpMethod(DartObject annotation) {
    if (_allChecker.isExactlyType(annotation.type!)) return 'ALL';
    if (_getChecker.isExactlyType(annotation.type!)) return 'GET';
    if (_postChecker.isExactlyType(annotation.type!)) return 'POST';
    throw InvalidGenerationSourceError('Unknown HTTP method');
  }

  String? _getPath(DartObject annotation) {
    final pathField = annotation.getField('path');
    return pathField?.toStringValue();
  }
}

class HandlerInfo {
  final String name;
  final String method;
  final String path;
  final List<ParameterElement> parameters;
  final DartType returnType;

  HandlerInfo(
      this.name, this.method, this.path, this.parameters, this.returnType);
}

Builder xServerBuilder(BuilderOptions options) => SharedPartBuilder(
      [XServerGenerator()],
      'xserver',
    );
