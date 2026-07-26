import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/auth_session.dart';
import '../models/custom_test_progress_summary.dart';
import '../models/ticket_summary.dart';
import '../l10n/app_strings.dart';
import '../services/api_client.dart';
import '../utils/friendly_error_message.dart';
import 'custom_test_page.dart';

class CustomTestsPage extends StatefulWidget {
  const CustomTestsPage({
    super.key,
    required this.session,
    this.onSessionUpdated,
  });

  final AuthSession session;
  final ValueChanged<AuthSession>? onSessionUpdated;

  @override
  State<CustomTestsPage> createState() => _CustomTestsPageState();
}

class _CustomTestsPageState extends State<CustomTestsPage> {
  late Future<List<_CustomTestCardData>> _ticketsFuture;
  late String _accessToken;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _accessToken = widget.session.accessToken;
    _ticketsFuture = _loadTickets();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<_CustomTestCardData>> _loadTickets() async {
    try {
      final tickets = await ApiClient.customTests(_accessToken);
      return _loadTicketsWithProgress(tickets, _accessToken);
    } on ApiException catch (error) {
      if (error.statusCode != 401 ||
          widget.session.refreshToken == null ||
          widget.session.refreshToken!.isEmpty) {
        rethrow;
      }

      final refreshed = await ApiClient.refresh(widget.session.refreshToken!);
      if (!mounted) return const <_CustomTestCardData>[];
      final active = refreshed.copyWith(user: widget.session.user);

      setState(() {
        _accessToken = active.accessToken;
      });
      widget.onSessionUpdated?.call(active);

      final tickets = await ApiClient.customTests(active.accessToken);
      return _loadTicketsWithProgress(tickets, active.accessToken);
    }
  }

  Future<List<_CustomTestCardData>> _loadTicketsWithProgress(
    List<TicketSummary> tickets,
    String accessToken,
  ) async {
    final results = await Future.wait(
      tickets.map((ticket) async {
        final progress = ticket.locked
            ? null
            : await _loadProgress(ticket.id, accessToken);
        return _CustomTestCardData(ticket: ticket, progress: progress);
      }),
    );
    return results;
  }

  Future<CustomTestProgressSummary?> _loadProgress(
    String testId,
    String accessToken,
  ) async {
    try {
      return await ApiClient.customTestProgress(
        accessToken: accessToken,
        testId: testId,
      );
    } on ApiException catch (error) {
      if (error.statusCode != 401 ||
          widget.session.refreshToken == null ||
          widget.session.refreshToken!.isEmpty) {
        rethrow;
      }

      final refreshed = await ApiClient.refresh(widget.session.refreshToken!);
      if (!mounted) return null;
      final active = refreshed.copyWith(user: widget.session.user);

      setState(() {
        _accessToken = active.accessToken;
      });
      widget.onSessionUpdated?.call(active);

      return ApiClient.customTestProgress(
        accessToken: active.accessToken,
        testId: testId,
      );
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
              _TicketsHeader(onBack: () => Navigator.of(context).pop()),
              const SizedBox(height: 18),
              Expanded(
                child: FutureBuilder<List<_CustomTestCardData>>(
                  future: _ticketsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _TicketsLoader();
                    }

                    if (snapshot.hasError) {
                      return _TicketsError(
                        message: friendlyErrorMessage(context, snapshot.error),
                        onRetry: () {
                          setState(() {
                            _ticketsFuture = _loadTickets();
                          });
                        },
                      );
                    }

                    final tickets =
                        snapshot.data ?? const <_CustomTestCardData>[];
                    if (tickets.isEmpty) {
                      return const _TicketsEmpty();
                    }

                    return ListView.separated(
                      key: const PageStorageKey<String>('custom-tests-list'),
                      controller: _scrollController,
                      itemCount: tickets.length,
                      physics: const BouncingScrollPhysics(),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = tickets[index];
                        return _TicketCard(
                          ticket: item.ticket,
                          progress: item.progress,
                          onTap: item.ticket.locked
                              ? null
                              : () async {
                                  final shouldRefresh =
                                      await Navigator.of(context).push<bool>(
                                        MaterialPageRoute(
                                          builder: (_) => CustomTestPage(
                                            session: widget.session,
                                            onSessionUpdated:
                                                widget.onSessionUpdated,
                                            ticket: item.ticket,
                                          ),
                                        ),
                                      );
                                  if (shouldRefresh != false && mounted) {
                                    setState(() {
                                      _ticketsFuture = _loadTickets();
                                    });
                                  }
                                },
                        );
                      },
                    );
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

class _TicketsHeader extends StatelessWidget {
  const _TicketsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isDark = AppColors.isDarkMode;
    return Row(
      children: [
        Material(
          color: isDark ? AppColors.surfaceSoft : AppColors.surface,
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
        Text(
          strings.t('custom_tests'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap, this.progress});

  final TicketSummary ticket;
  final VoidCallback? onTap;
  final CustomTestProgressSummary? progress;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final locked = ticket.locked;
    final isDark = AppColors.isDarkMode;
    final cardColor = locked ? AppColors.surfaceSoft : AppColors.surface;
    final iconBackground = locked
        ? AppColors.surfaceTint
        : (isDark ? const Color(0xFF1A2740) : const Color(0xFFEAF1FF));
    final iconColor = locked
        ? AppColors.textSoft
        : (isDark ? const Color(0xFF7DAEFF) : const Color(0xFF4C8DFF));
    final borderColor = locked
        ? AppColors.border.withValues(alpha: isDark ? 0.85 : 0.55)
        : AppColors.border.withValues(alpha: isDark ? 0.95 : 0.75);
    final shadow = isDark
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ]
        : const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ];
    final total = ticket.questionsCount ?? 0;
    final answeredCount = progress?.answers.length ?? 0;
    final correctCount = progress?.score ?? 0;
    final wrongCount = math.max(0, answeredCount - correctCount);
    final unansweredCount = math.max(0, total - answeredCount);
    final hasProgress = !locked && total > 0;
    final progressValue = hasProgress
        ? (correctCount / total).clamp(0.0, 1.0)
        : 0.0;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: shadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  locked ? Icons.lock_rounded : Icons.receipt_long_rounded,
                  color: iconColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            ticket.title,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          locked
                              ? Icons.lock_outline_rounded
                              : Icons.chevron_right_rounded,
                          color: AppColors.textSoft,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (locked)
                      Text(
                        strings.t('custom_tests_locked'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      )
                    else ...[
                      Text(
                        '$correctCount ${strings.t('correct_short')} • $wrongCount ${strings.t('wrong_short')} • $unansweredCount ${strings.t('unanswered_short')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progressValue,
                          minHeight: 4,
                          backgroundColor: AppColors.surfaceTint,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF4D4F),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketsLoader extends StatelessWidget {
  const _TicketsLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _TicketsEmpty extends StatelessWidget {
  const _TicketsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppStrings.of(context).t('custom_tests_empty'),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _CustomTestCardData {
  const _CustomTestCardData({required this.ticket, required this.progress});

  final TicketSummary ticket;
  final CustomTestProgressSummary? progress;
}

class _TicketsError extends StatelessWidget {
  const _TicketsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppStrings.of(context).t('retry_load')),
            ),
          ],
        ),
      ),
    );
  }
}
