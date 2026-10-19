import '../config/supabase_config.dart';

class Profile {
  const Profile({required this.fullName, required this.email, this.phone});

  final String fullName;
  final String email;
  final String? phone;
}

class ProfileRepo {
  ProfileRepo._();

  static Future<String> myFullName() async {
    final uid = supabase.auth.currentUser!.id;
    final row = await supabase
        .from('profiles')
        .select('full_name')
        .eq('owner_id', uid)
        .maybeSingle();
    return (row?['full_name'] as String?)?.trim() ?? '';
  }

  static Future<Profile> myProfile() async {
    final user = supabase.auth.currentUser!;
    final row = await supabase
        .from('profiles')
        .select('full_name, email, phone')
        .eq('owner_id', user.id)
        .maybeSingle();
    return Profile(
      fullName: (row?['full_name'] as String?) ?? '',
      email: (row?['email'] as String?) ?? user.email ?? '',
      phone: row?['phone'] as String?,
    );
  }

  static Future<void> updateProfile(
      {required String fullName, required String phone}) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase
        .from('profiles')
        .update({'full_name': fullName, 'phone': phone}).eq('owner_id', uid);
  }

  static Future<(int pets, int appointments)> myCounts() async {
    final uid = supabase.auth.currentUser!.id;
    final pets =
        await supabase.from('pets').select('pet_id').eq('owner_id', uid);
    final appts = await supabase
        .from('appointments')
        .select('appointment_id')
        .eq('owner_id', uid);
    return (pets.length, appts.length);
  }
}
