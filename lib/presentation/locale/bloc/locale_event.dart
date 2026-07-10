part of 'locale_bloc.dart';

sealed class LocaleEvent {
  const LocaleEvent();
}

final class LocaleLoadRequested extends LocaleEvent {
  const LocaleLoadRequested();
}

final class LocaleChanged extends LocaleEvent {
  const LocaleChanged(this.languageCode);

  final String languageCode;
}
