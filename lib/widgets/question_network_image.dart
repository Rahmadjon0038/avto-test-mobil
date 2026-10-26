import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/media_urls.dart';

/// Savol rasmi: ekran o'lchamiga mos variant (s/m/l), diskka keshlash va ishonchli zaxira zanjiri.
///
/// Oldin `Image.network` har safar asl rasmni (o'rtacha 400 KB, ba'zan 3 MB) backend proksisi
/// orqali qayta yuklardi. Endi:
///  * rasm to'g'ridan-to'g'ri R2'dan, kerakli o'lchamda (11–60 KB) olinadi;
///  * diskka keshlanadi (ilovani qayta ochganda ham tarmoqsiz ko'rinadi);
///  * variant topilmasa -> asl rasm -> proksi -> assets/default.png.
class QuestionNetworkImage extends StatefulWidget {
  const QuestionNetworkImage({
    super.key,
    required this.rawImage,
    this.width = double.infinity,
    this.height,
    this.fit = BoxFit.cover,
    this.variant,
    this.placeholderBuilder,
    this.errorChild,
  });

  /// `question.image` (asl, xom qiymat).
  final String rawImage;
  final double width;
  final double? height;
  final BoxFit fit;

  /// Berilmasa — joylashuv kengligi va ekran zichligiga qarab avtomatik tanlanadi.
  final ImageVariant? variant;
  final WidgetBuilder? placeholderBuilder;
  final Widget? errorChild;

  @override
  State<QuestionNetworkImage> createState() => _QuestionNetworkImageState();
}

class _QuestionNetworkImageState extends State<QuestionNetworkImage> {
  int _stage = 0;
  String _lastRaw = '';

  @override
  void didUpdateWidget(covariant QuestionNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawImage != widget.rawImage) _stage = 0;
  }

  Widget _fallback() {
    return widget.errorChild ??
        Image.asset(
          defaultQuestionImageAsset,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: Alignment.center,
        );
  }

  Widget _placeholder(BuildContext context) {
    final custom = widget.placeholderBuilder;
    if (custom != null) return custom(context);
    // Spinner o'rniga tinch fon: sahifa "yuklanmoqda" deb emas, joyi tayyor deb ko'rinadi.
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppColors.surfaceSoft,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final layoutWidth = widget.width.isFinite
            ? widget.width
            : (constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0);
        final variant = widget.variant ?? imageVariantForPixels(layoutWidth * dpr);
        final candidates = questionImageCandidates(widget.rawImage, variant: variant);
        if (candidates.isEmpty) return _fallback();

        if (_lastRaw != widget.rawImage) {
          _lastRaw = widget.rawImage;
          _stage = 0;
        }
        final stage = _stage.clamp(0, candidates.length - 1);

        return CachedNetworkImage(
          key: ValueKey('${widget.rawImage}#$stage'),
          imageUrl: candidates[stage],
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: Alignment.center,
          // Dekodlash xotirasini kamaytiradi: ekran kengligidan katta rasm xotirada saqlanmaydi.
          memCacheWidth: (layoutWidth * dpr).round(),
          fadeInDuration: const Duration(milliseconds: 120),
          placeholder: (context, url) => _placeholder(context),
          errorWidget: (context, url, error) {
            if (stage < candidates.length - 1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _stage = stage + 1);
              });
              return _placeholder(context);
            }
            return _fallback();
          },
        );
      },
    );
  }
}

/// Keyingi savollar rasmlarini oldindan keshga yuklaydi (hozirgidan keyingi [ahead] tasi).
/// Sekin ulanishda foydalanuvchi navbatdagi savolga o'tganda rasm tayyor bo'ladi.
void precacheQuestionImages(
  BuildContext context,
  List<String> rawImages,
  int currentIndex, {
  int ahead = 10,
  double layoutWidth = 360,
}) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final variant = imageVariantForPixels(layoutWidth * dpr);
  final end = (currentIndex + ahead).clamp(0, rawImages.length - 1);
  for (var index = currentIndex; index <= end; index += 1) {
    final candidates = questionImageCandidates(rawImages[index], variant: variant);
    if (candidates.isEmpty) continue;
    precacheImage(CachedNetworkImageProvider(candidates.first), context).catchError((_) {});
  }
}

/// Har bir sahifa holatida bitta nusxa: indeks yoki ro'yxat o'zgargandagina keyingi rasmlarni
/// keshga yuklaydi (build har safar chaqirilsa ham ortiqcha ish qilmaydi).
class QuestionImagePreloader {
  int? _lastIndex;
  int? _lastLength;

  void run(BuildContext context, List<String> rawImages, int currentIndex) {
    if (rawImages.isEmpty) return;
    if (_lastIndex == currentIndex && _lastLength == rawImages.length) return;
    _lastIndex = currentIndex;
    _lastLength = rawImages.length;
    final layoutWidth = MediaQuery.sizeOf(context).width - 64;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      precacheQuestionImages(context, rawImages, currentIndex, layoutWidth: layoutWidth);
    });
  }
}
