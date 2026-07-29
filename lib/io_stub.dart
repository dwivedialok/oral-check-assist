// Stub for dart:io when building for web. File-based APIs are not used on web;
// use inferFromBytes / Image.memory instead.
import 'dart:typed_data';

/// Stub: not used on web. Use bytes (Uint8List) and inferFromBytes().
class File {
  final String path;
  File(this.path);

  Future<Uint8List> readAsBytes() =>
      throw UnsupportedError('File not supported on web. Use inferFromBytes(Uint8List).');

  Future<File> copy(String newPath) =>
      throw UnsupportedError('File.copy not supported on web.');

  Future<File> writeAsBytes(List<int> bytes) =>
      throw UnsupportedError('File.writeAsBytes not supported on web. Use browser download APIs.');

  Future<bool> exists() =>
      throw UnsupportedError('File.exists not supported on web.');
}
