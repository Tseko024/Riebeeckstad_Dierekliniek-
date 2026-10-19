import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/appointments_repo.dart';
import '../models/appointment.dart';
import '../routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/paw_background.dart';
import '../widgets/pill_button.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  List<Appointment> _all = [];
  bool _loading = true;
  String? _error;

  int _tab = 0;
  String _query = '';
  bool _newestFirst = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AppointmentsRepo.myAppointments();
      if (mounted) setState(() => _all = list);
    } catch (e) {
      debugPrint('Load appointments error: $e');
      if (mounted) setState(() => _error = 'Could not load your appointments.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Appointment> get _upcoming => _all.where((a) => a.isUpcoming).toList();
  List<Appointment> get _cancelled => _all.where((a) => a.isCancelled).toList();
  List<Appointment> get _past =>
      _all.where((a) => !a.isCancelled && !a.isUpcoming).toList();

  List<Appointment> get _visible {
    final source =
        switch (_tab) { 0 => _upcoming, 1 => _past, _ => _cancelled };
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? source
        : source
            .where((a) =>
                a.petName.toLowerCase().contains(q) ||
                a.serviceLabel.toLowerCase().contains(q) ||
                a.reason.toLowerCase().contains(q))
            .toList();

    final ascending = (_tab == 0) != _newestFirst;
    filtered.sort((a, b) => ascending
        ? a.startsAt.compareTo(b.startsAt)
        : b.startsAt.compareTo(a.startsAt));
    return filtered;
  }

  Future<void> _bookNew() async {
    await Navigator.pushNamed(context, Routes.book);
    if (mounted) _load();
  }

  Future<void> _confirmCancel(Appointment a) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Text('${a.petName} — ${a.serviceLabel}\n'
            '${dateLong(a.startsAt)} at ${timeHm(a.startsAt)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (yes != true) return;

    try {
      await AppointmentsRepo.cancel(a.id);
      if (!mounted) return;
      Navigator.of(context)
          .popUntil((r) => r.settings.name == Routes.appointments || r.isFirst);
      _snack('Appointment cancelled.', success: true);
      _load();
    } on PostgrestException catch (e) {
      _snack(e.message);
    } catch (e) {
      debugPrint('Cancel error: $e');
      _snack('Could not cancel. Check your connection and try again.');
    }
  }

  void _snack(String text, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: success ? AppColors.navy : AppColors.red,
      ));
  }

  void _showDetails(Appointment a) {
    final text = Theme.of(context).textTheme;

    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.navy),
              const SizedBox(width: 10),
              SizedBox(width: 90, child: Text(label, style: text.bodySmall)),
              Expanded(child: Text(value, style: text.bodyMedium)),
            ],
          ),
        );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(a.serviceLabel,
                          style: AppTheme.heading(size: 26))),
                  _statusChip(a),
                ],
              ),
              const SizedBox(height: 12),
              row(Icons.pets, 'Pet', '${a.petName}  (${a.petSummary})'),
              row(Icons.calendar_month, 'Date', dateLong(a.startsAt)),
              row(Icons.schedule, 'Time', timeHm(a.startsAt)),
              row(Icons.location_on, 'Where',
                  'Riebeeckstad Dierekliniek, 138 Mc Lean St, Welkom'),
              row(Icons.person, 'Vet',
                  a.vetName ?? 'To be assigned by the clinic'),
              row(Icons.priority_high, 'Urgency', a.urgencyLabel),
              row(Icons.assignment_outlined, 'Symptoms',
                  a.reason.isEmpty ? '—' : a.reason),
              if (a.status == 'pending')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Waiting for the clinic to confirm your booking.',
                    style: text.bodySmall
                        ?.copyWith(color: const Color(0xFF8A6200)),
                  ),
                ),
              if (a.isUpcoming) ...[
                const SizedBox(height: 20),
                PillButton(
                  label: 'Cancel appointment',
                  color: AppColors.red,
                  icon: Icons.event_busy,
                  trailingIcon: Icons.close,
                  onPressed: () => _confirmCancel(a),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Image.asset('assets/images/logo.png', height: 56),
      ),
      bottomNavigationBar:
          const AppBottomNav(currentRoute: Routes.appointments),
      body: PawBackground(
        seed: 7,
        child: RefreshIndicator(
          onRefresh: _load,
          // Full width, like the Home screen (no narrow centred column).
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text('My Appointments',
                  style: AppTheme.heading(size: 30)
                      .copyWith(fontStyle: FontStyle.italic)),
              const Text('View and manage all your upcoming appointments'),
              const SizedBox(height: 14),
              _tabs(),
              const SizedBox(height: 12),
              _searchRow(),
              const SizedBox(height: 12),
              ..._content(),
              const SizedBox(height: 24),
              _bookNewSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabs() {
    final labels = [
      'Upcoming (${_upcoming.length})',
      'Past (${_past.length})',
      'Cancelled (${_cancelled.length})',
    ];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _tab == i ? AppColors.navy : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 3)
                  ],
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _tab == i ? Colors.white : AppColors.navy,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _searchRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search appointments...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: _newestFirst ? 'Sort: newest first' : 'Sort: oldest first',
          icon: const Icon(Icons.tune),
          onPressed: () => setState(() => _newestFirst = !_newestFirst),
        ),
      ],
    );
  }

  List<Widget> _content() {
    if (_loading) {
      return const [
        Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator())),
      ];
    }
    if (_error != null) {
      return [
        Center(child: Text(_error!)),
        Center(
            child:
                TextButton(onPressed: _load, child: const Text('Try again'))),
      ];
    }
    final list = _visible;
    if (list.isEmpty) {
      final message = _query.isNotEmpty
          ? 'No appointments match "$_query".'
          : switch (_tab) {
              0 => 'You have no upcoming appointments.',
              1 => 'No past appointments yet.',
              _ => 'No cancelled appointments.',
            };
      return [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ];
    }
    return [
      for (final a in list) ...[
        _appointmentCard(a),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _appointmentCard(Appointment a) {
    final text = Theme.of(context).textTheme;

    Widget info(IconData icon, String value) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.navy),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(value,
                      style: text.bodySmall, overflow: TextOverflow.ellipsis)),
            ],
          ),
        );

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetails(a),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Pet
              SizedBox(
                width: 84,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.tile,
                      child: Icon(
                          a.petSpecies == 'cat'
                              ? Icons.pets_outlined
                              : Icons.pets,
                          color: AppColors.navy),
                    ),
                    const SizedBox(height: 4),
                    Text(a.petName,
                        style: AppTheme.heading(size: 16),
                        overflow: TextOverflow.ellipsis),
                    Text(a.petSummary,
                        textAlign: TextAlign.center,
                        style: text.bodySmall?.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(a.serviceLabel,
                              style: AppTheme.heading(size: 18),
                              overflow: TextOverflow.ellipsis),
                        ),
                        _statusChip(a),
                      ],
                    ),
                    info(Icons.calendar_month, dateLong(a.startsAt)),
                    info(Icons.schedule, timeHm(a.startsAt)),
                    info(Icons.location_on, 'Riebeeckstad Dierekliniek'),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        onPressed: () => _showDetails(a),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.navy,
                          side: const BorderSide(color: AppColors.navy),
                          shape: const StadiumBorder(),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('View Details',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(Appointment a) {
    final label =
        (!a.isUpcoming && (a.status == 'pending' || a.status == 'confirmed'))
            ? 'Past'
            : a.statusLabel;
    final (bg, fg) = switch (a.status) {
      'confirmed' when a.isUpcoming => (
          const Color(0xFFD7F5D9),
          const Color(0xFF1B7A2B)
        ),
      'pending' when a.isUpcoming => (
          const Color(0xFFFFF1C9),
          const Color(0xFF8A6200)
        ),
      'cancelled' => (const Color(0xFFF8D7DA), AppColors.red),
      'completed' => (const Color(0xFFDDE3F5), AppColors.navy),
      _ => (AppColors.tile, AppColors.textDark),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style:
              TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _bookNewSection() {
    return Column(
      children: [
        const Text('Need to book a new appointment?',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: PillButton(
            label: 'Book New Appointment',
            color: AppColors.red,
            icon: Icons.calendar_month,
            height: 48,
            onPressed: _bookNew,
          ),
        ),
      ],
    );
  }
}
