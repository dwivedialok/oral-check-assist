import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (Map<String, dynamic>? data) async {
      if (data == null) return;
      final testLog = data['test_log'] as List<dynamic>?;
      if (testLog != null && testLog.isNotEmpty) {
        print('');
        print('--- E2E test summary ---');
        for (final entry in testLog) {
          final map = entry as Map<String, dynamic>;
          final name = map['name'] as String? ?? '?';
          final result = map['result'] as String? ?? '?';
          final icon = result == 'passed' ? '✓' : (result == 'skipped' ? '⊘' : '✗');
          print('  $icon $name -> $result');
        }
        print('------------------------');
        print('');
      }
      await writeResponseData(
        data,
        testOutputFilename: 'integration_response_data',
      );
    },
  );
}
