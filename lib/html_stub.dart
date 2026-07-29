// Stub for dart:html when running on non-web platforms
// This file is only imported when dart.library.io is available (non-web)

class Blob {
  final List<dynamic> data;
  final String type;
  Blob(this.data, [this.type = '']);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  String? href;
  AnchorElement({this.href});
  void setAttribute(String name, String value) {}
  void click() {}
}
