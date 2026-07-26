import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/command_types.dart';
import 'package:tailg_ble_app/models/control_command_activity.dart';

void main() {
  test('terminal command feedback replaces its pending row', () {
    final log = ControlCommandActivityLog();
    final id = log.start(
      command: CommandCode.lock,
      title: '设防中…',
      subtitle: '等待回执',
    );

    expect(
      log.finish(
        id: id,
        title: '设防完成',
        subtitle: '车辆已设防',
        status: ControlCommandActivityStatus.succeeded,
      ),
      isTrue,
    );
    expect(log.entries, hasLength(1));
    expect(log.entries.single.id, id);
    expect(log.entries.single.title, '设防完成');
    expect(log.entries.single.status, ControlCommandActivityStatus.succeeded);
  });

  test('command feedback retains only the newest configured count', () {
    final log = ControlCommandActivityLog(maxEntries: 2);
    final first = log.start(
      command: CommandCode.lock,
      title: 'first',
      subtitle: 'pending',
    );
    log.start(
      command: CommandCode.unlock,
      title: 'second',
      subtitle: 'pending',
    );
    log.start(command: CommandCode.find, title: 'third', subtitle: 'pending');

    expect(log.entries.map((entry) => entry.title), ['third', 'second']);
    expect(
      log.finish(
        id: first,
        title: 'expired',
        subtitle: 'expired',
        status: ControlCommandActivityStatus.failed,
      ),
      isFalse,
    );
  });
}
