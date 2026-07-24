import 'app_constants.dart';

const String defaultQuestionImageAsset = 'assets/default.png';

String resolveQuestionImageUrl(String rawImage) {
  final value = rawImage.trim();
  if (value.isEmpty) return defaultQuestionImageAsset;
  if (value.startsWith('assets/')) return value;

  final absoluteUrl = value.startsWith('http://') || value.startsWith('https://')
      ? value
      : value.startsWith('/')
          ? '$apiBaseUrl$value'
          : '$apiBaseUrl/$value';

  final proxy = Uri.parse('$apiBaseUrl/api/image').replace(
    queryParameters: {'u': absoluteUrl},
  );
  return proxy.toString();
}
