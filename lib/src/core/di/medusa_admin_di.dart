import 'package:medusa_admin/src/features/auth/presentation/bloc/authentication/authentication_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' as f;


import 'package:medusa_admin/src/core/constants/strings.dart';
import 'package:medusa_admin/src/core/utils/enums.dart';
import 'package:medusa_admin/src/features/auth/data/service/auth_preference_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'di.dart';

abstract class MedusaAdminDi {
  static final Interceptor loggerInterceptor = PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseBody: false,
      responseHeader: false,
      error: true,
      compact: true,
      maxWidth: 90);
  static final Interceptor authInterceptor = InterceptorsWrapper(
    onRequest: (options, handler) async {
      if (f.kIsWeb) {
        options.extra['withCredentials'] = true;
      }

      final authType = AuthPreferenceService.authTypeGetter;
      final secureStorage = getIt<FlutterSecureStorage>();
      try {
        // Universal Bearer JWT injection: If a JWT is present, attach Bearer header
        final String? jwt = await secureStorage.read(key: AppConstants.jwtKey);
        if (jwt != null && jwt.isNotEmpty && options.headers['Authorization'] == null) {
          options.headers['Authorization'] = 'Bearer $jwt';
        }

        switch (authType) {
          case AuthenticationType.cookie:
            final String? token = await secureStorage.read(key: AppConstants.tokenKey);
            if (token != null && token.isNotEmpty && options.headers['x-medusa-access-token'] == null) {
              options.headers['x-medusa-access-token'] = token;
            }

            if (f.kIsWeb) break;

            if (options.headers['Cookie'] != null) {
              break;
            }
            final String? cookie =
                await secureStorage.read(key: AppConstants.cookieKey);
            if (cookie?.isNotEmpty ?? false) {
              options.headers['Cookie'] = cookie;
            }
            break;

          case AuthenticationType.token:
            final token = await secureStorage.read(key: AppConstants.tokenKey);
            if (token != null && options.headers['x-medusa-access-token'] == null) {
              options.headers['x-medusa-access-token'] = token;
            }
            break;
          case AuthenticationType.supabase:
            final token = await secureStorage.read(key: AppConstants.supabaseTokenKey);
            if (token != null) {
              options.headers['sb-access-token'] = token;
            }
            // Retain Authorization header for Medusa V1 and custom admin endpoints
            if (jwt?.isNotEmpty ?? false) {
              options.headers['Authorization'] = 'Bearer $jwt';
            }
            break;

          case AuthenticationType.jwt:
            if (options.headers['Authorization'] != null) {
              break;
            }
            if (jwt?.isNotEmpty ?? false) {
              options.headers['Authorization'] = 'Bearer $jwt';
            }
            break;
        }
      } catch (_) {}
      handler.next(options);
    },
    onError: (DioException e, handler) async {
      // Do not aggressively log out on sub-endpoint 401s; only let user retry or auth check handle it
      if (e.response?.statusCode == 401 && e.requestOptions.path.endsWith('/auth')) {
        try {
          AuthenticationBloc.instance.add(const AuthenticationEvent.logOut());
        } catch (_) {}
      }
      handler.next(e);
    },
  );

  // static final Interceptor contentTypeInterceptor = InterceptorsWrapper(
  //   onRequest: (
  //       RequestOptions options,
  //       RequestInterceptorHandler handler,
  //       ) {
  //     if (options.contentType == null) {
  //       final dynamic data = options.data;
  //       final String? contentType;
  //       if (data is FormData) {
  //         contentType = Headers.multipartFormDataContentType;
  //       } else if (data is Map) {
  //         contentType = Headers.formUrlEncodedContentType;
  //       } else if (data is String) {
  //         contentType = Headers.jsonContentType;
  //       } else if (data != null) {
  //         contentType = Headers.textPlainContentType; // Can be removed if unnecessary.
  //       } else {
  //         contentType = null;
  //       }
  //       options.contentType = contentType;
  //     }
  //     handler.next(options);
  //   },
  // );
// static Future<void> registerMedusaAdminSingleton() async {
//   if (!getIt.isRegistered<MedusaAdminV2>()) {
//     getIt.registerLazySingleton<MedusaAdminV2>(
//       () => MedusaAdminV2.initialize(
//         baseUrl: AuthPreferenceService.baseUrlGetter!,
//         interceptors: [authInterceptor, loggerInterceptor],
//       ),
//     );
//   }
// }
//
// static Future<void> resetMedusaAdminSingleton() async {
//   await getIt.resetLazySingleton<MedusaAdminV2>();
// }
}
