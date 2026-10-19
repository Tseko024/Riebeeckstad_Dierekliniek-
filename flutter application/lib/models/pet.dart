const speciesOptions = ['dog', 'cat', 'bird', 'rabbit', 'reptile', 'other'];

String speciesLabel(String species) =>
    species.isEmpty ? '' : species[0].toUpperCase() + species.substring(1);

class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.age,
  });

  final String id;
  final String name;
  final String species;
  final String? breed;
  final int? age;

  factory Pet.fromMap(Map<String, dynamic> map) => Pet(
        id: map['pet_id'] as String,
        name: (map['patient_name'] as String?) ?? 'Pet',
        species: ((map['species'] as String?) ?? '').toLowerCase(),
        breed: map['breed'] as String?,
        age: (map['age'] as num?)?.toInt(),
      );

  String get ageLabel {
    final a = age;
    if (a == null) return '';
    if (a < 1) return 'Under 1 year';
    return '$a year${a == 1 ? '' : 's'}';
  }

  String get summary =>
      [speciesLabel(species), ageLabel].where((s) => s.isNotEmpty).join(' · ');
}
