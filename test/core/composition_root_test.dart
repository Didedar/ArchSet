import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/composition_root.dart';
import 'package:archset_r2/core/logging/logger.dart';
import '../support/fake_path_provider.dart';
import '../support/fake_secure_storage.dart';

class _RecordingObserver implements LogObserver {
  final messages = <String>[];

  @override
  void onLog(LogRecord record) => messages.add(record.message);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    installFakePathProvider();
    installFakeSecureStorage();
  });

  test('builds a Dependencies graph with a wired CoreDependencies', () async {
    final logger = Logger();

    final dependencies = await CompositionRoot(logger).initDependencies();

    expect(dependencies.core.logger, same(logger));
    expect(dependencies.core.database, isNotNull);
    expect(dependencies.core.secureStorage, isNotNull);
    expect(dependencies.theme.repository, isNotNull);
    expect(dependencies.locale.repository, isNotNull);
    expect(dependencies.auth.repository, isNotNull);
    expect(dependencies.sync.service, isNotNull);
    expect(dependencies.notes.repository, isNotNull);
  });

  test('logs initialization start and completion', () async {
    final logger = Logger();
    final observer = _RecordingObserver();
    logger.addObserver(observer);

    await CompositionRoot(logger).initDependencies();

    expect(observer.messages, contains(contains('Initialization started')));
    expect(observer.messages, contains(contains('Dependencies initialized')));
  });
}
