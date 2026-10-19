import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/appointments_repo.dart';
import '../data/clinic_hours.dart';
import '../data/pets_repo.dart';
import '../models/appointment.dart';
import '../models/pet.dart';
import '../routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/add_pet_sheet.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/paw_background.dart';
import '../widgets/pill_button.dart';

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  List<Pet> _pets = [];
  List<TimeSlot> _slots = [];
  bool _loadingPets = true;
  bool _loadingSlots = false;
  String? _petsError;
  String? _slotsError;

  Pet? _pet;
  String? _service;
  late final DateTime _firstDay;
  late DateTime _date;
  TimeSlot? _slot;
  String _urgency = 'routine';
  final _symptoms = TextEditingController();
  bool _submitting = false;

  static const _services = [
    ('general_checkup', Icons.medical_services_outlined),
    ('vaccination', Icons.vaccines),
    ('surgery', Icons.healing),
    ('dental', Icons.sentiment_satisfied_alt),
    ('other', Icons.more_horiz),
  ];

  @override
  void initState() {
    super.initState();
    _firstDay = _firstBookableDay();
    _date = _firstDay;
    _loadPets();
    _loadSlots();
  }

  @override
  void dispose() {
    _symptoms.dispose();
    super.dispose();
  }

  bool _readArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readArgs) return;
    _readArgs = true;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String && serviceLabels.containsKey(arg)) {
      _service = arg;
    }
  }

  bool _isOpenDay(DateTime day) =>
      ClinicHours.periodsFor(day.weekday).isNotEmpty;

  DateTime _firstBookableDay() {
    final now = ClinicHours.nowInClinic(); // South African time
    var day = DateTime(now.year, now.month, now.day);

    final today = ClinicHours.periodsFor(day.weekday);
    final minuteNow = now.hour * 60 + now.minute;
    if (today.isEmpty || today.last.endMinute - 30 <= minuteNow) {
      day = day.add(const Duration(days: 1));
    }
    while (!_isOpenDay(day)) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  Future<void> _loadPets() async {
    setState(() {
      _loadingPets = true;
      _petsError = null;
    });
    try {
      final pets = await PetsRepo.myPets();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        if (pets.length == 1) _pet = pets.first;
      });
    } catch (e) {
      debugPrint('Load pets error: $e');
      if (mounted) setState(() => _petsError = 'Could not load your pets.');
    } finally {
      if (mounted) setState(() => _loadingPets = false);
    }
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _slotsError = null;
      _slot = null;
    });
    try {
      final slots = await AppointmentsRepo.slotsFor(_date);
      if (mounted) setState(() => _slots = slots);
    } catch (e) {
      debugPrint('Load slots error: $e');
      if (mounted) {
        setState(() => _slotsError = 'Could not load available times.');
      }
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  Future<void> _addPet() async {
    final pet = await showAddPetSheet(context);
    if (pet == null || !mounted) return;
    setState(() {
      _pets = [..._pets, pet];
      _pet = pet;
    });
  }

  String? _missing() {
    if (_pet == null) return 'Please select a pet (or add one).';
    if (_service == null) return 'Please select a service.';
    if (_slot == null) return 'Please select a time.';
    if (_symptoms.text.trim().length < 5) {
      return 'Please describe the symptoms or reason for the visit.';
    }
    return null;
  }

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();
    final problem = _missing();
    if (problem != null) {
      _message(problem);
      return;
    }

    setState(() => _submitting = true);
    try {
      await AppointmentsRepo.book(
        petId: _pet!.id,
        service: _service!,
        date: _date,
        time: _slot!.dbTime,
        reason: _symptoms.text.trim(),
        urgency: _urgency,
      );
      if (!mounted) return;
      await _showSuccess();
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      _message(e.message.contains('not available')
          ? 'Sorry, that time was just taken. Please choose another time.'
          : e.message);
      _loadSlots();
    } catch (e) {
      debugPrint('Booking error: $e');
      _message(
          'Could not book the appointment. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccess() {
    final when =
        '${dateLong(_slot!.clinicTime)} at ${timeHm(_slot!.clinicTime)}';
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Appointment requested'),
        content: Text(
          '${_pet!.name} — ${serviceLabels[_service]}\n$when\n\n'
          'Your booking is pending until the clinic confirms it. '
          'You can follow it under My Appointments.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(text), backgroundColor: AppColors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Image.asset('assets/images/logo.png', height: 56),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: Routes.book),
      body: PawBackground(
        seed: 5,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('Book Appointment',
                style: AppTheme.heading(size: 30)
                    .copyWith(fontStyle: FontStyle.italic)),
            const Row(
              children: [
                Text('All your pets care, just a few steps away '),
                Icon(Icons.favorite, color: AppColors.red, size: 16),
              ],
            ),
            _sectionTitle(Icons.pets, '1. Select a Pet'),
            _petPicker(),
            _sectionTitle(Icons.pets, '2. Select a Service'),
            _servicePicker(),
            _sectionTitle(Icons.calendar_month, '3. Select date'),
            _datePicker(),
            _sectionTitle(Icons.schedule, '4. Select time'),
            _timePicker(),
            _sectionTitle(Icons.assignment_outlined, '5. Symptoms'),
            _symptomsField(),
            const SizedBox(height: 12),
            _urgencyPicker(),
            const SizedBox(height: 24),
            _buttons(),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textDark),
            const SizedBox(width: 6),
            Text(text,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  BoxDecoration _cardDecoration(bool selected) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.navy : Colors.transparent,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      );

  Widget _petPicker() {
    if (_loadingPets) {
      return const SizedBox(
          height: 100, child: Center(child: CircularProgressIndicator()));
    }
    if (_petsError != null) {
      return Row(children: [
        Text(_petsError!),
        TextButton(onPressed: _loadPets, child: const Text('Retry')),
      ]);
    }

    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final pet in _pets) ...[
            _petCard(pet),
            const SizedBox(width: 10),
          ],
          _addPetCard(),
        ],
      ),
    );
  }

  Widget _petCard(Pet pet) {
    final selected = _pet?.id == pet.id;
    return GestureDetector(
      onTap: () => setState(() => _pet = pet),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(8),
        decoration: _cardDecoration(selected),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.tile,
              child: Icon(
                  pet.species == 'cat' ? Icons.pets_outlined : Icons.pets,
                  color: AppColors.navy,
                  size: 20),
            ),
            const SizedBox(height: 4),
            Text(pet.name,
                style: AppTheme.heading(size: 16),
                overflow: TextOverflow.ellipsis),
            Text(pet.summary,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _addPetCard() {
    return GestureDetector(
      onTap: _addPet,
      child: Container(
        width: 100,
        decoration: _cardDecoration(false),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFF1E5EFF),
              child: Icon(Icons.add, color: Colors.white),
            ),
            SizedBox(height: 6),
            Text('Add a Pet',
                style: TextStyle(
                    color: AppColors.navy, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _servicePicker() {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (value, icon) = _services[i];
          final selected = _service == value;
          return GestureDetector(
            onTap: () => setState(() => _service = value),
            child: Container(
              width: 82,
              padding: const EdgeInsets.all(6),
              decoration: _cardDecoration(selected),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.navy, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    serviceLabels[value]!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: AppColors.navy),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _datePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: _cardDecoration(false),
          child: CalendarDatePicker(
            initialDate: _date,
            firstDate: _firstDay,
            lastDate: _firstDay.add(const Duration(days: 60)),
            selectableDayPredicate: _isOpenDay,
            onDateChanged: (d) {
              setState(() => _date = d);
              _loadSlots();
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          ClinicHours.summary,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _timePicker() {
    if (_loadingSlots) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_slotsError != null) {
      return Row(children: [
        Text(_slotsError!),
        TextButton(onPressed: _loadSlots, child: const Text('Retry')),
      ]);
    }
    final open = _slots.where((s) => s.available).length;
    if (_slots.isEmpty || open == 0) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'No times available on ${dateLong(_date)}. Please choose another day.',
          style: const TextStyle(color: AppColors.red),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${dateLong(_date)} · $open available',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slot in _slots)
              ChoiceChip(
                label: Text(timeHm(slot.clinicTime)),
                selected: _slot == slot,
                selectedColor: AppColors.red,
                labelStyle: TextStyle(
                  color: _slot == slot ? Colors.white : AppColors.textDark,
                  decoration:
                      slot.available ? null : TextDecoration.lineThrough,
                ),
                showCheckmark: false,
                onSelected:
                    slot.available ? (_) => setState(() => _slot = slot) : null,
              ),
          ],
        ),
      ],
    );
  }

  Widget _symptomsField() {
    return TextField(
      controller: _symptoms,
      minLines: 3,
      maxLines: 6,
      maxLength: 500,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: 'Please enter the symptoms of your pet',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _urgencyPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('How urgent is it?',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'routine', label: Text('Routine')),
            ButtonSegment(value: 'soon', label: Text('Soon')),
            ButtonSegment(value: 'urgent', label: Text('Urgent')),
          ],
          selected: {_urgency},
          onSelectionChanged: (s) => setState(() => _urgency = s.first),
        ),
        if (_urgency == 'urgent')
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'For emergencies, please also phone the clinic on 057 388 1409.',
              style: TextStyle(color: AppColors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buttons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _submitting ? null : () => Navigator.maybePop(context),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.textDark,
                shape: const StadiumBorder(),
              ),
              child: const Text('Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: PillButton(
            label: 'Confirm Appointment',
            color: AppColors.red,
            icon: Icons.event_available,
            trailingIcon: Icons.arrow_forward,
            height: 48,
            loading: _submitting,
            onPressed: _confirm,
          ),
        ),
      ],
    );
  }
}
