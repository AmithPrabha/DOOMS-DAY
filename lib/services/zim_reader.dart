import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

typedef _RequestC =
    Pointer<Utf8> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Int32,
      Int32,
    );
typedef _RequestDart =
    Pointer<Utf8> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
      int,
    );
typedef _FreeC = Void Function(Pointer<Void>);
typedef _FreeDart = void Function(Pointer<Void>);
typedef _AssetC =
    Pointer<Uint8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Uint64>);
typedef _AssetDart =
    Pointer<Uint8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Uint64>);

/// Prototype adapter. Native binaries must be built and supplied explicitly;
/// production linking remains gated on licensing and platform verification.
/// Every call runs off the UI isolate and pages search results in native libzim.
class ZimReader {
  final String libraryPath;
  const ZimReader(this.libraryPath);
  Future<Map<String, dynamic>> request(
    String archive,
    String operation, {
    String argument = '',
    int offset = 0,
    int count = 20,
  }) {
    final library = libraryPath;
    return Isolate.run(() {
      final native = DynamicLibrary.open(library);
      final call = native.lookupFunction<_RequestC, _RequestDart>(
        'dd_zim_request',
      );
      final release = native.lookupFunction<_FreeC, _FreeDart>('dd_zim_free');
      final path = archive.toNativeUtf8();
      final op = operation.toNativeUtf8();
      final arg = argument.toNativeUtf8();
      Pointer<Utf8> result = nullptr;
      try {
        result = call(path, op, arg, offset, count);
        if (result == nullptr) throw StateError('Native allocation failed');
        final decoded =
            jsonDecode(result.toDartString()) as Map<String, dynamic>;
        if (decoded.containsKey('error')) {
          throw StateError(decoded['error'] as String);
        }
        return decoded;
      } finally {
        if (result != nullptr) release(result.cast());
        calloc.free(path);
        calloc.free(op);
        calloc.free(arg);
      }
    });
  }

  Future<Uint8List> asset(String archive, String entry) {
    final library = libraryPath;
    return Isolate.run(() {
      final native = DynamicLibrary.open(library);
      final call = native.lookupFunction<_AssetC, _AssetDart>('dd_zim_asset');
      final release = native.lookupFunction<_FreeC, _FreeDart>('dd_zim_free');
      final path = archive.toNativeUtf8();
      final name = entry.toNativeUtf8();
      final size = calloc<Uint64>();
      Pointer<Uint8> result = nullptr;
      try {
        result = call(path, name, size);
        if (result == nullptr) {
          throw StateError('Asset absent, oversized, or unreadable');
        }
        return Uint8List.fromList(result.asTypedList(size.value));
      } finally {
        if (result != nullptr) release(result.cast());
        calloc.free(path);
        calloc.free(name);
        calloc.free(size);
      }
    });
  }
}
