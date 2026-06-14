import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/auth_session.dart';
import '../models/ticket_summary.dart';
import '../services/api_client.dart';
import 'ticket_test_page.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({
    super.key,
    required this.session,
    this.onSessionUpdated,
  });

  final AuthSession session;
  final ValueChanged<AuthSession>? onSessionUpdated;

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  late Future<List<TicketSummary>> _ticketsFuture;
  late String _accessToken;

  @override
  void initState() {
    super.initState();
    _accessToken = widget.session.accessToken;
    _ticketsFuture = _loadTickets();
  }

  Future<List<TicketSummary>> _loadTickets() async {
    try {
      return await ApiClient.tickets(_accessToken);
    } on ApiException catch (error) {
      if (error.statusCode != 401 || widget.session.refreshToken == null || widget.session.refreshToken!.isEmpty) {
        rethrow;
      }

      final refreshed = await ApiClient.refresh(widget.session.refreshToken!);
      if (!mounted) return const <TicketSummary>[];
      final active = refreshed.copyWith(user: widget.session.user);

      setState(() {
        _accessToken = active.accessToken;
      });
      widget.onSessionUpdated?.call(active);

      return ApiClient.tickets(active.accessToken);
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
                child: FutureBuilder<List<TicketSummary>>(
                  future: _ticketsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _TicketsLoader();
                    }

                    if (snapshot.hasError) {
                      return _TicketsError(
                        message: snapshot.error.toString(),
                        onRetry: () {
                          setState(() {
                            _ticketsFuture = _loadTickets();
                          });
                        },
                      );
                    }

                    final tickets = snapshot.data ?? const <TicketSummary>[];
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
                          onTap: ticket.locked
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TicketTestPage(
                                        session: widget.session,
                                        onSessionUpdated: widget.onSessionUpdated,
                                        ticket: ticket,
                                      ),
                                    ),
                                  );
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
        const Text(
          'Biletlar',
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
  const _TicketCard({required this.ticket, required this.onTap});

  final TicketSummary ticket;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = ticket.locked;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: locked ? const Color(0xFFF6F7FB) : Colors.white,
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
                      ? const Color(0xFFEDEFF6)
                      : const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  locked ? Icons.lock_rounded : Icons.receipt_long_rounded,
                  color: locked
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF4C8DFF),
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locked ? 'Hozircha ochilmagan' : 'Bosib yeching',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
                color: const Color(0xFFB5B8C0),
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

class _TicketsEmpty extends StatelessWidget {
  const _TicketsEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Biletlar topilmadi',
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
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Qayta urinish'),
            ),
          ],
        ),
      ),
    );
  }
}
