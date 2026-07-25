import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

const _lsBackground = Color(0xFFF7F9FF);
const _lsSurface = Color(0xFFFFFFFF);
const _lsBorder = Color(0xFFBFD4FF);
const _lsText = Color(0xFF1C1C1E);
const _lsTextMuted = Color(0xFF636366);
const _lsTextSoft = Color(0xFF8C8C93);

class LanguageSelectionPage extends StatelessWidget {
  const LanguageSelectionPage({
    super.key,
    required this.onSelected,
    this.compact = false,
  });

  final ValueChanged<String> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        compact ? 12 : 18,
        16,
        compact ? 16 : 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact) ...[
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _lsBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!compact) ...[
            Text(
              strings.t('choose_language'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _lsText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.t('choose_language_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: _lsTextMuted,
              ),
            ),
            const SizedBox(height: 18),
          ],
          _LanguageCard(
            title: strings.t('uz_latn'),
            icon: Icons.language_rounded,
            onTap: () => onSelected(AppLanguageStore.uzLatn),
            compact: compact,
          ),
          SizedBox(height: compact ? 10 : 12),
          _LanguageCard(
            title: strings.t('uz_cyrl'),
            icon: Icons.language_rounded,
            onTap: () => onSelected(AppLanguageStore.uzCyrl),
            compact: compact,
          ),
          SizedBox(height: compact ? 10 : 12),
          _LanguageCard(
            title: strings.t('ru'),
            icon: Icons.language_rounded,
            onTap: () => onSelected(AppLanguageStore.ru),
            compact: compact,
          ),
        ],
      ),
    );

    if (compact) {
      return Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          decoration: const BoxDecoration(
            color: _lsBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: _lsTextSoft,
                      tooltip: strings.t('close'),
                    ),
                  ],
                ),
              ),
              Flexible(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _lsBackground,
      body: SafeArea(
        child: content,
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.compact = false,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 16,
            vertical: compact ? 14 : 18,
          ),
          decoration: BoxDecoration(
            color: _lsSurface,
            borderRadius: BorderRadius.circular(compact ? 18 : 20),
            border: Border.all(color: _lsBorder.withValues(alpha: 0.65)),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 46 : 52,
                height: compact ? 46 : 52,
                decoration: BoxDecoration(
                  color: _lsBackground,
                  borderRadius: BorderRadius.circular(compact ? 16 : 18),
                ),
                child: Icon(icon, color: const Color(0xFF2F80ED), size: compact ? 24 : 28),
              ),
              SizedBox(width: compact ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: compact ? 15.5 : 16,
                        fontWeight: FontWeight.w800,
                        color: _lsText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: _lsTextSoft),
            ],
          ),
        ),
      ),
    );
  }
}
