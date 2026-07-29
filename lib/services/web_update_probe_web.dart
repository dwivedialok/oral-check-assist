import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

Future<String?> fetchWebVersionToken() async {
  try {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final request = await html.HttpRequest.request(
      'version.json?t=$ts',
      method: 'GET',
      requestHeaders: const {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
    if (request.status != 200 || request.responseText == null) {
      return null;
    }

    final raw = jsonDecode(request.responseText!);
    if (raw is! Map<String, dynamic>) return null;

    final version = (raw['version'] ?? '').toString().trim();
    final build = (raw['build_number'] ?? '').toString().trim();
    if (version.isEmpty) return null;

    return build.isEmpty ? version : '$version+$build';
  } catch (_) {
    return null;
  }
}

Future<void> reloadWebPage() async {
  await _activateLatestServiceWorker();
  html.window.location.replace(_cacheBustedCurrentUrl());
}

Future<void> _activateLatestServiceWorker() async {
  try {
    final container = html.window.navigator.serviceWorker;
    if (container == null) return;

    final registrations = await container.getRegistrations();
    var activationRequested = false;

    for (final registration in registrations) {
      final updatedRegistration = await registration.update();

      final waiting = updatedRegistration.waiting ?? registration.waiting;
      if (waiting != null) {
        activationRequested = true;
        waiting.postMessage('skipWaiting');
      }
    }

    if (!activationRequested) return;

    await _waitForControllerChange(container);
  } catch (_) {
    // If service-worker activation fails, still navigate. We intentionally do
    // not unregister workers or delete caches, because unchanged ONNX assets
    // should remain cached across app-only releases.
  }
}

Future<void> _waitForControllerChange(
  html.ServiceWorkerContainer container,
) async {
  final completer = Completer<void>();
  late html.EventListener listener;
  listener = (_) {
    if (!completer.isCompleted) completer.complete();
    container.removeEventListener('controllerchange', listener);
  };

  container.addEventListener('controllerchange', listener);
  await completer.future.timeout(
    const Duration(seconds: 4),
    onTimeout: () {
      container.removeEventListener('controllerchange', listener);
    },
  );
}

String _cacheBustedCurrentUrl() {
  final uri = Uri.parse(html.window.location.href);
  final params = Map<String, String>.from(uri.queryParameters);
  params['_appUpdate'] = DateTime.now().millisecondsSinceEpoch.toString();
  return uri.replace(queryParameters: params).toString();
}
