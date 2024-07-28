import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:dart_casing/dart_casing.dart';
import 'package:xserver/src/annotations.dart';

import 'endpoint_util.dart';

class ClientEndpointsGenerator extends GeneratorForAnnotation<XServer> {
  final util = EndpointUtil();

  @override
  Future<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) async {
    final writer = DartFileWriter(buildStep);

    final endpointBaseElement = await buildStep.resolveClassElement(
        uri: 'package:xserver/src/endpoint_base.dart', 'EndpointBase');
    if (endpointBaseElement == null) {
      throw Exception('Failed to resolve EndpointBase class');
    }

    final responseParserElement = await buildStep.resolveClassElement(
        uri: 'package:xserver/src/response_parsers.dart', 'ResponseParsers');
    if (responseParserElement == null) {
      throw Exception('Failed to resolve ResponseParsers class');
    }

    final root = await util.createEndpointTree(buildStep);
    final typeProvider =
        await buildStep.inputLibrary.then((l) => l.typeProvider);
    await _generateClientClasses(
        writer, root, typeProvider, endpointBaseElement, responseParserElement);

    return writer.build();
  }

  Future<void> _generateClientClasses(
      DartFileWriter writer,
      EndpointInfo root,
      TypeProvider typeProvider,
      ClassElement endpointBaseElement,
      ClassElement responseParserElement) async {
    await _generateClientClass(
        writer, root, typeProvider, endpointBaseElement, responseParserElement,
        isRoot: true);
    await _generateNestedClasses(
        writer, root, typeProvider, endpointBaseElement, responseParserElement);
  }

  Future<void> _generateNestedClasses(
      DartFileWriter writer,
      EndpointInfo parent,
      TypeProvider typeProvider,
      ClassElement endpointBaseElement,
      ClassElement responseParserElement) async {
    for (var child in parent.children.values) {
      await _generateClientClass(writer, child, typeProvider,
          endpointBaseElement, responseParserElement);
      await _generateNestedClasses(writer, child, typeProvider,
          endpointBaseElement, responseParserElement);
    }
  }

  Future<void> _generateClientClass(
      DartFileWriter writer,
      EndpointInfo endpoint,
      TypeProvider typeProvider,
      ClassElement endpointBaseElement,
      ClassElement responseParserElement,
      {bool isRoot = false}) async {
    final className = isRoot
        ? 'ServerEndpoints'
        : '${Casing.pascalCase(endpoint.name)}Endpoint';

    writer.writeln('class $className extends ');
    writer.writeParts([endpointBaseElement, ' {']);
    writer.writeln('  $className(super.baseUrl, { super.defaultHeaders });');
    writer.writeln();
    writer.writeln('  @override');
    writer.writeln('  String get path => \'${endpoint.path}\';');
    writer.writeln();

    await _generateEndpointMethods(
        writer, endpoint, typeProvider, responseParserElement);

    for (var child in endpoint.children.values) {
      final childClassName = '${Casing.pascalCase(child.name)}Endpoint';
      writer.writeln(
          '  late final $childClassName \$${Casing.camelCase(child.name)} = $childClassName(baseUrl, defaultHeaders: defaultHeaders);');
    }

    writer.writeln('}');
    writer.writeln();
  }

  Future<void> _generateParserMethods(
      DartFileWriter writer, EndpointInfo endpoint) async {
    for (final entry in endpoint.methods.entries) {
      final method = entry.key;
      final returnType = entry.value.returnType;
      final parserName = '_parse${method.toUpperCase()}Response';

      final actualReturnType =
          endpoint.isEventSource ? _getInnerType(returnType) : returnType;

      writer.writeParts(
          ['  ', actualReturnType, ' $parserName(String response) {']);
      writer.writeln('    ${_getParseResponseBody(actualReturnType)}');
      writer.writeln('  }');
      writer.writeln();
    }
  }

  String _getParseResponseBody(DartType type) {
    if (type is VoidType) {
      return 'return;';
    } else if (type.isDartCoreString) {
      return 'return response;';
    } else if (type.isDartCoreInt) {
      return 'return int.parse(response);';
    } else if (type.isDartCoreDouble) {
      return 'return double.parse(response);';
    } else if (type.isDartCoreBool) {
      return 'return bool.parse(response);';
    } else {
      return 'return ${type.getDisplayString(withNullability: false)}.fromJson(json.decode(response));';
    }
  }

  Future<void> _generateEndpointMethods(
      DartFileWriter writer,
      EndpointInfo endpoint,
      TypeProvider typeProvider,
      ClassElement responseParserElement) async {
    if (endpoint.isEventSource) {
      for (final entry in endpoint.methods.entries) {
        final method = entry.key;
        final methodInfo = entry.value;
        final innerType = _getInnerType(methodInfo.returnType);
        writer.writeParts([
          '  Stream<',
          innerType,
          '> ${method.toLowerCase()}({Map<String, dynamic>? query${method.toLowerCase() == 'post' ? ', dynamic data' : ''}}) {'
        ]);
        writer.writeln('    return eventSourceRequest(');
        writer.writeln('      \'${method.toUpperCase()}\',');
        writer.writeln('      query: query,');
        if (method.toLowerCase() == 'post') writer.writeln('      data: data,');
        writer.writeParts([
          '      parseResponse: ',
          _getParserMethod(innerType, responseParserElement),
          ','
        ]);
        writer.writeln('    );');
        writer.writeln('  }');
      }
    } else {
      for (final entry in endpoint.methods.entries) {
        final method = entry.key;
        final methodInfo = entry.value;
        writer.writeParts([
          '  Future<',
          methodInfo.returnType,
          '> ${method.toLowerCase()}({Map<String, dynamic>? query${method.toLowerCase() == 'post' ? ', dynamic data' : ''}}) {'
        ]);
        writer.writeln('    return request(');
        writer.writeln('      \'${method.toUpperCase()}\',');
        writer.writeln('      query: query,');
        if (method.toLowerCase() == 'post') writer.writeln('      data: data,');
        writer.writeParts([
          '      parseResponse: ',
          _getParserMethod(methodInfo.returnType, responseParserElement),
          ','
        ]);
        writer.writeln('    );');
        writer.writeln('  }');
      }
    }
    writer.writeln();
  }

  Element _getParserMethod(DartType type, ClassElement responseParserElement) {
    if (type is VoidType) {
      return responseParserElement.getMethod('parseVoid')!;
    } else if (type.isDartCoreString) {
      return responseParserElement.getMethod('parseString')!;
    } else if (type.isDartCoreInt) {
      return responseParserElement.getMethod('parseInt')!;
    } else if (type.isDartCoreDouble) {
      return responseParserElement.getMethod('parseDouble')!;
    } else if (type.isDartCoreBool) {
      return responseParserElement.getMethod('parseBool')!;
    } else if (type is InterfaceType && type.isDartCoreMap) {
      return responseParserElement.getMethod('parseJson')!;
    } else if (type is InterfaceType && type.isDartCoreList) {
      return responseParserElement.getMethod('parseList')!;
    } else {
      return responseParserElement.getMethod('parseObject')!;
    }
  }

  DartType _getInnerType(DartType streamType) {
    if (streamType is InterfaceType && streamType.isDartAsyncStream) {
      return streamType.typeArguments.first;
    }
    throw Exception(
        'Expected Stream type, got ${streamType.getDisplayString(withNullability: true)}');
  }
}

Builder clientEndpointsBuilder(BuilderOptions options) =>
    LibraryBuilder(ClientEndpointsGenerator(),
        generatedExtension: '.client.dart');
