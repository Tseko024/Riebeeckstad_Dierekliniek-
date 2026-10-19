import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/pets_repo.dart';
import '../models/medical_record.dart';
import '../models/pet.dart';
import '../routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/add_pet_sheet.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/paw_background.dart';
import '../widgets/pill_button.dart';

class MyPetsScreen extends StatefulWidget {
  const MyPetsScreen({super.key});

  @override
  State<MyPetsScreen> createState() => _MyPetsScreenState();
}

class _MyPetsScreenState extends State<MyPetsScreen> {
  List<Pet> _pets = [];
  bool _loading = true;
  String? _error;

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
      final pets = await PetsRepo.myPets();
      if (mounted) setState(() => _pets = pets);
    } catch (e) {
      debugPrint('Load pets error: $e');
      if (mounted) setState(() => _error = 'Could not load your pets.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addPet() async {
    final pet = await showAddPetSheet(context);
    if (pet != null) {
      _snack('${pet.name} added.', success: true);
      _load();
    }
  }

  Future<void> _editPet(Pet pet) async {
    final updated = await showAddPetSheet(context, pet: pet);
    if (updated != null) {
      _snack('${updated.name} updated.', success: true);
      _load();
    }
  }

  Future<void> _deletePet(Pet pet) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${pet.name}?'),
        content: const Text('This removes the pet from your account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes != true) return;

    try {
      await PetsRepo.deletePet(pet.id);
      _snack('${pet.name} removed.', success: true);
      _load();
    } on PostgrestException catch (e) {
      _snack(e.code == '23503'
          ? '${pet.name} has appointments or medical records, so they can\'t be removed. '
              'Please contact the clinic if this pet is no longer with you.'
          : e.message);
    } catch (e) {
      debugPrint('Delete pet error: $e');
      _snack('Could not remove the pet. Check your connection and try again.');
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

  void _showDetails(Pet pet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => _PetDetails(
          pet: pet,
          scrollController: scroll,
          onEdit: () {
            Navigator.pop(ctx);
            _editPet(pet);
          },
          onDelete: () {
            Navigator.pop(ctx);
            _deletePet(pet);
          },
          onBook: () {
            Navigator.pop(ctx);
            Navigator.pushNamed(context, Routes.book);
          },
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
      bottomNavigationBar: const AppBottomNav(currentRoute: Routes.pets),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPet,
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add a Pet'),
      ),
      body: PawBackground(
        seed: 11,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              Text('My Pets',
                  style: AppTheme.heading(size: 30)
                      .copyWith(fontStyle: FontStyle.italic)),
              const Text('View and manage your pets'),
              const SizedBox(height: 16),
              ..._content(),
            ],
          ),
        ),
      ),
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
    if (_pets.isEmpty) {
      return [
        const SizedBox(height: 24),
        Image.asset('assets/images/pets.png', height: 140),
        const SizedBox(height: 12),
        const Text("You haven't added any pets yet.",
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: PillButton(
              label: 'Add your first pet',
              color: AppColors.navy,
              icon: Icons.pets,
              onPressed: _addPet,
            ),
          ),
        ),
      ];
    }

    return [
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _pets.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 104,
        ),
        itemBuilder: (_, i) => _petCard(_pets[i]),
      ),
    ];
  }

  Widget _petCard(Pet pet) {
    final text = Theme.of(context).textTheme;

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetails(pet),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.tile,
                child: Icon(
                    pet.species == 'cat' ? Icons.pets_outlined : Icons.pets,
                    color: AppColors.navy,
                    size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.name,
                        style: AppTheme.heading(size: 22),
                        overflow: TextOverflow.ellipsis),
                    Text(pet.summary, style: text.bodyMedium),
                    if (pet.breed != null && pet.breed!.isNotEmpty)
                      Text(pet.breed!,
                          style: text.bodySmall,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.navy),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetDetails extends StatefulWidget {
  const _PetDetails({
    required this.pet,
    required this.scrollController,
    required this.onEdit,
    required this.onDelete,
    required this.onBook,
  });

  final Pet pet;
  final ScrollController scrollController;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onBook;

  @override
  State<_PetDetails> createState() => _PetDetailsState();
}

class _PetDetailsState extends State<_PetDetails> {
  late Future<List<MedicalRecord>> _history;

  @override
  void initState() {
    super.initState();
    _history = PetsRepo.medicalHistory(widget.pet.id);
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final text = Theme.of(context).textTheme;

    Widget info(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(width: 80, child: Text(label, style: text.bodySmall)),
              Expanded(
                  child: Text(value.isEmpty ? '—' : value,
                      style: text.bodyMedium)),
            ],
          ),
        );

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.tile,
              child: Icon(
                  pet.species == 'cat' ? Icons.pets_outlined : Icons.pets,
                  color: AppColors.navy,
                  size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(pet.name, style: AppTheme.heading(size: 28))),
          ],
        ),
        const SizedBox(height: 12),
        info('Species', speciesLabel(pet.species)),
        info('Breed', pet.breed ?? ''),
        info('Age', pet.ageLabel),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PillButton(
          label: 'Book an appointment',
          color: AppColors.red,
          icon: Icons.calendar_month,
          onPressed: widget.onBook,
        ),
        const Divider(height: 32),
        Row(
          children: [
            const Icon(Icons.medical_information_outlined,
                color: AppColors.navy),
            const SizedBox(width: 8),
            Text('Medical History',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<MedicalRecord>>(
          future: _history,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return const Text('Could not load medical history.');
            }
            final records = snap.data ?? [];
            if (records.isEmpty) {
              return Text(
                  'No medical records yet. Records are added by the vet after a visit.',
                  style: text.bodySmall);
            }
            return Column(
              children: [
                for (final r in records)
                  Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateLong(r.visitDate),
                              style: text.titleSmall?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700)),
                          if (r.diagnosis?.isNotEmpty == true)
                            Text('Diagnosis: ${r.diagnosis}'),
                          if (r.treatment?.isNotEmpty == true)
                            Text('Treatment: ${r.treatment}'),
                          if (r.medications?.isNotEmpty == true)
                            Text('Medication: ${r.medications}'),
                          if (r.notes?.isNotEmpty == true)
                            Text(r.notes!, style: text.bodySmall),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
