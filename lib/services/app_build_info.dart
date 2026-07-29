/// Build metadata embedded into the compiled app bundle.
///
/// On Flutter web, `PackageInfo.fromPlatform()` reads `version.json` from the
/// server. That is useful for discovering the latest deployment, but it is not
/// a reliable "currently running app" version because old cached JavaScript can
/// fetch the new `version.json`. Pass this value during web builds with:
///
/// `--dart-define=APP_VERSION_TOKEN=<version>+<build_number>`
const String kEmbeddedAppVersionToken =
    String.fromEnvironment('APP_VERSION_TOKEN');

String buildVersionToken(String version, String buildNumber) {
  final v = version.trim();
  final b = buildNumber.trim();
  return b.isEmpty ? v : '$v+$b';
}

String runningVersionToken({
  required String packageVersion,
  required String packageBuildNumber,
}) {
  final embedded = kEmbeddedAppVersionToken.trim();
  if (embedded.isNotEmpty) return embedded;
  return buildVersionToken(packageVersion, packageBuildNumber);
}
