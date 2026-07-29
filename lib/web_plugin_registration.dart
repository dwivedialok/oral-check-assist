import 'package:flutter_web_plugins/flutter_web_plugins.dart';
// ignore: implementation_imports — package does not expose a public web registrar API.
import 'package:package_info_plus/src/package_info_plus_web.dart';

/// Ensures [PackageInfo.fromPlatform] uses the web implementation (HTTP + version.json)
/// instead of the default method channel, which has no handler in the browser.
void ensureWebPackageInfoPluginRegistered() {
  PackageInfoPlusWebPlugin.registerWith(Registrar());
}
