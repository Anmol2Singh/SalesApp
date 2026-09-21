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

  // If using placeholder credentials, automatically authenticate as a mock Admin to prevent being stuck on splash screen
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

  // Check saved staff/technician or customer session on startup
  try {
    final prefs = await SharedPreferences.getInstance();
    final staffId = prefs.getString('staff_session_id') ?? prefs.getString('technician_session_id');
    final staffRoleStr = prefs.getString('staff_session_role') ?? 'technician';
    final staffRolesList = prefs.getStringList('staff_session_roles');
    final staffEmail = prefs.getString('staff_session_email') ?? prefs.getString('technician_session_email') ?? '';
    final staffName = prefs.getString('staff_session_name') ?? prefs.getString('technician_session_name') ?? 'Staff';

    if (staffId != null && staffId.isNotEmpty && supabase.auth.currentUser == null) {
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

    final savedCustUid = prefs.getString('customer_session_uid');
    final savedCustPhone = prefs.getString('customer_session_phone');
    if (savedCustUid != null && savedCustUid.isNotEmpty && supabase.auth.currentUser == null && staffId == null) {
      String custName = 'Customer';
      final cleanDigits = (savedCustPhone ?? '').replaceAll(RegExp(r'\D'), '');
      if (cleanDigits.isNotEmpty) {
        try {
          final dbCust = await supabase
              .from('customers')
              .select('customer_name, contact_person')
              .or('phone.eq.$savedCustPhone,phone.ilike.%$cleanDigits')
              .limit(1)
              .maybeSingle();
          if (dbCust != null) {
            custName = dbCust['customer_name'] ?? dbCust['contact_person'] ?? custName;
          }
        } catch (_) {}
      }
      yield Profile(
        id: savedCustUid,
        fullName: custName,
        email: '',
        phone: savedCustPhone,
        roles: [UserRole.customer],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    final currentUser = supabase.auth.currentUser;
    if (currentUser != null && staffId == null && savedCustUid == null) {
      final cachedName = prefs.getString('cached_profile_name_${currentUser.id}');
      final cachedRolesStr = prefs.getString('cached_profile_roles_${currentUser.id}');
      if (cachedRolesStr != null && cachedRolesStr.isNotEmpty) {
        final roles = cachedRolesStr.split(',').map((r) => UserRole.fromString(r)).toList();
        yield Profile(
          id: currentUser.id,
          fullName: cachedName ?? currentUser.userMetadata?['full_name'] ?? 'User',
          email: currentUser.email ?? '',
          phone: currentUser.phone ?? currentUser.userMetadata?['phone'],
          roles: roles.isNotEmpty ? roles : [UserRole.sales],
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    }
  } catch (_) {}

  final authStream = supabase.auth.onAuthStateChange.handleError((error, stack) {
    // Silently ignore offline network/DNS errors during stream listening
  });

  await for (final authChange in authStream) {
    final user = authChange.session?.user;
    if (user == null) {
      final prefs = await SharedPreferences.getInstance();
      final staffId = prefs.getString('staff_session_id') ?? prefs.getString('technician_session_id');
      final staffRoleStr = prefs.getString('staff_session_role') ?? 'technician';
      final staffRolesList = prefs.getStringList('staff_session_roles');
      final staffEmail = prefs.getString('staff_session_email') ?? prefs.getString('technician_session_email') ?? '';
      final staffName = prefs.getString('staff_session_name') ?? prefs.getString('technician_session_name') ?? 'Staff';

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
        continue;
      }

      final savedCustUid = prefs.getString('customer_session_uid');
      final savedCustPhone = prefs.getString('customer_session_phone');
      if (savedCustUid != null && savedCustUid.isNotEmpty) {
        String custName = 'Customer';
        final cleanDigits = (savedCustPhone ?? '').replaceAll(RegExp(r'\D'), '');
        if (cleanDigits.isNotEmpty) {
          try {
            final dbCust = await supabase
                .from('customers')
                .select('customer_name, contact_person')
                .or('phone.eq.$savedCustPhone,phone.ilike.%$cleanDigits')
                .limit(1)
                .maybeSingle();
            if (dbCust != null) {
              custName = dbCust['customer_name'] ?? dbCust['contact_person'] ?? custName;
            }
          } catch (_) {}
        }
        yield Profile(
          id: savedCustUid,
          fullName: custName,
          email: '',
          phone: savedCustPhone,
          roles: [UserRole.customer],
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      } else {
        yield null;
      }
      continue;
    }

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

    try {
      final response = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      
      if (response != null) {
        var profile = Profile.fromJson(response);
        if (!profile.isActive || (response['roles'] is List && (response['roles'] as List).contains('deactivated'))) {
          // Deactivated user: Auto log out!
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('user_account_deleted_kicked', true);
            await prefs.remove('cached_profile_id_${user.id}');
            await prefs.remove('cached_profile_name_${user.id}');
            await prefs.remove('cached_profile_email_${user.id}');
            await prefs.remove('cached_profile_roles_${user.id}');
            await prefs.remove('staff_session_id');
            await prefs.remove('staff_session_email');
            await prefs.remove('staff_session_name');
            await prefs.remove('staff_session_role');
            await prefs.remove('staff_session_roles');
            await supabase.auth.signOut();
          } catch (_) {}
          yield null;
          return;
        }

        // Cache user profile for offline session resilience
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_profile_id_${user.id}', profile.id);
          await prefs.setString('cached_profile_name_${user.id}', profile.fullName);
          await prefs.setString('cached_profile_email_${user.id}', profile.email);
          await prefs.setString('cached_profile_roles_${user.id}', profile.roles.map((r) => r.value).join(','));
        } catch (_) {}
        yield profile;
      } else {
        // Try customer_profiles table first
        final custResponse = await supabase
            .from('customer_profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (custResponse != null) {
          String displayName = custResponse['full_name'] ?? 'Customer';
          final prefs = await SharedPreferences.getInstance();
          final savedCustPhone = custResponse['phone'] ?? user.phone ?? user.userMetadata?['phone'] ?? prefs.getString('customer_session_phone');
          if (savedCustPhone != null && savedCustPhone.toString().isNotEmpty) {
            final cleanDigits = savedCustPhone.toString().replaceAll(RegExp(r'\D'), '');
            if (cleanDigits.isNotEmpty) {
              try {
                final last10 = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
                final dbCust = await supabase
                    .from('customers')
                    .select('customer_name, contact_person')
                    .or('phone.eq.$savedCustPhone,phone.eq.$cleanDigits,phone.ilike.%$last10')
                    .limit(1)
                    .maybeSingle();
                if (dbCust != null) {
                  final custName = dbCust['customer_name'] ?? dbCust['contact_person'];
                  if (custName != null && custName.toString().isNotEmpty) {
                    displayName = custName.toString();
                  }
                }
              } catch (_) {}
            }
          }

          yield Profile(
            id: user.id,
            fullName: displayName,
            email: custResponse['email'] ?? user.email ?? '',
            phone: custResponse['phone'] ?? user.phone,
            roles: [UserRole.customer],
            isActive: true,
            themePreference: custResponse['theme_preference'] ?? 'light',
            createdAt: custResponse['created_at'] != null ? DateTime.tryParse(custResponse['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
            updatedAt: custResponse['updated_at'] != null ? DateTime.tryParse(custResponse['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
          );
          continue;
        }

        // Try technicians table
        final techQuery = supabase.from('technicians').select();
        final techResponse = user.email != null && user.email!.isNotEmpty
            ? await techQuery.or('id.eq.${user.id},email.eq.${user.email}').maybeSingle()
            : await techQuery.eq('id', user.id).maybeSingle();
        if (techResponse != null) {
          final isTechActive = techResponse['is_active'] ?? true;
          if (!isTechActive) {
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('user_account_deleted_kicked', true);
              await prefs.remove('technician_session_id');
              await prefs.remove('technician_session_email');
              await prefs.remove('technician_session_name');
              await supabase.auth.signOut();
            } catch (_) {}
            yield null;
            return;
          }

          yield Profile(
            id: user.id,
            fullName: techResponse['name'] ?? 'Technician',
            email: techResponse['email'] ?? user.email ?? '',
            phone: techResponse['phone'] ?? user.phone,
            roles: [UserRole.technician],
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        } else {
          // User was deleted from profiles, customer_profiles, and technicians (DELETED USER!)
          // Cleanly auto-logout session immediately and never convert to a customer!
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('user_account_deleted_kicked', true);
            await prefs.remove('cached_profile_id_${user.id}');
            await prefs.remove('cached_profile_name_${user.id}');
            await prefs.remove('cached_profile_email_${user.id}');
            await prefs.remove('cached_profile_roles_${user.id}');
            await prefs.remove('staff_session_id');
            await prefs.remove('staff_session_email');
            await prefs.remove('staff_session_name');
            await prefs.remove('staff_session_role');
            await prefs.remove('customer_session_uid');
            await prefs.remove('customer_session_phone');
            await prefs.remove('technician_session_id');
            await prefs.remove('technician_session_email');
            await prefs.remove('technician_session_name');
            await supabase.auth.signOut();
          } catch (_) {}
          yield null;
          return;
        }
      }
    } catch (e) {
      // Offline fallback: only restore if a cached profile actually exists
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedRolesStr = prefs.getString('cached_profile_roles_${user.id}');
        if (cachedRolesStr != null && cachedRolesStr.isNotEmpty) {
          final offlineRoles = cachedRolesStr.split(',').map((r) => UserRole.fromString(r)).toList();
          final cachedName = prefs.getString('cached_profile_name_${user.id}') ?? (user.userMetadata?['full_name'] ?? 'User');
          yield Profile(
            id: user.id,
            fullName: cachedName,
            email: user.email ?? '',
            phone: user.phone ?? user.userMetadata?['phone'],
            roles: offlineRoles,
            isActive: true,
            themePreference: 'system',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          continue;
        }
      } catch (_) {}

      yield null;
    }
  }
});

// Current user profile (non-stream, for sync access)
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
    final cleanEmail = email.trim().toLowerCase();
    try {
      final prefs = await SharedPreferences.getInstance();

      // Support company email aliases (@insiya.com <-> @izyheat.com)
      final username = cleanEmail.contains('@') ? cleanEmail.split('@').first : cleanEmail;
      final izyheatEmail = cleanEmail.endsWith('@izyheat.com')
          ? cleanEmail
          : '$username@izyheat.com';
      final insiyaEmail = cleanEmail.endsWith('@insiya.com')
          ? cleanEmail
          : '$username@insiya.com';
      final candidateEmails = <String>{cleanEmail, izyheatEmail, insiyaEmail}.toList();

      AuthResponse? response;
      Object? lastAuthErr;

      for (final candidate in candidateEmails) {
        try {
          response = await _supabase.auth.signInWithPassword(
            email: candidate,
            password: password,
          );
          if (response.user != null) break;
        } catch (e) {
          lastAuthErr = e;
        }
      }

      if (response?.user != null) {
        // Clear any customer session
        await prefs.remove('customer_session_uid');
        await prefs.remove('customer_session_phone');

        // Check if user exists and is active
        final profileResponse = await _supabase
            .from('profiles')
            .select('is_active')
            .eq('id', response!.user!.id)
            .maybeSingle();

        final custResponse = profileResponse == null
            ? await _supabase
                .from('customer_profiles')
                .select('id')
                .eq('id', response.user!.id)
                .maybeSingle()
            : null;

        final techResponse = (profileResponse == null && custResponse == null)
            ? await _supabase
                .from('technicians')
                .select('is_active')
                .eq('id', response.user!.id)
                .maybeSingle()
            : null;

        if (profileResponse == null && custResponse == null && techResponse == null) {
          await _supabase.auth.signOut();
          throw Exception('User not found. This account does not exist or has been deleted.');
        }

        if (profileResponse != null && !(profileResponse['is_active'] as bool? ?? true)) {
          await _supabase.auth.signOut();
          throw Exception('Your account has been deactivated. Please contact admin.');
        }

        if (techResponse != null && !(techResponse['is_active'] as bool? ?? true)) {
          await _supabase.auth.signOut();
          throw Exception('Your account has been deactivated. Please contact admin.');
        }

        state = const AsyncValue.data(null);
        return;
      }

      // Fallback for office staff/technician login when user account exists in profiles or technicians table
      try {
        Map<String, dynamic>? profileRow;

        for (final candidate in candidateEmails) {
          try {
            profileRow = await _supabase
                .from('profiles')
                .select()
                .ilike('email', candidate)
                .maybeSingle();
            if (profileRow != null) break;
          } catch (_) {}
        }

        // If not matched by exact candidate, check if username prefix matches
        if (profileRow == null && username.isNotEmpty) {
          try {
            final matches = await _supabase
                .from('profiles')
                .select()
                .ilike('email', '$username@%')
                .limit(1);
            if ((matches as List).isNotEmpty) {
              profileRow = matches.first;
            }
          } catch (_) {}
        }

        if (profileRow != null) {
          if (!(profileRow['is_active'] as bool? ?? true)) {
            throw Exception('Your account has been deactivated. Please contact admin.');
          }
          final rolesData = profileRow['roles'];
          List<String> roleStrings = [];
          if (rolesData is List) {
            roleStrings = rolesData.map((e) => e.toString()).toList();
          } else if (profileRow['role'] != null) {
            roleStrings = [profileRow['role'].toString()];
          }
          if (roleStrings.isEmpty) roleStrings = ['admin'];
          final roles = roleStrings.map((r) => UserRole.fromString(r)).toList();

          await prefs.remove('customer_session_uid');
          await prefs.remove('customer_session_phone');

          await prefs.setString('staff_session_id', profileRow['id'] as String);
          await prefs.setString('staff_session_email', profileRow['email'] as String? ?? cleanEmail);
          await prefs.setString('staff_session_name', (profileRow['full_name'] as String?) ?? 'Staff Member');
          await prefs.setString('staff_session_role', roles.first.value);
          await prefs.setStringList('staff_session_roles', roles.map((r) => r.value).toList());

          state = const AsyncValue.data(null);
          return;
        }
      } catch (e) {
        if (e.toString().contains('deactivated')) rethrow;
      }

      try {
        Map<String, dynamic>? techRow;

        for (final candidate in candidateEmails) {
          try {
            techRow = await _supabase
                .from('technicians')
                .select()
                .ilike('email', candidate)
                .maybeSingle();
            if (techRow != null) break;
          } catch (_) {}
        }

        if (techRow == null && username.isNotEmpty) {
          try {
            final matches = await _supabase
                .from('technicians')
                .select()
                .ilike('email', '$username@%')
                .limit(1);
            if ((matches as List).isNotEmpty) {
              techRow = matches.first;
            }
          } catch (_) {}
        }

        if (techRow != null) {
          final techId = techRow['id']?.toString() ?? 'tech-${DateTime.now().millisecondsSinceEpoch}';

          await prefs.remove('customer_session_uid');
          await prefs.remove('customer_session_phone');

          await prefs.setString('staff_session_id', techId);
          await prefs.setString('staff_session_email', techRow['email'] as String? ?? cleanEmail);
          await prefs.setString('staff_session_name', (techRow['name'] as String?) ?? 'Technician');
          await prefs.setString('staff_session_role', UserRole.technician.value);

          // Also keep technician_session_* for backwards compatibility
          await prefs.setString('technician_session_id', techId);
          await prefs.setString('technician_session_email', techRow['email'] as String? ?? cleanEmail);
          await prefs.setString('technician_session_name', (techRow['name'] as String?) ?? 'Technician');

          state = const AsyncValue.data(null);
          return;
        }
      } catch (_) {}

      if (lastAuthErr != null) {
        throw lastAuthErr;
      } else {
        throw Exception('Invalid login credentials');
      }
    } catch (e) {
      _supabase.auth.signOut();
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
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
    } catch (e) {
      // Push token update is non-critical, don't throw
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthController(supabase);
});
