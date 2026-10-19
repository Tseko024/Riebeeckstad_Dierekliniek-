import '../config/supabase_config.dart';
import '../models/medical_record.dart';
import '../models/pet.dart';

class PetsRepo {
  PetsRepo._();

  static const _columns = 'pet_id, patient_name, species, breed, age';

  static Future<List<Pet>> myPets() async {
    final uid = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('pets')
        .select(_columns)
        .eq('owner_id', uid)
        .order('created_at', ascending: true);
    return rows.map(Pet.fromMap).toList();
  }

  static Future<Pet> addPet({
    required String name,
    required String species,
    String? breed,
    int? age,
  }) async {
    final row = await supabase
        .from('pets')
        .insert({
          'owner_id': supabase.auth.currentUser!.id,
          'patient_name': name,
          'species': species,
          'breed': (breed == null || breed.isEmpty) ? null : breed,
          'age': age,
        })
        .select(_columns)
        .single();
    return Pet.fromMap(row);
  }

  static Future<Pet> updatePet({
    required String petId,
    required String name,
    required String species,
    String? breed,
    int? age,
  }) async {
    final row = await supabase
        .from('pets')
        .update({
          'patient_name': name,
          'species': species,
          'breed': (breed == null || breed.isEmpty) ? null : breed,
          'age': age,
        })
        .eq('pet_id', petId)
        .select(_columns)
        .single();
    return Pet.fromMap(row);
  }

  static Future<void> deletePet(String petId) async {
    await supabase.from('pets').delete().eq('pet_id', petId);
  }

  static Future<List<MedicalRecord>> medicalHistory(String petId) async {
    final rows = await supabase
        .from('medical_history')
        .select('visit_date, diagnosis, treatment, medications, notes')
        .eq('pet_id', petId)
        .order('visit_date', ascending: false);
    return rows.map(MedicalRecord.fromMap).toList();
  }
}
