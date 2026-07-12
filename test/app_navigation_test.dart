import 'package:flutter_test/flutter_test.dart';

import 'helpers/source_scan.dart';

void main() {
  test('vehicle-home refresh contains and logs background failures', () {
    final source = readSource('lib/services/app_navigation.dart');

    expect(source, contains('unawaited(_refreshVehiclesSilently(cloud))'));
    expect(
      source,
      contains('await cloud.refreshVehicles(silent: true, force: true)'),
    );
    expect(source, contains('OfficialCloudRedactor.errorMessage(error)'));
    expect(source, isNot(contains('unawaited(cloud.refreshVehicles(')));
  });
}
