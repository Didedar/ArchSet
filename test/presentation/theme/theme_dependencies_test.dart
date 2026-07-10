import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/domain/repositories/theme_repository.dart';
import 'package:archset_r2/presentation/theme/theme_dependencies.dart';
import 'package:mocktail/mocktail.dart';

class _MockThemeRepository extends Mock implements ThemeRepository {}

void main() {
  test('holds the repository it was built with', () {
    final repository = _MockThemeRepository();

    final deps = ThemeDependencies(repository: repository);

    expect(deps.repository, same(repository));
  });
}
