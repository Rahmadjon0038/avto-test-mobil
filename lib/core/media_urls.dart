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

// ---------------------------------------------------------------------------------------------
// Rasm variantlari (s/m/l). Backend har bir rasm uchun uchta webp nusxa saqlaydi:
//   images/<nom>.<ext>  ->  images/s|m|l/<nom>.webp   (480 / 800 / 1280 px)
// Variant manzili faqat nomdan hosil qilinadi, shuning uchun bazadagi `image` maydonlari
// o'zgarmaydi. Eski rasm (variant yaratilmagan) yoki boshqa host bo'lsa — asl manzilga qaytiladi.
// ---------------------------------------------------------------------------------------------
enum ImageVariant { s, m, l }

const Map<ImageVariant, int> imageVariantWidths = {
  ImageVariant.s: 480,
  ImageVariant.m: 800,
  ImageVariant.l: 1280,
};

// R2 ni o'z domeniga ulaganda: flutter build --dart-define=IMAGE_HOSTS=cdn.topshirdi.uz
const String _extraImageHosts = String.fromEnvironment('IMAGE_HOSTS');

bool _isDirectImageHost(String host) {
  final value = host.toLowerCase();
  if (value.endsWith('r2.dev') || value.endsWith('r2.cloudflarestorage.com')) {
    return true;
  }
  return _extraImageHosts
      .split(',')
      .map((item) => item.trim().toLowerCase())
      .where((item) => item.isNotEmpty)
      .contains(value);
}

final RegExp _originalImagePath = RegExp(
  r'^/images/([^/]+)\.(jpe?g|png|webp|avif)$',
  caseSensitive: false,
);

/// Ekran kengligiga (piksel) mos variant.
ImageVariant imageVariantForPixels(double physicalWidth) {
  if (physicalWidth <= imageVariantWidths[ImageVariant.s]!) {
    return ImageVariant.s;
  }
  if (physicalWidth <= imageVariantWidths[ImageVariant.m]!) {
    return ImageVariant.m;
  }
  return ImageVariant.l;
}

/// Rasmni yuklash urinishlari tartibi: [variant (to'g'ridan-to'g'ri), asl (to'g'ridan-to'g'ri),
/// asl (backend proksi orqali)]. Bo'sh ro'yxat — rasm yo'q (zaxira rasm ko'rsatiladi).
List<String> questionImageCandidates(String rawImage, {ImageVariant? variant}) {
  final value = rawImage.trim();
  if (value.isEmpty || value.startsWith('assets/')) return const <String>[];

  final absoluteUrl = value.startsWith('http://') || value.startsWith('https://')
      ? value
      : value.startsWith('/')
          ? '$apiBaseUrl$value'
          : '$apiBaseUrl/$value';
  final proxyUrl = resolveQuestionImageUrl(absoluteUrl);

  final parsed = Uri.tryParse(absoluteUrl);
  final match = parsed == null ? null : _originalImagePath.firstMatch(parsed.path);
  if (parsed == null || match == null || !_isDirectImageHost(parsed.host)) {
    // Noma'lum host: eskicha, faqat backend proksi orqali.
    return <String>[proxyUrl];
  }

  final origin = '${parsed.scheme}://${parsed.authority}';
  final candidates = <String>[
    if (variant != null) '$origin/images/${variant.name}/${match.group(1)}.webp',
    absoluteUrl,
    proxyUrl,
  ];
  return candidates;
}
