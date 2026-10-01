// lib/features/auth/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers/supabase_provider.dart';

// Current auth user (Supabase User)
final authUserProvider = StreamProvider<User?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange
      .handleError((_) {})
      .map((event) => event.session?.user);
});

// Current user profile from DB
final authStateProvider = StreamProvider<Profile?>((ref) async* {
  final supabase = ref.watch(supabaseClientProvider);

  // Demo fallback
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  if (supabaseUrl.contains('your-project-ref')) {
    yield Profile(
      id: '00000000-0000-0000-0000-000000000000',
      fullName: 'IZYHEAT Admin (Demo)',
      email: 'admin@izyheat.com',
      phone: '+91 99999 99999',
      roles: [UserRole.admin],
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return;
  }

  // 1. Initial cached profile emission to eliminate splash screen flicker
  try {
    final prefs = await SharedPreferences.getInstance();
    final staffId = prefs.getString('staff_session_id') ??
        prefs.getString('technician_session_id');
    final staffRoleStr = prefs.getString('staff_session_role') ?? 'technician';
    final staffRolesList = prefs.getStringList('staff_session_roles');
    final staffEmail = prefs.getString('staff_session_email') ?? '';
    final staffName = prefs.getString('staff_session_name') ?? 'Staff';

    if (staffId != null && staffId.isNotEmpty) {
      final roles = (staffRolesList != null && staffRolesList.isNotEmpty)
          ? staffRolesList.map((r) => UserRole.fromString(r)).toList()
          : [UserRole.fromString(staffRoleStr)];
      yield Profile(
        id: staffId,
        fullName: staffName,
        email: staffEmail,
        phone: '',
        roles: roles,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  } catch (_) {}

  // 2. Stream Supabase auth state changes
  final authStream = supabase.auth.onAuthStateChange.handleError((_, __) {});

  await for (final authChange in authStream) {
    final user = authChange.session?.user;

    if (user == null) {
      final prefs = await SharedPreferences.getInstance();
      final staffId = prefs.getString('staff_session_id');

      // If no auth user and no offline staff session, user is logged out
      if (staffId == null || staffId.isEmpty) {
        yield null;
      }
      continue;
    }

    // Handle Mock User
    if (user.id.startsWith('mock-user-')) {
      yield Profile(
        id: user.id,
        fullName: 'Customer (Mock)',
        email: user.email ?? '',
        phone: user.phone ?? user.userMetadata?['phone'],
        roles: [UserRole.customer],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      continue;
    }

    // 3. Resolve user profile across tables
    try {
      // Priority A: check profiles table (Staff / Admins / Sales)
      Map<String, dynamic>? profileRow = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // Fallback by email if ID hasn't synced
      if (profileRow == null && user.email != null) {
        profileRow = await supabase
            .from('profiles')
            .select()
            .ilike('email', user.email!)
            .maybeSingle();
      }

      if (profileRow != null) {
        final profile = Profile.fromJson(profileRow);

        if (!profile.isActive ||
            (profileRow['roles'] is List &&
                (profileRow['roles'] as List).contains('deactivated'))) {
          await _clearLocalSessions();
          await supabase.auth.signOut();
          yield null;
          return;
        }

        // Cache session details
        await _saveProfileSession(profile);
        yield profile;
        continue;
      }

      // Priority B: check customer_profiles table
      final custResponse = await supabase
          .from('customer_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (custResponse != null) {
        final custProfile = Profile(
          id: user.id,
          fullName: custResponse['full_name'] ?? 'Customer',
          email: custResponse['email'] ?? user.email ?? '',
          phone: custResponse['phone'] ?? user.phone,
          roles: [UserRole.customer],
          isActive: true,
          themePreference: custResponse['theme_preference'] ?? 'light',
          createdAt:
              DateTime.tryParse(custResponse['created_at']?.toString() ?? '') ??
                  DateTime.now(),
          updatedAt:
              DateTime.tryParse(custResponse['updated_at']?.toString() ?? '') ??
                  DateTime.now(),
        );
        yield custProfile;
        continue;
      }

      // Priority C: check technicians table
      Map<String, dynamic>? techResponse;
      if (user.email != null && user.email!.isNotEmpty) {
        techResponse = await supabase
            .from('technicians')
            .select()
            .or('id.eq.${user.id},email.eq.${user.email}')
            .maybeSingle();
      } else {
        techResponse = await supabase
            .from('technicians')
            .select()
            .eq('id', user.id)
            .maybeSingle();
      }

      if (techResponse != null) {
        final isTechActive = techResponse['is_active'] ?? true;
        if (!isTechActive) {
          await _clearLocalSessions();
          await supabase.auth.signOut();
          yield null;
          return;
        }

        final techProfile = Profile(
          id: user.id,
          fullName: techResponse['name'] ?? 'Technician',
          email: techResponse['email'] ?? user.email ?? '',
          phone: techResponse['phone'] ?? user.phone,
          roles: [UserRole.technician],
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _saveProfileSession(techProfile);
        yield techProfile;
        continue;
      }

      // If user exists in auth.users but has no role row anywhere yet, default to sales
      final defaultProfile = Profile(
        id: user.id,
        fullName: user.userMetadata?['full_name'] ??
            user.email?.split('@').first ??
            'Staff User',
        email: user.email ?? '',
        phone: user.phone,
        roles: [UserRole.sales],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      yield defaultProfile;
    } catch (e) {
      // Offline fallback using SharedPreferences cache
      final prefs = await SharedPreferences.getInstance();
      final cachedRolesStr = prefs.getString('cached_profile_roles_${user.id}');
      if (cachedRolesStr != null && cachedRolesStr.isNotEmpty) {
        final offlineRoles = cachedRolesStr
            .split(',')
            .map((r) => UserRole.fromString(r))
            .toList();
        yield Profile(
          id: user.id,
          fullName: prefs.getString('cached_profile_name_${user.id}') ?? 'User',
          email: user.email ?? '',
          phone: user.phone,
          roles: offlineRoles,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      } else {
        yield null;
      }
    }
  }
});

Future<void> _clearLocalSessions() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customer_session_uid');
    await prefs.remove('customer_session_phone');
    await prefs.remove('technician_session_id');
    await prefs.remove('technician_session_email');
    await prefs.remove('technician_session_name');
    await prefs.remove('staff_session_id');
    await prefs.remove('staff_session_email');
    await prefs.remove('staff_session_name');
    await prefs.remove('staff_session_role');
    await prefs.remove('staff_session_roles');
  } catch (_) {}
}

Future<void> _saveProfileSession(Profile profile) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('staff_session_id', profile.id);
    await prefs.setString('staff_session_email', profile.email);
    await prefs.setString('staff_session_name', profile.fullName);
    await prefs.setString('staff_session_role', profile.primaryRole.value);
    await prefs.setStringList(
        'staff_session_roles', profile.roles.map((r) => r.value).toList());
    await prefs.setString('cached_profile_id_${profile.id}', profile.id);
    await prefs.setString(
        'cached_profile_name_${profile.id}', profile.fullName);
    await prefs.setString('cached_profile_email_${profile.id}', profile.email);
    await prefs.setString('cached_profile_roles_${profile.id}',
        profile.roles.map((r) => r.value).join(','));
  } catch (_) {}
}

final currentProfileProvider = Provider<Profile?>((ref) {
  return ref.watch(authStateProvider).value;
});

// Auth controller
class AuthController extends StateNotifier<AsyncValue<void>> {
  final SupabaseClient _supabase;

  AuthController(this._supabase) : super(const AsyncValue.data(null));

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    final cleanEmail = email.trim();

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: password.trim(),
      );

      if (response.user == null) {
        throw Exception('Invalid email or password');
      }

      final authUser = response.user!;

      // Verify active status in profiles table
      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      if (profileResponse != null) {
        if (!(profileResponse['is_active'] as bool? ?? true)) {
          await _supabase.auth.signOut();
          throw Exception(
              'Your account has been deactivated. Please contact admin.');
        }
        final profile = Profile.fromJson(profileResponse);
        await _saveProfileSession(profile);
      }

      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _clearLocalSessions();
      await _supabase.auth.signOut();
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> updatePushToken(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase
          .from('profiles')
          .update({'push_token': token}).eq('id', user.id);
    } catch (_) {}
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthController(supabase);
});
