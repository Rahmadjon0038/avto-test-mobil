import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../l10n/app_strings.dart';

String friendlyErrorMessage(
  BuildContext context,
  Object? error, {
  String fallbackKey = 'load_failed',
}) {
  final strings = AppStrings.of(context);
  if (error is SocketException || error is TimeoutException) {
    return strings.t('internet_required');
  }

  final message = error?.toString() ?? '';
  final lower = message.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('connection timed out') ||
      lower.contains('timed out') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused')) {
    return strings.t('internet_required');
  }

  return strings.t(fallbackKey);
}
