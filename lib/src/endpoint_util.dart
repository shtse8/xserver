import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:source_gen/source_gen.dart';
import 'package:xserver/src/annotations.dart';

class EndpointInfo {
  String name;
  String path;
  Map<String, MethodInfo> methods = {};
  final Map<String, EndpointInfo> children = {};

  EndpointInfo(this.name, this.path);

  bool get isEventSource => methods.values.any((info) =>
      info.returnType is InterfaceType && info.returnType.isDartAsyncStream);

  @override
  String toString() {
    return 'EndpointInfo(name: $name, path: $path, methods: ${methods.keys}, children: ${children.keys})';
  }

  void addMethod(String method, DartType returnType, Element handler) {
    methods[method] = MethodInfo(returnType, handler);
  }
}

class MethodInfo {
  final DartType returnType;
  final Element handler;

  MethodInfo(this.returnType, this.handler);
}

class EndpointUtil {
  final String basePath;

  EndpointUtil(this.basePath);

  Future<EndpointInfo> createEndpointTree(BuildStep buildStep) async {
    final serverFiles =
        await buildStep.findAssets(Glob('$basePath/**.dart')).toList();

    final library = await buildStep.inputLibrary;
    final typeProvider = library.typeProvider;
    final root = _createVoidEndpoint('root', '/', typeProvider);

    serverFiles.sort((a, b) {
      final aIsIndex = path.basename(a.path) == 'index.dart';
      final bIsIndex = path.basename(b.path) == 'index.dart';
      if (aIsIndex && !bIsIndex) return -1;
      if (!aIsIndex && bIsIndex) return 1;
      return a.path.compareTo(b.path);
    });

    for (final asset in serverFiles) {
      final info = await _extractEndpointInfo(asset, buildStep);
      if (info != null) {
        _addEndpointToTree(root, info, typeProvider);
      }
    }

    return root;
  }

  void visit(EndpointInfo root, void Function(EndpointInfo node) visitor) {
    visitor(root);
    for (final child in root.children.values) {
      visit(child, visitor);
    }
  }

  EndpointInfo _createVoidEndpoint(
    String name,
    String path,
    TypeProvider typeProvider,
  ) {
    return EndpointInfo(name, path);
  }

  DartType _getReturnType(FunctionTypedElement element) {
    final type = element.returnType;
    if (type is InterfaceType && type.isDartAsyncFuture) {
      return type.typeArguments.first;
    }
    return type;
  }

  Future<EndpointInfo?> _extractEndpointInfo(
      AssetId asset, BuildStep buildStep) async {
    final library = await buildStep.resolver.libraryFor(asset);
    for (final element in library.topLevelElements) {
      if (element is FunctionTypedElement &&
          TypeChecker.fromRuntime(Handler).hasAnnotationOf(element)) {
        final returnType = _getReturnType(element);
        final relativePath = path.url.relative(asset.path, from: basePath);
        final (endpointPath, _) = _parseFilePath(relativePath);
        final name = _getEndpointName(endpointPath);
        final info = EndpointInfo(name, endpointPath);
        final methods = [
          if (TypeChecker.fromRuntime(Get).hasAnnotationOf(element) ||
              TypeChecker.fromRuntime(All).hasAnnotationOf(element))
            'get',
          if (TypeChecker.fromRuntime(Post).hasAnnotationOf(element) ||
              TypeChecker.fromRuntime(All).hasAnnotationOf(element))
            'post',
        ];

        for (final method in methods) {
          info.addMethod(method, returnType, element);
        }
        return info;
      }
    }
    return null;
  }

  String _getEndpointName(String endpointPath) {
    final parts =
        endpointPath.split('/').where((part) => part.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : 'root';
  }

  (String, List<String>) _parseFilePath(String filePath) {
    String normalizedPath = filePath.replaceAll('\\\\', '/');
    final parts = normalizedPath.split('.');
    String endpointPath = '/${parts[0].replaceAll('index', '')}';
    endpointPath = endpointPath.replaceAll(RegExp(r'//+'), '/');
    if (endpointPath.length > 1 && endpointPath.endsWith('/')) {
      endpointPath = endpointPath.substring(0, endpointPath.length - 1);
    }

    List<String> methods;
    if (parts.length > 1 && ['get', 'post'].contains(parts[1].toLowerCase())) {
      methods = [parts[1].toLowerCase()];
    } else {
      methods = [
        'get',
        'post'
      ]; // Default to both GET and POST if not specified
    }

    return (endpointPath, methods);
  }

  void _addEndpointToTree(
      EndpointInfo root, EndpointInfo endpoint, TypeProvider typeProvider) {
    final parts =
        endpoint.path.split('/').where((part) => part.isNotEmpty).toList();
    var current = root;
    var pathParts = <String>[];

    if (parts.isEmpty) {
      // it is the root
      current.methods.addAll(endpoint.methods);
      return;
    }

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      pathParts.add(part);
      final currentPath = '/${pathParts.join('/')}';
      final isLast = i == parts.length - 1;

      if (!current.children.containsKey(part)) {
        if (isLast) {
          current.children[part] = endpoint;
        } else {
          current.children[part] =
              _createVoidEndpoint(part, currentPath, typeProvider);
        }
      } else if (isLast) {
        current.children[part]!.methods.addAll(endpoint.methods);
      }

      current = current.children[part]!;
    }
  }
}

class LibraryImport {
  final Uri uri;
  final String alias;

  LibraryImport(this.uri, this.alias);

  @override
  String toString() => "import '${uri.toString()}' as $alias;";
}

class DartFileWriter {
  final List<Object> _parts = [];
  final BuildStep _buildStep;

  DartFileWriter(this._buildStep);

  void writeln([Object? line]) {
    if (line != null) {
      _parts.add(line);
    }
    _parts.add('\n');
  }

  void write(Object? line) {
    if (line != null) {
      _parts.add(line);
    }
  }

  void writeParts(List<Object?> parts) {
    _parts.addAll(parts.whereType<Object>());
  }

  Future<Uri?> _resolvePublicUri(Element element) async {
    final resolver = _buildStep.resolver;
    final originalLib = element.library;
    if (originalLib == null) {
      print('Warning: Could not resolve library for ${element.name}');
      return null;
    }

    // Try to find a library that exports the original library
    try {
      await for (final lib in resolver.libraries) {
        if (lib.exportNamespace.definedNames.containsValue(element)) {
          final assetId = await resolver.assetIdForElement(lib);
          return _formatUri(assetId);
        }
      }
    } catch (e) {
      print('Error while searching libraries: $e');
    }

    // If no exporting library is found, use the original element's source URI
    final sourceUri = element.source?.uri;
    if (sourceUri != null && sourceUri.scheme == 'package') {
      return sourceUri;
    }

    // Fallback to the original library's source URI if element's source is not available
    final libSourceUri = originalLib.source.uri;
    if (libSourceUri.scheme == 'package') {
      return libSourceUri;
    }

    print('Warning: Could not resolve public URI for ${element.name}');
    return null;
  }

  Uri _formatUri(AssetId assetId) {
    final pathSegments = assetId.pathSegments;
    final formattedSegments =
        pathSegments[0] == 'lib' ? pathSegments.skip(1) : pathSegments;
    return Uri(
      scheme: 'package',
      pathSegments: [assetId.package, ...formattedSegments],
    );
  }

  Future<String> build() async {
    final imports = <Uri, LibraryImport>{};
    final resolvedContent = StringBuffer();

    for (final part in _parts) {
      if (part is Element) {
        final libraryUri = await _resolvePublicUri(part);
        if (libraryUri != null) {
          final import = imports.putIfAbsent(libraryUri,
              () => LibraryImport(libraryUri, 'i${imports.length}'));
          resolvedContent
            ..write(import.alias)
            ..write('.');
        }
        if (part is MethodElement) {
          resolvedContent.write(part.enclosingElement.name);
          resolvedContent.write('.');
        }
        resolvedContent.write(part.name);
      } else {
        resolvedContent.write(part);
      }
    }

    final buffer = StringBuffer();

    // Write imports
    for (final import in imports.values) {
      buffer.writeln(import);
    }
    if (imports.isNotEmpty) buffer.writeln();

    // Write resolved content
    buffer.write(resolvedContent);

    return buffer.toString();
  }
}

extension BuildStepExtension on BuildStep {
  Future<ClassElement?> resolveClassElement(
    String className, {
    String? uri,
  }) async {
    try {
      var library = uri == null
          ? await inputLibrary
          : await resolver.libraryFor(AssetId.resolve(Uri.parse(uri)));

      // Function to check a library for the class
      ClassElement? findClassInLibrary(LibraryElement lib) {
        // Check in the current library
        var classElement = lib.getClass(className);
        if (classElement != null) {
          return classElement;
        }

        // Check in exported libraries (only one level deep to avoid loops)
        for (var exportedLib in lib.exportedLibraries) {
          classElement = exportedLib.getClass(className);
          if (classElement != null) {
            return classElement;
          }
        }

        return null;
      }

      // Search in the main library and its direct exports
      return findClassInLibrary(library);
    } catch (e, stackTrace) {
      print('Stack trace: $stackTrace');
      return null;
    }
  }
}
