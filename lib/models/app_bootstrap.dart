import '../l10n/app_strings.dart';

class AppWarningText {
  AppWarningText({
    required this.titleI18n,
    required this.messageI18n,
    required this.actionLabelI18n,
  });

  final Map<String, String> titleI18n;
  final Map<String, String> messageI18n;
  final Map<String, String> actionLabelI18n;

  factory AppWarningText.fromJson(Map<String, dynamic> json) {
    return AppWarningText(
      titleI18n: _readMap(json['titleI18n']),
      messageI18n: _readMap(json['messageI18n']),
      actionLabelI18n: _readMap(json['actionLabelI18n']),
    );
  }

  String titleFor(String languageCode) =>
      _pick(titleI18n, languageCode, fallback: 'Ilovani yangilang');

  String messageFor(String languageCode) => _pick(
        messageI18n,
        languageCode,
        fallback: 'Yangi funksiyalar qo‘shildi. Ilovani yangilang.',
      );

  String actionLabelFor(String languageCode) =>
      _pick(actionLabelI18n, languageCode, fallback: 'Yangilash');

  Map<String, dynamic> toJson() => {
        'titleI18n': titleI18n,
        'messageI18n': messageI18n,
        'actionLabelI18n': actionLabelI18n,
      };
}

class AppBootstrapConfig {
  AppBootstrapConfig({
    required this.warningEnabled,
    required this.forceUpdate,
    required this.minAppVersionAndroid,
    required this.minAppVersionIos,
    required this.updateUrl,
    required this.updateUrlAndroid,
    required this.updateUrlIos,
    required this.syncOnLaunch,
    required this.videoOnlineOnly,
    required this.audioOfflineCache,
    required this.audioPremiumRequired,
    required this.videoPremiumRequired,
    required this.warning,
    this.updatedAt,
  });

  final bool warningEnabled;
  final bool forceUpdate;
  final String minAppVersionAndroid;
  final String minAppVersionIos;
  final String updateUrl;
  final String updateUrlAndroid;
  final String updateUrlIos;
  final bool syncOnLaunch;
  final bool videoOnlineOnly;
  final bool audioOfflineCache;
  final bool audioPremiumRequired;
  final bool videoPremiumRequired;
  final AppWarningText warning;
  final String? updatedAt;

  factory AppBootstrapConfig.fromJson(Map<String, dynamic> json) {
    return AppBootstrapConfig(
      warningEnabled: json['warningEnabled'] != false,
      forceUpdate: json['forceUpdate'] == true,
      minAppVersionAndroid:
          (json['minAppVersionAndroid'] ?? json['min_app_version_android'] ?? '')
              .toString(),
      minAppVersionIos:
          (json['minAppVersionIos'] ?? json['min_app_version_ios'] ?? '')
              .toString(),
      updateUrl: (json['updateUrl'] ?? 'https://topshirdi.uz').toString(),
      updateUrlAndroid: (json['updateUrlAndroid'] ??
              'https://play.google.com/store/apps/details?id=uz.roadtest.app&hl=en_IE')
          .toString(),
      updateUrlIos: (json['updateUrlIos'] ??
              'https://apps.apple.com/us/app/topshirdi/id6781198005')
          .toString(),
      syncOnLaunch: json['syncOnLaunch'] != false,
      videoOnlineOnly: json['videoOnlineOnly'] != false,
      audioOfflineCache: json['audioOfflineCache'] != false,
      audioPremiumRequired: json['audioPremiumRequired'] == true,
      videoPremiumRequired: json['videoPremiumRequired'] == true,
      warning: AppWarningText.fromJson(
        Map<String, dynamic>.from((json['warning'] ?? const {}) as Map),
      ),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  String titleForCurrentLanguage() =>
      warning.titleFor(AppLanguageStore.currentCode);

  String messageForCurrentLanguage() =>
      warning.messageFor(AppLanguageStore.currentCode);

  String actionLabelForCurrentLanguage() =>
      warning.actionLabelFor(AppLanguageStore.currentCode);

  Map<String, dynamic> toJson() => {
        'warningEnabled': warningEnabled,
        'forceUpdate': forceUpdate,
        'minAppVersionAndroid': minAppVersionAndroid,
        'minAppVersionIos': minAppVersionIos,
        'updateUrl': updateUrl,
        'updateUrlAndroid': updateUrlAndroid,
        'updateUrlIos': updateUrlIos,
        'syncOnLaunch': syncOnLaunch,
        'videoOnlineOnly': videoOnlineOnly,
        'audioOfflineCache': audioOfflineCache,
        'audioPremiumRequired': audioPremiumRequired,
        'videoPremiumRequired': videoPremiumRequired,
        'warning': warning.toJson(),
        'updatedAt': updatedAt,
      };
}

class OfflineSectionState {
  OfflineSectionState({
    required this.count,
    required this.updatedAt,
  });

  final int count;
  final String? updatedAt;

  factory OfflineSectionState.fromJson(Map<String, dynamic> json) {
    return OfflineSectionState(
      count: int.tryParse(json['count']?.toString() ?? '') ?? 0,
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'count': count,
        'updatedAt': updatedAt,
      };
}

class OfflineManifest {
  OfflineManifest({
    required this.language,
    required this.generatedAt,
    required this.version,
    required this.topics,
    required this.tickets,
    required this.customTests,
    required this.videos,
  });

  final String language;
  final String? generatedAt;
  final String version;
  final OfflineSectionState topics;
  final OfflineSectionState tickets;
  final OfflineSectionState customTests;
  final OfflineSectionState videos;

  factory OfflineManifest.fromJson(Map<String, dynamic> json) {
    final sections = Map<String, dynamic>.from(json['sections'] ?? const {});
    return OfflineManifest(
      language: (json['language'] ?? AppLanguageStore.uzLatn).toString(),
      generatedAt: json['generatedAt']?.toString(),
      version: (json['version'] ?? '').toString(),
      topics: OfflineSectionState.fromJson(
        Map<String, dynamic>.from(sections['topics'] ?? const {}),
      ),
      tickets: OfflineSectionState.fromJson(
        Map<String, dynamic>.from(sections['tickets'] ?? const {}),
      ),
      customTests: OfflineSectionState.fromJson(
        Map<String, dynamic>.from(sections['customTests'] ?? const {}),
      ),
      videos: OfflineSectionState.fromJson(
        Map<String, dynamic>.from(sections['videos'] ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'language': language,
        'generatedAt': generatedAt,
        'version': version,
        'sections': {
          'topics': topics.toJson(),
          'tickets': tickets.toJson(),
          'customTests': customTests.toJson(),
          'videos': videos.toJson(),
        },
      };
}

Map<String, String> _readMap(dynamic value) {
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val?.toString() ?? ''));
  }
  return <String, String>{};
}

String _pick(
  Map<String, String> value,
  String languageCode, {
  required String fallback,
}) {
  final normalized = languageCode.trim().isEmpty
      ? AppLanguageStore.uzLatn
      : languageCode.trim();
  return value[normalized] ??
      value[AppLanguageStore.uzLatn] ??
      value[AppLanguageStore.uzCyrl] ??
      value[AppLanguageStore.ru] ??
      fallback;
}
