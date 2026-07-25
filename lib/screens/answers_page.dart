import 'package:flutter/material.dart';
import 'dart:async';

import '../core/app_colors.dart';
import '../core/media_urls.dart';
import '../models/auth_session.dart';
import '../models/answer_question.dart';
import '../l10n/app_strings.dart';
import '../services/api_client.dart';
import '../widgets/question_explanation_footer.dart';

class AnswersPage extends StatefulWidget {
  const AnswersPage({super.key, required this.session, this.onSessionUpdated});

  final AuthSession session;
  final ValueChanged<AuthSession>? onSessionUpdated;

  @override
  State<AnswersPage> createState() => _AnswersPageState();
}

class _AnswersPageState extends State<AnswersPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  late String _accessToken;
  String? _languageCode;
  final List<AnswerQuestion> _items = <AnswerQuestion>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String _filter = 'all';
  bool _sessionExpired = false;
  int? _totalCount;
  static const int _pageSize = 40;

  @override
  void initState() {
    super.initState();
    _accessToken = widget.session.accessToken;
    _languageCode = AppLanguageStore.currentCode;
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLanguage = AppLanguageScope.of(context).languageCode;
    if (_languageCode == currentLanguage) return;
    _languageCode = currentLanguage;
    _reload();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _items.clear();
      _offset = 0;
      _hasMore = true;
      _sessionExpired = false;
      _totalCount = null;
    });
    try {
      await _loadPage();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _reload();
    });
  }

  Future<void> _loadPage() async {
    try {
      final body = await ApiClient.answers(
        accessToken: _accessToken,
        offset: _offset,
        limit: _pageSize,
        search: _searchController.text.trim(),
        filter: _filter,
      );
      final rawItems = body['questions'];
      final fetched = rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) =>
                      AnswerQuestion.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : <AnswerQuestion>[];
      if (!mounted) return;
      setState(() {
        _items.addAll(fetched);
        _hasMore = body['hasMore'] == true;
        final total = body['total'] ?? body['count'] ?? body['totalCount'];
        _totalCount = int.tryParse(total?.toString() ?? '');
        _offset = _items.length;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on ApiException catch (error) {
      if (error.statusCode == 401 &&
          widget.session.refreshToken != null &&
          widget.session.refreshToken!.isNotEmpty) {
        try {
          final refreshed = await ApiClient.refresh(
            widget.session.refreshToken!,
          );
          if (!mounted) return;
          final active = refreshed.copyWith(user: widget.session.user);
          setState(() {
            _accessToken = active.accessToken;
          });
          widget.onSessionUpdated?.call(active);
          await _loadPage();
          return;
        } on ApiException catch (_) {
          if (!mounted) return;
          setState(() {
            _sessionExpired = true;
            _isLoading = false;
            _isLoadingMore = false;
          });
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      rethrow;
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _sessionExpired) return;
    setState(() {
      _isLoadingMore = true;
    });
    try {
      await _loadPage();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AnswersHeader(
                onBack: () => Navigator.of(context).pop(),
                totalCount: _totalCount,
                loadedCount: _items.length,
              ),
              const SizedBox(height: 16),
              _SearchBar(
                controller: _searchController,
                onChanged: _onSearchChanged,
                filter: _filter,
                onFilterChanged: (value) {
                  if (_filter == value) return;
                  setState(() => _filter = value);
                  _reload();
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _sessionExpired
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              strings.t('session_ended_title'),
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              strings.t('session_ended_subtitle'),
                              style: TextStyle(
                                color: AppColors.text.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                    ? Center(
                        child: Text(
                          strings.t('nothing_found'),
                          style: TextStyle(
                            color: AppColors.text.withValues(alpha: 0.7),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _items.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index >= _items.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Center(
                                child: OutlinedButton(
                                  onPressed: _isLoadingMore ? null : _loadMore,
                                  child: Text(
                                    _isLoadingMore
                                        ? strings.t('loading')
                                        : strings.t('load_more'),
                                  ),
                                ),
                              ),
                            );
                          }
                          final question = _items[index];
                          return _AnswerCard(question: question, index: index);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswersHeader extends StatelessWidget {
  const _AnswersHeader({
    required this.onBack,
    required this.totalCount,
    required this.loadedCount,
  });

  final VoidCallback onBack;
  final int? totalCount;
  final int loadedCount;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Row(
      children: [
        Material(
          color: AppColors.surface,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onBack,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 46,
              height: 46,
              child: Icon(Icons.arrow_back_rounded),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  strings.t('answers'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${AppStrings.of(context).t('answers_total')} ${totalCount ?? loadedCount} ta',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.filter,
    required this.onFilterChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String filter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: strings.t('search_placeholder'),
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.text.withValues(alpha: 0.5),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          tooltip: strings.t('filter'),
          onSelected: onFilterChanged,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          offset: const Offset(0, 12),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'all',
              child: _FilterMenuItem(
                label: strings.t('all'),
                active: filter == 'all',
              ),
            ),
            PopupMenuItem<String>(
              value: 'with-image',
              child: _FilterMenuItem(
                label: strings.t('with_image'),
                active: filter == 'with-image',
              ),
            ),
            PopupMenuItem<String>(
              value: 'without-image',
              child: _FilterMenuItem(
                label: strings.t('without_image'),
                active: filter == 'without-image',
              ),
            ),
          ],
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.filter_alt_rounded,
              color: filter == 'all' ? AppColors.text : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterMenuItem extends StatelessWidget {
  const _FilterMenuItem({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.check_rounded,
          size: 18,
          color: active ? AppColors.primary : Colors.transparent,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: active ? AppColors.primary : AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.question, required this.index});

  final AnswerQuestion question;
  final int index;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}-${strings.t('question_suffix')}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.text.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            question.text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          if (question.image.trim().isNotEmpty)
            Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                _resolveImage(question.image),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          if (question.image.trim().isNotEmpty) const SizedBox(height: 10),
          ...question.options.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: entry.key == question.correctIndex
                      ? (AppColors.isDarkMode
                            ? const Color(0xFF173523)
                            : const Color(0xFFE8F6EC))
                      : AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: entry.key == question.correctIndex
                        ? (AppColors.isDarkMode
                              ? const Color(0xFF2F8A58)
                              : const Color(0xFF86D39A))
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: entry.key == question.correctIndex
                            ? (AppColors.isDarkMode
                                  ? const Color(0xFF2FBF71)
                                  : const Color(0xFF2FBF71))
                            : AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        String.fromCharCode(65 + entry.key),
                        style: TextStyle(
                          color: entry.key == question.correctIndex
                              ? Colors.white
                              : AppColors.text.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: entry.key == question.correctIndex
                              ? (AppColors.isDarkMode
                                    ? const Color(0xFFB7F0C8)
                                    : const Color(0xFF137A42))
                              : AppColors.text,
                        ),
                      ),
                    ),
                    if (entry.key == question.correctIndex)
                      const Padding(
                        padding: EdgeInsets.only(left: 6, top: 1),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF2FBF71),
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (question.audio.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  showQuestionAudioExplanationSheet(
                    context: context,
                    audioUrl: question.audio,
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(Icons.volume_up_rounded, size: 18),
                label: Text(
                  strings.t('audio_explanation'),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          if (question.explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                question.explanation,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: AppColors.text.withValues(alpha: 0.86),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _resolveImage(String image) {
  return resolveQuestionImageUrl(image);
}
