import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/locale_provider.dart';

class AppStrings {
  // Locale keys
  static const String settings = 'settings';
  static const String signOut = 'sign_out';
  static const String signOutConfirmTitle = 'sign_out_confirm_title';
  static const String signOutConfirmMessage = 'sign_out_confirm_message';
  static const String cancel = 'cancel';
  static const String confirm = 'confirm';
  static const String termsOfUse = 'terms_of_use';
  static const String privacyPolicy = 'privacy_policy';
  static const String featureRequest = 'feature_request';
  static const String darkMode = 'dark_mode';
  static const String language = 'language';
  static const String userId = 'user_id';
  static const String email = 'email';
  static const String deleteAccount = 'delete_account';
  static const String hello = 'hello';
  static const String unknown = 'unknown';
  static const String welcomeTo = 'welcome_to';
  static const String archset = 'archset';
  static const String signInGoogle = 'sign_in_google';
  static const String signInApple = 'sign_in_apple';
  static const String signInEmail = 'sign_in_email';
  static const String myNotes = 'my_notes';
  static const String all = 'all';
  static const String folders = 'folders';
  static const String noFoldersYet = 'no_folders_yet';
  static const String tapToCreateFolder = 'tap_to_create_folder';
  static const String rename = 'rename';
  static const String delete = 'delete';
  static const String confirmDeleteFolder = 'confirm_delete_folder';
  static const String notesMovedToAll = 'notes_moved_to_all';
  static const String allNotes = 'all_notes';
  static const String untitled = 'untitled';
  static const String justNow = 'just_now';
  static const String ago = 'ago';
  static const String insertLink = 'insert_link';
  static const String enterLinkUrl = 'enter_link_url';
  static const String rewriteLoading = 'rewrite_loading';
  static const String rewriteFail = 'rewrite_fail';
  static const String rewriteSuccess = 'rewrite_success';
  static const String aiRewriteResult = 'ai_rewrite_result';
  static const String noTextToRewrite = 'no_text_to_rewrite';
  static const String noTranscription = 'no_transcription';
  static const String pdf = 'pdf';
  static const String aiChat = 'ai_chat';
  static const String image = 'image';
  static const String camera = 'camera';
  static const String scan = 'scan';
  static const String drawing = 'drawing';
  static const String transcription = 'transcription';
  static const String aiRewrite = 'ai_rewrite';
  static const String aiAssistant = 'ai_assistant';
  static const String audioRecording = 'audio_recording';
  static const String deleteDiaryConfirmTitle = 'delete_diary_confirm_title';
  static const String deleteDiaryConfirmMessage =
      'delete_diary_confirm_message';
  static const String diary = 'diary';
  static const String apply = 'apply';
  static const String insert = 'insert';
  static const String deleteFolder = 'delete_folder';
  static const String moveToFolder = 'move_to_folder';
  static const String deleteNote = 'delete_note';
  static const String noNotesInFolder = 'no_notes_in_folder';
  static const String tapToCreateNote = 'tap_to_create_note';
  static const String errorLoadingFolders = 'error_loading_folders';
  static const String createNewFolder = 'create_new_folder';
  static const String copyTranscription = 'copy_transcription';
  static const String share = 'share';
  static const String noTranscriptionAvailable = 'no_transcription_available';
  static const String noTranscriptionTextAvailable =
      'no_transcription_text_available';
  static const String done = 'done';
  static const String errorSavingDrawing = 'error_saving_drawing';
  static const String diaryBase = 'diary_base';
  static const String diaryBaseDesc = 'diary_base_desc';
  static const String askQuestions = 'ask_questions';
  static const String askQuestionsDesc = 'ask_questions_desc';
  static const String study = 'study';
  static const String studyDesc = 'study_desc';
  static const String yourText = 'your_text';
  static const String failedToGetResponse = 'failed_to_get_response';
  static const String errorLabel = 'error_label';
  static const String folderName = 'folder_name';
  static const String colorLabel = 'color_label';

  static const String create = 'create';
  static const String transcriptionMode = 'transcription_mode';
  static const String onlineGemini = 'online_gemini';
  static const String offlineWhisper = 'offline_whisper';
  static const String downloadModel = 'download_model';
  static const String modelDownloaded = 'model_downloaded';
  static const String downloading = 'downloading';
  static const String transcriptionSettings = 'transcription_settings';
  static const String modelNotFound = 'model_not_found';
  static const String downloadWhisperDesc = 'download_whisper_desc';

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      settings: 'Settings',
      signOut: 'Sign Out',
      signOutConfirmTitle: 'Sign Out',
      signOutConfirmMessage:
          'Are you sure you want to sign out? Your local data will be cleared.',
      cancel: 'Cancel',
      confirm: 'Sign Out',
      termsOfUse: 'Terms of Use',
      privacyPolicy: 'Privacy Policy',
      featureRequest: 'Feature request',
      darkMode: 'Dark mode',
      language: 'Language',
      userId: 'User ID',
      email: 'Email',
      deleteAccount: 'Delete Account',
      hello: 'Hello',
      unknown: 'Unknown',
      welcomeTo: 'Welcome to',
      archset: 'ARCHSET',
      signInGoogle: 'Sign in with Google',
      signInApple: 'Sign in with Apple',
      signInEmail: 'Sign in with Email',
      myNotes: 'My Notes',
      all: 'All',
      folders: 'Folders',
      noFoldersYet: 'No folders yet',
      tapToCreateFolder: 'Tap + to create your first folder',
      rename: 'Rename',
      delete: 'Delete',
      confirmDeleteFolder: 'Delete "%s"?',
      notesMovedToAll: 'Notes in this folder will be moved to All Notes.',
      allNotes: 'All notes',
      untitled: 'Untitled',
      justNow: 'Just now',
      ago: 'ago',
      insertLink: 'Insert Link',
      enterLinkUrl: 'https://...',
      rewriteLoading:
          'Rewriting for archaeological\ndocumentation standards...',
      rewriteFail: 'Failed to rewrite text. Please try again.',
      rewriteSuccess: 'Text rewritten successfully!',
      aiRewriteResult: 'AI Rewrite Result',
      noTextToRewrite: 'No text to rewrite. Please add some content first.',
      noTranscription: 'No transcription available. Record audio first.',
      pdf: 'PDF',
      aiChat: 'AI Chat',
      image: 'Image',
      camera: 'Camera',
      scan: 'Scan',
      drawing: 'Drawing',
      transcription: 'Transcription',
      aiRewrite: 'AI rewrite',
      aiAssistant: 'AI Assistant',
      audioRecording: 'Audio recording',
      deleteDiaryConfirmTitle: 'Delete this diary?',
      deleteDiaryConfirmMessage: 'This action cannot be undone.',
      diary: 'Diary',
      apply: 'Apply',
      insert: 'Insert',
      deleteFolder: 'Delete Folder',
      moveToFolder: 'Move to Folder',
      deleteNote: 'Delete Note',
      noNotesInFolder: 'No notes in this folder',
      tapToCreateNote: 'Tap + to create a new note',
      errorLoadingFolders: 'Error loading folders',
      createNewFolder: 'Create New Folder',
      copyTranscription: 'Copy transcription',
      share: 'Share',
      noTranscriptionAvailable: 'No transcription available',
      noTranscriptionTextAvailable:
          'No transcription text available for this recording.',
      done: 'Done',
      errorSavingDrawing: 'Failed to save drawing',
      diaryBase: 'Diary\'s Base',
      diaryBaseDesc:
          'Remind yourself of what you wrote in your journal and ask for any information related to the journal.',
      askQuestions: 'Ask questions',
      askQuestionsDesc:
          'Ask questions about misunderstandings regarding your findings and research.',
      study: 'Study',
      studyDesc:
          'Gain experience based on the data you collect more effectively with AI.',
      yourText: 'Your Text...',
      failedToGetResponse: 'Failed to get response. Please try again.',
      errorLabel: 'Error: ',
      folderName: 'Folder name',
      colorLabel: 'Color',
      create: 'Create',
      // Transcription
      'transcription_mode': 'Transcription Mode',
      'online_gemini': 'Gemini (Online)',
      'offline_whisper': 'Whisper (Offline)',
      'download_model': 'Download Model',
      'model_downloaded': 'Model Downloaded',
      'downloading': 'Downloading...',
      'transcription_settings': 'Transcription Settings',
      'model_not_found': 'Model not found',
      'download_whisper_desc':
          'Download Whisper model (140MB) for offline transcription.',
    },
    'ru': {
      settings: 'Настройки',
      signOut: 'Выйти',
      signOutConfirmTitle: 'Выход',
      signOutConfirmMessage:
          'Вы уверены, что хотите выйти? Локальные данные будут удалены.',
      cancel: 'Отмена',
      confirm: 'Выйти',
      termsOfUse: 'Условия использования',
      privacyPolicy: 'Политика конфиденциальности',
      featureRequest: 'Запрос функций',
      darkMode: 'Тёмная тема',
      language: 'Язык',
      userId: 'ID пользователя',
      email: 'Email',
      deleteAccount: 'Удалить аккаунт',
      hello: 'Привет',
      unknown: 'Неизвестно',
      welcomeTo: 'Добро пожаловать в',
      archset: 'ARCHSET',
      signInGoogle: 'Войти через Google',
      signInApple: 'Войти через Apple',
      signInEmail: 'Войти через Email',
      myNotes: 'Мои заметки',
      all: 'Все',
      folders: 'Папки',
      noFoldersYet: 'Папок пока нет',
      tapToCreateFolder: 'Нажмите +, чтобы создать папку',
      rename: 'Переименовать',
      delete: 'Удалить',
      confirmDeleteFolder: 'Удалить "%s"?',
      notesMovedToAll: 'Заметки будут перемещены в "Все заметки".',
      allNotes: 'Все заметки',
      untitled: 'Без названия',
      justNow: 'Только что',
      ago: 'назад',
      insertLink: 'Вставить ссылку',
      enterLinkUrl: 'https://...',
      rewriteLoading:
          'Переписываем под стандарты\nархеологической документации...',
      rewriteFail: 'Не удалось переписать текст. Попробуйте снова.',
      rewriteSuccess: 'Текст успешно переписан!',
      aiRewriteResult: 'Результат AI',
      noTextToRewrite: 'Нет текста для обработки.',
      noTranscription: 'Нет транскрипции. Сначала запишите аудио.',
      pdf: 'PDF',
      aiChat: 'AI Чат',
      image: 'Изображение',
      camera: 'Камера',
      scan: 'Скан',
      drawing: 'Рисунок',
      transcription: 'Транскрипция',
      aiRewrite: 'AI Рерайт',
      aiAssistant: 'AI Ассистент',
      audioRecording: 'Аудиозапись',
      deleteDiaryConfirmTitle: 'Удалить дневник?',
      deleteDiaryConfirmMessage: 'Это действие нельзя отменить.',
      diary: 'Дневник',
      apply: 'Применить',
      insert: 'Вставить',
      deleteFolder: 'Удалить папку',
      moveToFolder: 'Переместить в папку',
      deleteNote: 'Удалить заметку',
      noNotesInFolder: 'В этой папке нет заметок',
      tapToCreateNote: 'Нажмите +, чтобы создать',
      errorLoadingFolders: 'Ошибка загрузки папок',
      createNewFolder: 'Создать новую папку',
      copyTranscription: 'Копировать транскрипцию',
      share: 'Поделиться',
      noTranscriptionAvailable: 'Нет доступной транскрипции',
      noTranscriptionTextAvailable: 'Нет текста транскрипции для этой записи.',
      done: 'Готово',
      errorSavingDrawing: 'Не удалось сохранить рисунок',
      diaryBase: 'База дневника',
      diaryBaseDesc:
          'Напомните себе, что вы писали в дневнике, и запросите любую информацию, связанную с ним.',
      askQuestions: 'Задавать вопросы',
      askQuestionsDesc:
          'Задавайте вопросы о недопонимании ваших находок и исследований.',
      study: 'Учёба',
      studyDesc:
          'Эффективнее получайте опыт на основе собранных данных с помощью AI.',
      yourText: 'Ваш текст...',
      failedToGetResponse: 'Не удалось получить ответ. Попробуйте снова.',
      errorLabel: 'Ошибка: ',
      folderName: 'Название папки',
      colorLabel: 'Цвет',
      create: 'Создать',
      // Transcription
      'transcription_mode': 'Режим транскрипции',
      'online_gemini': 'Gemini (Онлайн)',
      'offline_whisper': 'Whisper (Оффлайн)',
      'download_model': 'Скачать модель',
      'model_downloaded': 'Модель загружена',
      'downloading': 'Загрузка...',
      'transcription_settings': 'Настройки транскрипции',
      'model_not_found': 'Модель не найдена',
      'download_whisper_desc':
          'Скачайте модель Whisper (140 МБ) для оффлайн транскрипции.',
    },
    'kk': {
      settings: 'Баптаулар',
      signOut: 'Шығу',
      signOutConfirmTitle: 'Шығу',
      signOutConfirmMessage:
          'Шығуға сенімдісіз бе? Жергілікті деректер өшіріледі.',
      cancel: 'Бас тарту',
      confirm: 'Шығу',
      termsOfUse: 'Пайдалану шарттары',
      privacyPolicy: 'Құпиялылық саясаты',
      featureRequest: 'Функция сұрау',
      darkMode: 'Қараңғы режим',
      language: 'Тіл',
      userId: 'Пайдаланушы ID',
      email: 'Email',
      deleteAccount: 'Аккаунтты өшіру',
      hello: 'Сәлем',
      unknown: 'Белгісіз',
      welcomeTo: 'Қош келдініз',
      archset: 'ARCHSET',
      signInGoogle: 'Google арқылы кіру',
      signInApple: 'Apple арқылы кіру',
      signInEmail: 'Email арқылы кіру',
      myNotes: 'Менің жазбаларым',
      all: 'Барлығы',
      folders: 'Папкалар',
      noFoldersYet: 'Папкалар жоқ',
      tapToCreateFolder: 'Папка жасау үшін + басыңыз',
      rename: 'Атын өзгерту',
      delete: 'Өшіру',
      confirmDeleteFolder: '"%s" өшіру?',
      notesMovedToAll: 'Жазбалар "Барлық жазбалар" бөліміне жылжытылады.',
      allNotes: 'Барлық жазбалар',
      untitled: 'Тақырыпсыз',
      justNow: 'Жаңа ғана',
      ago: 'бұрын',
      insertLink: 'Сілтеме қосу',
      enterLinkUrl: 'https://...',
      rewriteLoading:
          'Археологиялық құжаттама\nстандарттарына сәйкестендіру...',
      rewriteFail: 'Мәтінді қайта жазу сәтсіз аяқталды.',
      rewriteSuccess: 'Мәтін сәтті қайта жазылды!',
      aiRewriteResult: 'AI Нәтижесі',
      noTextToRewrite: 'Өңдеуге арналған мәтін жоқ.',
      noTranscription: 'Транскрипция жоқ. Алдымен аудио жазыңыз.',
      pdf: 'PDF',
      aiChat: 'AI Чат',
      image: 'Сурет',
      camera: 'Камера',
      scan: 'Скан',
      drawing: 'Сурет салу',
      transcription: 'Транскрипция',
      aiRewrite: 'AI Рерайт',
      aiAssistant: 'AI Көмекші',
      audioRecording: 'Аудио жазба',
      deleteDiaryConfirmTitle: 'Дневникті өшіру?',
      deleteDiaryConfirmMessage: 'Бұл әрекетті қайтару мүмкін емес.',
      diary: 'Дневник',
      apply: 'Қолдану',
      insert: 'Кірістіру',
      deleteFolder: 'Папканы өшіру',
      moveToFolder: 'Папкаға жылжыту',
      deleteNote: 'Жазбаны өшіру',
      noNotesInFolder: 'Бұл папкада жазбалар жоқ',
      tapToCreateNote: 'Жасау үшін + басыңыз',
      errorLoadingFolders: 'Папкаларды жүктеу қатесі',
      createNewFolder: 'Жаңа папка жасау',
      copyTranscription: 'Транскрипцияны көшіру',
      share: 'Бөлісу',
      noTranscriptionAvailable: 'Транскрипция қолжетімсіз',
      noTranscriptionTextAvailable: 'Бұл жазба үшін транскрипция мәтіні жоқ.',
      done: 'Дайын',
      errorSavingDrawing: 'Суретті сақтау мүмкін болмады',
      diaryBase: 'Дневник базасы',
      diaryBaseDesc:
          'Күнделікте жазғаныңызды еске түсіріп, оған қатысты кез келген ақпаратты сұраңыз.',
      askQuestions: 'Сұрақ қою',
      askQuestionsDesc:
          'Табылымдарыңыз бен зерттеулеріңізге қатысты түсініспеушіліктер туралы сұрақтар қойыңыз.',
      study: 'Оқу',
      studyDesc:
          'AI көмегімен жинақталған деректер негізінде тәжірибені тиімдірек алыңыз.',
      yourText: 'Сіздің мәтініңіз...',
      failedToGetResponse: 'Жауап алу мүмкін болмады. Қайталап көріңіз.',
      errorLabel: 'Қате: ',
      folderName: 'Папка атауы',
      colorLabel: 'Түс',
      create: 'Жасау',
      // Transcription
      'transcription_mode': 'Транскрипция режимі',
      'online_gemini': 'Gemini (Онлайн)',
      'offline_whisper': 'Whisper (Оффлайн)',
      'download_model': 'Модельді жүктеу',
      'model_downloaded': 'Модель жүктелді',
      'downloading': 'Жүктелуде...',
      'transcription_settings': 'Транскрипция баптаулары',
      'model_not_found': 'Модель табылмады',
      'download_whisper_desc':
          'Оффлайн транскрипция үшін Whisper моделін (140 МБ) жүктеңіз.',
    },
  };

  static String tr(WidgetRef ref, String key) {
    final locale = ref.watch(localeProvider);
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']![key]!;
  }
}
