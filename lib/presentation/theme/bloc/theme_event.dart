part of 'theme_bloc.dart';

sealed class ThemeEvent {
  const ThemeEvent();
}

final class ThemeLoadRequested extends ThemeEvent {
  const ThemeLoadRequested();
}

final class ThemeModeChanged extends ThemeEvent {
  const ThemeModeChanged(this.isDark);

  final bool isDark;
}
