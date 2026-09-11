import 'package:medusa_admin/src/core/services/app_scope_service.dart';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:medusa_admin/src/core/constants/strings.dart';
import 'package:medusa_admin/src/core/di/di.dart';
import 'package:medusa_admin/src/core/error/medusa_error.dart';
import 'package:medusa_admin/src/core/utils/enums.dart';
import 'package:medusa_admin/src/features/auth/data/service/auth_preference_service.dart';
import 'package:medusa_admin/src/core/di/medusa_v1_client.dart';
import 'package:medusa_admin_dart_client/medusa_admin_dart_client_v2.dart';
import 'package:medusa_js_dart/medusa_js_dart.dart'
    hide User, Error, AuthenticationType, AdminAuthRes;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;





import 'package:multiple_result/multiple_result.dart';


@lazySingleton
class AuthenticationUseCase {

  AuthenticationUseCase(this._medusaAdminV2, this._medusav1, this._securePrefs);



  static AuthenticationUseCase get instance => getIt<AuthenticationUseCase>();

  AuthRepository get _authenticationRepository => _medusaAdminV2.auth;

  UsersRepository get _usersRepository => _medusaAdminV2.users;
  final MedusaAdminV2 _medusaAdminV2;
  final InterceptedMedusa _medusav1;
  final FlutterSecureStorage _securePrefs;
  User? _lastAuthenticatedUser;





  Future<Result<String, MedusaError>> login(
      {required String email, required String password}) async {
    final medusaApiVersion = AuthPreferenceService.medusaApiVersionGetter;
    try {
      if (medusaApiVersion == MedusaApiVersion.v1) {
        final authType = AuthPreferenceService.authTypeGetter;
        if (authType == AuthenticationType.supabase) {
          log('Starting Supabase login for $email');
          final response = await sb.Supabase.instance.client.auth
              .signInWithPassword(email: email, password: password);
          if (response.session != null) {
            final token = response.session!.accessToken;
            await _securePrefs.write(key: AppConstants.supabaseTokenKey, value: token);
            _medusav1.setApiKey(token);
            return Success(token);
          }
          return Error(MedusaError(code: 'auth_error', type: 'Auth Error', message: 'Supabase login failed'));
        }


        log('Starting V1 login for $email');
        String? jwtToken;
        // 1. Try to fetch JWT token via /admin/auth/token (standard Medusa V1 Bearer JWT)
        try {
          final tokenRes = await _medusav1.dio.post(
            '/admin/auth/token',
            data: {'email': email, 'password': password},
          );
          if (tokenRes.data is Map && tokenRes.data['access_token'] != null) {
            jwtToken = tokenRes.data['access_token'] as String;
            log('V1 JWT token retrieved: ${jwtToken.substring(0, 10)}...');
            await _securePrefs.write(key: AppConstants.jwtKey, value: jwtToken);
            _medusav1.dio.options.headers['Authorization'] = 'Bearer $jwtToken';
          }
        } catch (e) {
          log('V1 /admin/auth/token error or not supported: $e');
        }

        // 2. Also attempt createSession (sets session cookie and returns user object)
        try {
          final authRes = await _medusav1.admin.auth
              .createSession(AdminPostAuthReq(email, password))
              .timeout(const Duration(seconds: 30));
          final u = authRes.user;
          _lastAuthenticatedUser = User(
            id: u.id,
            email: u.email,
            firstName: u.firstName,
            lastName: u.lastName,
          );
          final userMeta = Map<String, dynamic>.from(u.metadata ?? {});
          await AppScopeService.setUserMetadata(
            userMeta,
            u.role.name,
          );
          try {
            final authMe = await _medusav1.dio.get('/admin/auth');
            if (authMe.data is Map && authMe.data['user'] is Map) {
              final raw = authMe.data['user'] as Map<String, dynamic>;
              final meta = Map<String, dynamic>.from(raw['metadata'] ?? {});
              if (raw['store_id'] != null && !meta.containsKey('store_id')) {
                meta['store_id'] = raw['store_id'];
              }
              await AppScopeService.setUserMetadata(
                meta,
                raw['role']?.toString(),
              );
            }
          } catch (_) {}
        } catch (e) {
          log('V1 createSession error: $e');
          if (jwtToken == null) {
            if (e is DioException) {
              return Error(MedusaError.fromHttp(
                status: e.response?.statusCode,
                body: e.response?.data,
                cause: e,
              ));
            }
            rethrow;
          }
        }

        final token = _medusav1.getCookieToken();
        log('V1 cookie token retrieved: ${token != null ? 'YES' : 'NO'}');
        if (token != null) {
          await _securePrefs.write(key: AppConstants.cookieKey, value: 'connect.sid=$token');
        }

        if (jwtToken != null) {
          return Success(jwtToken);
        } else if (token != null) {
          return Success('connect.sid=$token');
        }
        return const Success('');
      }

      final user = await _authenticationRepository
          .authProvider('emailpass', {'email': email, 'password': password});


      if (user is Map<String, dynamic>) {
        return Success(user['token'] as String);
      }
      return Error(MedusaError(
            code: 'invalid_response',
            type: 'Invalid Response',
            message: 'The response from the server was not as expected.'));
    } on DioException catch (e) {
      return Error(MedusaError.fromHttp(
        status: e.response?.statusCode,
        body: e.response?.data,
        cause: e,
      ));
    } catch (error, stack) {
      log(error.toString());
      log(stack.toString());
      return Error(MedusaError(
          code: 'unknown', type: 'unknown', message: error.toString()));
    }
  }

  Future<Result<DeleteSessionRes, MedusaError>> logout() async {
    final medusaApiVersion = AuthPreferenceService.medusaApiVersionGetter;
    try {
      _lastAuthenticatedUser = null;
      await _securePrefs.delete(key: AppConstants.jwtKey);
      await _securePrefs.delete(key: AppConstants.cookieKey);
      await _securePrefs.delete(key: AppConstants.tokenKey);
      await _securePrefs.delete(key: AppConstants.supabaseTokenKey);
      _medusav1.dio.options.headers.remove('Authorization');
      _medusav1.setCookieToken('');
      _medusav1.setApiKey('');

      if (medusaApiVersion == MedusaApiVersion.v1) {
        final authType = AuthPreferenceService.authTypeGetter;
        if (authType == AuthenticationType.supabase) {
           await sb.Supabase.instance.client.auth.signOut();
           return const Success(DeleteSessionRes(success: true));
        }
        try {
          await _medusav1.admin.auth.deleteSession();
        } catch (_) {}
        return const Success(DeleteSessionRes(success: true));
      }

      final result = await _authenticationRepository.logout();
      return Success(result);

    } on DioException catch (e) {
      return Error(MedusaError.fromHttp(
        status: e.response?.statusCode,
        body: e.response?.data,
        cause: e,
      ));
    } catch (error, stack) {
      log(error.toString());
      log(stack.toString());
      return Error(MedusaError(
          code: 'unknown', type: 'unknown', message: error.toString()));
    }
  }

  Future<Result<SessionUser, MedusaError>> postSession(String token) async {
    try {
      final result =
          await _authenticationRepository.postSession('Bearer $token');
      return Success(result.user);
    } on DioException catch (e) {
      return Error(MedusaError.fromHttp(
        status: e.response?.statusCode,
        body: e.response?.data,
        cause: e,
      ));
    } catch (error, stack) {
      log(error.toString());
      log(stack.toString());
      return Error(MedusaError(
          code: 'unknown', type: 'unknown', message: error.toString()));
    }
  }

  Future<Result<User, MedusaError>> getCurrentUser({String? fields}) async {
    final medusaApiVersion = AuthPreferenceService.medusaApiVersionGetter;
    try {
      if (medusaApiVersion == MedusaApiVersion.v1) {
        final authType = AuthPreferenceService.authTypeGetter;

        final jwt = await _securePrefs.read(key: AppConstants.jwtKey);
        if (jwt != null && jwt.isNotEmpty) {
          _medusav1.dio.options.headers['Authorization'] = 'Bearer $jwt';
        }

        if (authType == AuthenticationType.cookie &&
            _medusav1.getCookieToken() == null) {
          final cookie = await _securePrefs.read(key: AppConstants.cookieKey);
          if (cookie != null) {
            final token = cookie.split('=').last;
            _medusav1.setCookieToken(token);
          }
        } else if (authType == AuthenticationType.token &&
            _medusav1.getApiKey() == null) {
          final token = await _securePrefs.read(key: AppConstants.tokenKey);
          if (token != null) {
            _medusav1.setApiKey(token);
          }
        } else if (authType == AuthenticationType.supabase &&
            _medusav1.getApiKey() == null) {
          final token = await _securePrefs.read(key: AppConstants.supabaseTokenKey);
          if (token != null) {
            _medusav1.setApiKey(token);
          }
        }

        try {
          final result = await _medusav1.admin.auth.getSession();
          final u = result.user;
          final user = User(
            id: u.id,
            email: u.email,
            firstName: u.firstName,
            lastName: u.lastName,
          );
          _lastAuthenticatedUser = user;
          final userMeta = Map<String, dynamic>.from(u.metadata ?? {});
          await AppScopeService.setUserMetadata(
            userMeta,
            u.role.name,
          );
          try {
            final authMe = await _medusav1.dio.get('/admin/auth');
            if (authMe.data is Map && authMe.data['user'] is Map) {
              final raw = authMe.data['user'] as Map<String, dynamic>;
              final meta = Map<String, dynamic>.from(raw['metadata'] ?? {});
              if (raw['store_id'] != null && !meta.containsKey('store_id')) {
                meta['store_id'] = raw['store_id'];
              }
              await AppScopeService.setUserMetadata(
                meta,
                raw['role']?.toString(),
              );
            }
          } catch (_) {
            try {
              final authMe = await _medusav1.dio.get('/admin/auth');
              if (authMe.data is Map && authMe.data['user'] is Map) {
                final raw = authMe.data['user'] as Map<String, dynamic>;
                if (raw['metadata'] is Map) {
                  await AppScopeService.setUserMetadata(
                    Map<String, dynamic>.from(raw['metadata']),
                    raw['role']?.toString(),
                  );
                }
              }
            } catch (_) {}
          }
          return Success(user);
        } catch (e) {
          log('getSession failed: $e');
          if (_lastAuthenticatedUser != null) {
            log('Using cached _lastAuthenticatedUser');
            return Success(_lastAuthenticatedUser!);
          }
          rethrow;
        }
      }




      final result = await _usersRepository.retrieveMe(fields: fields);
      return Success(result.user);

    } on DioException catch (e) {
      return Error(MedusaError.fromHttp(
        status: e.response?.statusCode,
        body: e.response?.data,
        cause: e,
      ));
    } catch (error, stack) {
      log(error.toString());
      log(stack.toString());
      return Error(MedusaError(
          code: 'unknown', type: 'unknown', message: error.toString()));
    }
  }
}
