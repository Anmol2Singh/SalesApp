// lib/features/auth/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/notification_service.dart';

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
  const supabaseUrl = AppConfig.supabaseUrl;
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
    final customerUid = prefs.getString('customer_session_uid');

    if (customerUid != null && customerUid.isNotEmpty) {
      final customerPhone = prefs.getString('customer_session_phone') ?? '';
      final customerName = prefs.getString('customer_session_name') ?? 'Customer';
      yield Profile(
        id: customerUid,
        fullName: customerName,
        email: '',
        phone: customerPhone,
        roles: [UserRole.customer],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } else if (staffId != null && staffId.isNotEmpty) {
      final staffRoleStr = prefs.getString('staff_session_role') ?? 'technician';
      final staffRolesList = prefs.getStringList('staff_session_roles');
      final staffEmail = prefs.getString('staff_session_email') ?? '';
      final staffName = prefs.getString('staff_session_name') ?? 'Staff';

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
      final customerUid = prefs.getString('customer_session_uid');

      if (customerUid != null && customerUid.isNotEmpty) {
        final customerPhone = prefs.getString('customer_session_phone') ?? '';
        final customerName = prefs.getString('customer_session_name') ?? 'Customer';
        yield Profile(
          id: customerUid,
          fullName: customerName,
          email: '',
          phone: customerPhone,
          roles: [UserRole.customer],
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      } else if (staffId == null || staffId.isEmpty) {
        yield null;
      }
      continue;
    }

    // Handle Mock User
    if (user.id.startsWith('mock-user-')) {
      final mockProfile = Profile(
        id: user.id,
        fullName: 'Customer (Mock)',
        email: user.email ?? '',
        phone: user.phone ?? user.userMetadata?['phone'],
        roles: [UserRole.customer],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _saveProfileSession(mockProfile);
      yield mockProfile;
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
        await _saveProfileSession(custProfile);
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
    if (profile.primaryRole == UserRole.customer || profile.roles.contains(UserRole.customer)) {
      await prefs.setString('customer_session_uid', profile.id);
      await prefs.setString('customer_session_phone', profile.phone ?? '');
      await prefs.setString('customer_session_name', profile.fullName);
    } else {
      await prefs.setString('staff_session_id', profile.id);
      await prefs.setString('staff_session_email', profile.email);
      await prefs.setString('staff_session_name', profile.fullName);
      await prefs.setString('staff_session_role', profile.primaryRole.value);
      await prefs.setStringList(
          'staff_session_roles', profile.roles.map((r) => r.value).toList());
    }
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
    final cleanEmail = email.trim().toLowerCase();

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
      // Staff / Manager account fallback: if profile exists in profiles table and is active,
      // sync/link with GoTrue and retry sign in.
      try {
        final profileCheck = await _supabase
            .from('profiles')
            .select()
            .ilike('email', cleanEmail)
            .maybeSingle();

        if (profileCheck != null && (profileCheck['is_active'] as bool? ?? true)) {
          final tempClient = SupabaseClient(
            AppConfig.supabaseUrl,
            AppConfig.supabaseAnonKey,
            authOptions: const FlutterAuthClientOptions(
              authFlowType: AuthFlowType.implicit,
            ),
          );
          try {
            await tempClient.auth.signUp(
              email: cleanEmail,
              password: password.trim(),
              data: {
                'full_name': profileCheck['full_name'],
                'role': profileCheck['role'] ?? 'sales',
              },
            );
          } catch (_) {}

          final retryResponse = await _supabase.auth.signInWithPassword(
            email: cleanEmail,
            password: password.trim(),
          );

          if (retryResponse.user != null) {
            final authUser = retryResponse.user!;
            if (profileCheck['id'] != authUser.id) {
              try {
                await _supabase.from('profiles').update({'id': authUser.id}).eq('id', profileCheck['id']);
              } catch (_) {}
            }
            final profile = Profile.fromJson(profileCheck);
            await _saveProfileSession(profile);
            state = const AsyncValue.data(null);
            return;
          }
        }
      } catch (_) {}
      // Technician auto-sync fallback: if user exists in technicians table with matching password,
      // create/sync their Auth account on the fly and retry sign in.
      try {
        final techList = await _supabase
            .from('technicians')
            .select()
            .ilike('email', cleanEmail)
            .limit(1);

        if (techList.isNotEmpty) {
          final tech = techList.first;
          final techPass = tech['password']?.toString() ?? '';
          if (techPass.isNotEmpty && techPass == password.trim()) {
            await _supabase.rpc('create_new_user', params: {
              'email': cleanEmail,
              'password': password.trim(),
              'full_name': tech['name'] ?? 'Technician',
              'new_role': 'technician',
            });

            final retryResponse = await _supabase.auth.signInWithPassword(
              email: cleanEmail,
              password: password.trim(),
            );

            if (retryResponse.user != null) {
              final authUser = retryResponse.user!;
              final oldTechId = tech['id']?.toString() ?? '';

              // Sync technicians table ID with auth UID to guarantee singular matching account
              if (oldTechId.isNotEmpty && oldTechId != authUser.id) {
                try {
                  await _supabase.from('technicians').update({'id': authUser.id}).eq('id', oldTechId);
                  await _supabase.from('complaints').update({'technician_id': authUser.id}).eq('technician_id', oldTechId);
                  await _supabase.from('installations').update({'technician_id': authUser.id}).eq('technician_id', oldTechId);
                } catch (_) {}
              }
              if (tech['phone'] != null && tech['phone'].toString().trim().isNotEmpty) {
                try {
                  await _supabase.from('profiles').update({'phone': tech['phone'].toString().trim()}).eq('id', authUser.id);
                } catch (_) {}
              }

              final techProfile = Profile(
                id: authUser.id,
                fullName: tech['name'] ?? 'Technician',
                email: cleanEmail,
                phone: tech['phone']?.toString(),
                roles: [UserRole.technician],
                isActive: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await _saveProfileSession(techProfile);
              state = const AsyncValue.data(null);
              return;
            }
          }
        }
      } catch (_) {}

      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await NotificationService.unregisterDeviceToken(_supabase);
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
