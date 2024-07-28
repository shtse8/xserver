import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:xserver/src/annotations.dart';

import 'endpoint_util.dart';

class XServerGenerator extends GeneratorForAnnotation<XServer> {
  @override
  Future<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) async {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
          'XServer annotation can only be applied to classes.',
          element: element);
    }

    final className = element.name;

    final writer = DartFileWriter(buildStep);

    writer.writeln('base class _\$$className extends XServerBase {');
    writer.writeln('  _\$$className() : super();');
    writer.writeln();
    writer.writeln('  @override');
    writer.writeln('  void registerHandlers(Router router) {');
    writer.writeln('    // Generated handler registrations');
    writer.writeln('    generatedRegisterHandlers(router);');
    writer.writeln('  }');
    writer.writeln('}');

    return writer.build();
  }
}

class XServerImportsGenerator extends GeneratorForAnnotation<XServer> {
  final util = EndpointUtil();

  @override
  Future<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) async {
    final root = await util.createEndpointTree(buildStep);

    final writer = DartFileWriter(buildStep);

    final routerElement = await buildStep.resolveClassElement(
        uri: 'package:shelf_router/shelf_router.dart', 'Router');

    writer.writeParts(
        ['void generatedRegisterHandlers(', routerElement, ' router) {']);
    util.visit(root, (node) {
      for (final entry in node.methods.entries) {
        final method = entry.key;
        final methodInfo = entry.value;
        writer.writeln(
            '//${methodInfo.returnType.getDisplayString(withNullability: true)}');
        writer.writeParts([
          "  router.${method.toLowerCase()}('${node.path}', ",
          methodInfo.handler,
          ".handler);\n"
        ]);
      }
    });
    writer.writeln('}');

    return writer.build();
  }
}

Builder xserverBuilder(BuilderOptions options) =>
    SharedPartBuilder([XServerGenerator()], 'xserver');

Builder xserverImportsBuilder(BuilderOptions options) =>
    LibraryBuilder(XServerImportsGenerator(),
        generatedExtension: '.imports.dart');
