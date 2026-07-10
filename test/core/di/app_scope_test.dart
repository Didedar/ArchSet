import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/dependencies.dart';
import 'package:archset_r2/core/di/app_scope.dart';
import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies.dart';
import '../../support/fake_app_database.dart';

void main() {
  testWidgets('exposes Dependencies and CoreDependencies to descendants',
      (tester) async {
    final dependencies = Dependencies(
      core: CoreDependencies(
        database: FakeAppDatabase(),
        secureStorage: const FlutterSecureStorage(),
        logger: Logger(),
      ),
    );
    late BuildContext capturedContext;

    await tester.pumpWidget(AppScope(
      dependencies: dependencies,
      child: Builder(
        builder: (context) {
          capturedContext = context;
          return const SizedBox();
        },
      ),
    ));

    expect(capturedContext.di, same(dependencies));
    expect(capturedContext.coreDependencies, same(dependencies.core));
  });
}
