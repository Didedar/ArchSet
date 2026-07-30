import 'package:flutter/widgets.dart' show Locale;

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

  // Artifacts map
  static const String artifactsMap = 'artifacts_map';
  static const String artifact = 'artifact';
  static const String noArtifactsYet = 'no_artifacts_yet';
  static const String noArtifactsHint = 'no_artifacts_hint';
  static const String withoutLocation = 'without_location';
  static const String withoutLocationTitle = 'without_location_title';
  static const String mapTokenMissing = 'map_token_missing';
  static const String mapTokenMissingHint = 'map_token_missing_hint';
  static const String coordinates = 'coordinates';
  static const String photographed = 'photographed';
  static const String openNote = 'open_note';
  static const String notAnalyzed = 'not_analyzed';
  static const String comments = 'comments';
  static const String noComments = 'no_comments';
  static const String addComment = 'add_comment';
  static const String deleteComment = 'delete_comment';
  static const String imageUnavailable = 'image_unavailable';

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      settings: 'Settings',
      signOut: 'Sign Out',
      signOutConfirmTitle: 'Sign Out',
      signOutConfirmMessage:
          'Are you sure you want to sign out? Your local diary stays on this device.',
      cancel: 'Cancel',
      confirm: 'Confirm',
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
      // Artifacts map
      artifactsMap: 'Artifacts Map',
      artifact: 'Artifact',
      noArtifactsYet: 'No artifacts on the map yet',
      noArtifactsHint:
          'Photograph a find inside a note and it will appear here.',
      withoutLocation: 'without location',
      withoutLocationTitle: 'Photos without location',
      mapTokenMissing: 'Map is not configured',
      mapTokenMissingHint:
          'Build the app with --dart-define=MAPBOX_ACCESS_TOKEN=your_token to enable the map.',
      coordinates: 'Coordinates',
      photographed: 'Photographed',
      openNote: 'Open note',
      notAnalyzed: 'This photo has not been analyzed yet.',
      comments: 'Comments',
      noComments: 'No comments yet',
      addComment: 'Write a comment...',
      deleteComment: 'Delete comment',
      imageUnavailable: 'Image unavailable',
    },
    'ru': {
      settings: 'Настройки',
      signOut: 'Выйти',
      signOutConfirmTitle: 'Выход',
      signOutConfirmMessage:
          'Вы уверены, что хотите выйти? Локальный дневник останется на этом устройстве.',
      cancel: 'Отмена',
      confirm: 'Подтвердить',
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
      // Artifacts map
      artifactsMap: 'Карта артефактов',
      artifact: 'Артефакт',
      noArtifactsYet: 'На карте пока нет артефактов',
      noArtifactsHint:
          'Сфотографируйте находку в заметке — она появится здесь.',
      withoutLocation: 'без геолокации',
      withoutLocationTitle: 'Фото без геолокации',
      mapTokenMissing: 'Карта не настроена',
      mapTokenMissingHint:
          'Соберите приложение с --dart-define=MAPBOX_ACCESS_TOKEN=ваш_токен, чтобы включить карту.',
      coordinates: 'Координаты',
      photographed: 'Снято',
      openNote: 'Открыть заметку',
      notAnalyzed: 'Это фото ещё не проанализировано.',
      comments: 'Комментарии',
      noComments: 'Комментариев пока нет',
      addComment: 'Написать комментарий...',
      deleteComment: 'Удалить комментарий',
      imageUnavailable: 'Изображение недоступно',
    },
    'kk': {
      settings: 'Баптаулар',
      signOut: 'Шығу',
      signOutConfirmTitle: 'Шығу',
      signOutConfirmMessage:
          'Шығуға сенімдісіз бе? Жергілікті күнделік осы құрылғыда сақталады.',
      cancel: 'Бас тарту',
      confirm: 'Растау',
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
      // Artifacts map
      artifactsMap: 'Артефактілер картасы',
      artifact: 'Артефакт',
      noArtifactsYet: 'Картада әзірге артефактілер жоқ',
      noArtifactsHint: 'Жазбада олжаны суретке түсіріңіз — ол осында шығады.',
      withoutLocation: 'геолокациясыз',
      withoutLocationTitle: 'Геолокациясыз суреттер',
      mapTokenMissing: 'Карта бапталмаған',
      mapTokenMissingHint:
          'Картаны қосу үшін қолданбаны --dart-define=MAPBOX_ACCESS_TOKEN=токеніңіз арқылы жинаңыз.',
      coordinates: 'Координаттар',
      photographed: 'Түсірілді',
      openNote: 'Жазбаны ашу',
      notAnalyzed: 'Бұл сурет әлі талданбаған.',
      comments: 'Пікірлер',
      noComments: 'Әзірге пікір жоқ',
      addComment: 'Пікір жазу...',
      deleteComment: 'Пікірді жою',
      imageUnavailable: 'Сурет қолжетімсіз',
    },
    'zh': {
      settings: '设置',
      signOut: '退出登录',
      signOutConfirmTitle: '退出登录',
      signOutConfirmMessage: '您确定要退出登录吗？本地日记将保留在此设备上。',
      cancel: '取消',
      confirm: '确认',
      termsOfUse: '使用条款',
      privacyPolicy: '隐私政策',
      featureRequest: '功能请求',
      darkMode: '深色模式',
      language: '语言',
      userId: '用户ID',
      email: '邮箱',
      deleteAccount: '删除账户',
      hello: '你好',
      unknown: '未知',
      welcomeTo: '欢迎使用',
      archset: 'ARCHSET',
      signInGoogle: '使用 Google 登录',
      signInApple: '使用 Apple 登录',
      signInEmail: '使用邮箱登录',
      myNotes: '我的笔记',
      all: '全部',
      folders: '文件夹',
      noFoldersYet: '暂无文件夹',
      tapToCreateFolder: '点击 + 创建您的第一个文件夹',
      rename: '重命名',
      delete: '删除',
      confirmDeleteFolder: '删除"%s"？',
      notesMovedToAll: '此文件夹中的笔记将移动到"所有笔记"。',
      allNotes: '所有笔记',
      untitled: '无标题',
      justNow: '刚刚',
      ago: '前',
      insertLink: '插入链接',
      enterLinkUrl: 'https://...',
      rewriteLoading: '正在按照考古\n文档标准重写...',
      rewriteFail: '文本重写失败，请重试。',
      rewriteSuccess: '文本重写成功！',
      aiRewriteResult: 'AI 重写结果',
      noTextToRewrite: '没有可重写的文本，请先添加一些内容。',
      noTranscription: '没有可用的转录内容，请先录制音频。',
      pdf: 'PDF',
      aiChat: 'AI 聊天',
      image: '图片',
      camera: '相机',
      scan: '扫描',
      drawing: '绘图',
      transcription: '转录',
      aiRewrite: 'AI 重写',
      aiAssistant: 'AI 助手',
      audioRecording: '录音',
      deleteDiaryConfirmTitle: '删除此日记？',
      deleteDiaryConfirmMessage: '此操作无法撤销。',
      diary: '日记',
      apply: '应用',
      insert: '插入',
      deleteFolder: '删除文件夹',
      moveToFolder: '移动到文件夹',
      deleteNote: '删除笔记',
      noNotesInFolder: '此文件夹中没有笔记',
      tapToCreateNote: '点击 + 创建新笔记',
      errorLoadingFolders: '加载文件夹出错',
      createNewFolder: '创建新文件夹',
      copyTranscription: '复制转录内容',
      share: '分享',
      noTranscriptionAvailable: '没有可用的转录内容',
      noTranscriptionTextAvailable: '此录音没有可用的转录文本。',
      done: '完成',
      errorSavingDrawing: '保存绘图失败',
      diaryBase: '日记库',
      diaryBaseDesc: '回顾您在日记中写下的内容，并询问与日记相关的任何信息。',
      askQuestions: '提出问题',
      askQuestionsDesc: '就您的发现和研究中的疑问提出问题。',
      study: '学习',
      studyDesc: '借助 AI 更高效地利用您收集的数据积累经验。',
      yourText: '您的文本...',
      failedToGetResponse: '获取响应失败，请重试。',
      errorLabel: '错误：',
      folderName: '文件夹名称',
      colorLabel: '颜色',
      create: '创建',
      // Transcription
      'transcription_mode': '转录模式',
      'online_gemini': 'Gemini（在线）',
      'offline_whisper': 'Whisper（离线）',
      'download_model': '下载模型',
      'model_downloaded': '模型已下载',
      'downloading': '下载中...',
      'transcription_settings': '转录设置',
      'model_not_found': '未找到模型',
      'download_whisper_desc': '下载 Whisper 模型（140MB）以进行离线转录。',
      // Artifacts map
      artifactsMap: '文物地图',
      artifact: '文物',
      noArtifactsYet: '地图上还没有文物',
      noArtifactsHint: '在笔记中拍摄发现物，它就会显示在这里。',
      withoutLocation: '无定位',
      withoutLocationTitle: '无定位的照片',
      mapTokenMissing: '地图未配置',
      mapTokenMissingHint:
          '请使用 --dart-define=MAPBOX_ACCESS_TOKEN=您的令牌 构建应用以启用地图。',
      coordinates: '坐标',
      photographed: '拍摄于',
      openNote: '打开笔记',
      notAnalyzed: '此照片尚未分析。',
      comments: '评论',
      noComments: '暂无评论',
      addComment: '写评论...',
      deleteComment: '删除评论',
      imageUnavailable: '图片不可用',
    },
  };

  static String tr(Locale locale, String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']![key]!;
  }
}
