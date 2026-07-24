import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/auth_session.dart';
import '../models/ticket_summary.dart';
import '../l10n/app_strings.dart';
import '../services/api_client.dart';
import '../services/ticket_test_progress_store.dart';
import '../utils/friendly_error_message.dart';
import 'ticket_test_page.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key, required this.session, this.onSessionUpdated});

  final AuthSession session;
  final ValueChanged<AuthSession>? onSessionUpdated;

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  late Future<_TicketsLoadResult> _ticketsFuture;
  late String _accessToken;
  String? _languageCode;

  @override
  void initState() {
    super.initState();
    _accessToken = widget.session.accessToken;
    _languageCode = AppLanguageStore.currentCode;
    _ticketsFuture = _loadTickets();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLanguage = AppLanguageScope.of(context).languageCode;
    if (_languageCode == currentLanguage) return;
    _languageCode = currentLanguage;
    setState(() {
      _ticketsFuture = _loadTickets();
    });
  }

  Future<_TicketsLoadResult> _loadTickets() async {
    try {
      final tickets = await ApiClient.tickets(_accessToken);
      final progress = await TicketTestProgressStore.loadAll();
      return _TicketsLoadResult(
        tickets: tickets,
        progressByTicketId: {
          for (final entry in progress.entries)
            if (entry.value.result != null) entry.key: entry.value.result!,
        },
      );
    } on ApiException catch (error) {
      if (error.statusCode != 401 ||
          widget.session.refreshToken == null ||
          widget.session.refreshToken!.isEmpty) {
        rethrow;
      }

      final refreshed = await ApiClient.refresh(widget.session.refreshToken!);
      if (!mounted) {
        return const _TicketsLoadResult(
          tickets: <TicketSummary>[],
          progressByTicketId: <String, TicketTestResult>{},
        );
      }
      final active = refreshed.copyWith(user: widget.session.user);

      setState(() {
        _accessToken = active.accessToken;
      });
      widget.onSessionUpdated?.call(active);

      final tickets = await ApiClient.tickets(active.accessToken);
      final progress = await TicketTestProgressStore.loadAll();
      return _TicketsLoadResult(
        tickets: tickets,
        progressByTicketId: {
          for (final entry in progress.entries)
            if (entry.value.result != null) entry.key: entry.value.result!,
        },
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
                child: FutureBuilder<_TicketsLoadResult>(
                  future: _ticketsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _TicketsLoader();
                    }

                    if (snapshot.hasError) {
                      return _TicketsError(
                        message: friendlyErrorMessage(
                          context,
                          snapshot.error,
                        ),
                        onRetry: () {
                          setState(() {
                            _ticketsFuture = _loadTickets();
                          });
                        },
                      );
                    }

                    final data =
                        snapshot.data ??
                        const _TicketsLoadResult(
                          tickets: <TicketSummary>[],
                          progressByTicketId: <String, TicketTestResult>{},
                        );
                    final tickets = data.tickets;
                    if (tickets.isEmpty) {
                      return const _TicketsEmpty();
                    }

                    return ListView.separated(
                      itemCount: tickets.length,
                      physics: const BouncingScrollPhysics(),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final ticket = tickets[index];
                        return _TicketCard(
                          ticket: ticket,
                          progress: data.progressByTicketId[ticket.id],
                          onTap: ticket.locked
                              ? null
                              : () async {
                                  final shouldRefresh =
                                      await Navigator.of(context).push<bool>(
                                        MaterialPageRoute(
                                          builder: (_) => TicketTestPage(
                                            session: widget.session,
                                            onSessionUpdated:
                                                widget.onSessionUpdated,
                                            ticket: ticket,
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
        Text(
          strings.t('tickets'),
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
  final TicketTestResult? progress;

  @override
  Widget build(BuildContext context) {
    final locked = ticket.locked;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: locked ? AppColors.surfaceSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: locked
                  ? AppColors.border.withValues(alpha: 0.55)
                  : AppColors.border.withValues(alpha: 0.75),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: locked
                      ? AppColors.surfaceTint
                      : AppColors.surfaceTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  locked ? Icons.lock_rounded : Icons.receipt_long_rounded,
                  color: locked
                      ? AppColors.textSoft
                      : AppColors.primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 10),
                      _TicketProgressPreview(progress: progress!),
                    ],
                  ],
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

class _TicketsLoadResult {
  const _TicketsLoadResult({
    required this.tickets,
    required this.progressByTicketId,
  });

  final List<TicketSummary> tickets;
  final Map<String, TicketTestResult> progressByTicketId;
}

class _TicketProgressPreview extends StatelessWidget {
  const _TicketProgressPreview({required this.progress});

  final TicketTestResult progress;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final unanswered = (progress.total - progress.correct - progress.wrong)
        .clamp(0, progress.total)
        .toInt();
    final percent = progress.total <= 0 ? 0 : progress.percent.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${progress.correct} ${strings.t('correct_short')} · ${progress.wrong} ${strings.t('wrong_short')} · $unanswered ${strings.t('unanswered_short')}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: percent / 100,
            backgroundColor: AppColors.surfaceSoft,
            valueColor: AlwaysStoppedAnimation<Color>(
              percent >= 70
                  ? const Color(0xFF21A65B)
                  : percent >= 40
                  ? const Color(0xFFF0A23A)
                  : const Color(0xFFD64545),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketsEmpty extends StatelessWidget {
  const _TicketsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppStrings.of(context).t('no_content'),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
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
