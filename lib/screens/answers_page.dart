import 'package:flutter/material.dart';
import 'dart:async';

import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../models/auth_session.dart';
import '../models/answer_question.dart';
import '../services/api_client.dart';

class AnswersPage extends StatefulWidget {
  const AnswersPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<AnswersPage> createState() => _AnswersPageState();
}

class _AnswersPageState extends State<AnswersPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  late String _accessToken;
  final List<AnswerQuestion> _items = <AnswerQuestion>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String _filter = 'all';
  bool _sessionExpired = false;
  static const int _pageSize = 40;

  @override
  void initState() {
    super.initState();
    _accessToken = widget.session.accessToken;
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
          setState(() {
            _accessToken = refreshed.accessToken;
          });
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AnswersHeader(onBack: () => Navigator.of(context).pop()),
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
                              'Sessiya tugadi',
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Qayta kirish kerak.',
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
                          'Hech narsa topilmadi',
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
                                        ? 'Yuklanmoqda...'
                                        : 'Ko‘proq yuklash',
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
  const _AnswersHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
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
        const Expanded(
          child: Text(
            'Barcha testlar javoblari',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
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
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Savol, izoh yoki javob bo‘yicha qidir',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.text.withValues(alpha: 0.5),
              ),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
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
          tooltip: 'Filtr',
          onSelected: onFilterChanged,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          offset: const Offset(0, 12),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'all',
              child: _FilterMenuItem(
                label: 'Barchasi',
                active: filter == 'all',
              ),
            ),
            PopupMenuItem<String>(
              value: 'with-image',
              child: _FilterMenuItem(
                label: 'Rasmli',
                active: filter == 'with-image',
              ),
            ),
            PopupMenuItem<String>(
              value: 'without-image',
              child: _FilterMenuItem(
                label: 'Rasmsiz',
                active: filter == 'without-image',
              ),
            ),
          ],
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
            '${index + 1}-savol',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.text.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            question.text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.22,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          if (question.image.trim().isNotEmpty)
            Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.surface,
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
                      ? const Color(0xFFE8F6EC)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: entry.key == question.correctIndex
                        ? const Color(0xFF86D39A)
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
                            ? const Color(0xFF2FBF71)
                            : const Color(0xFFF1F5F9),
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
                              ? const Color(0xFF137A42)
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
          if (question.explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                question.explanation,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AppColors.text.withValues(alpha: 0.82),
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
  final value = image.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  if (value.startsWith('/')) return '$apiBaseUrl$value';
  return '$apiBaseUrl/$value';
}
