import 'package:flutter/foundation.dart';

import 'src/core/di/medusa_admin_di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'src/core/constants/strings.dart';
import 'src/core/di/medusa_v1_transformer.dart';
import 'src/multi_bloc_provider.dart';
import 'package:medusa_admin/src/features/app_settings/presentation/cubits/language/language_cubit.dart';
import 'package:medusa_admin/src/features/app_settings/presentation/cubits/theme/theme_cubit.dart';
import 'src/core/routing/app_router.dart';
import 'src/core/theme/flex_theme.dart';
import 'src/core/di/di.dart';
import 'src/core/localization/app_localizations.dart';
import 'src/observer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //* observe bloc logs
  Bloc.observer = MyBlocObserver();

  // //* initialize firebase
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  //* initialize firebase crashlytics
  // FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  // PlatformDispatcher.instance.onError = (error, stack) {
  //   FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  //   return true;
  // };

  //* initialize Supabase using stored credentials if available, else use defaults
  final secureStorage = const FlutterSecureStorage();
  final storedUrl = await secureStorage.read(key: AppConstants.supabaseUrlKey);
  final storedAnonKey = await secureStorage.read(key: AppConstants.supabaseAnonKey);

  final supabaseUrl = (storedUrl != null && storedUrl.isNotEmpty)
      ? storedUrl
      : AppConstants.defaultSupabaseUrl;
  final supabaseAnonKey = (storedAnonKey != null && storedAnonKey.isNotEmpty)
      ? storedAnonKey
      : AppConstants.defaultSupabaseAnonKey;

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (_) {
    // Already initialized — safe to ignore on hot restart.
  }

  //* inject dependencies
  await configureInjection();

  //* Patch the dart client's Dio with our V1 transformer.
  //* The dart client uses GetIt.instance and its Dio is registered by
  //* a static initializer BEFORE our configure call, meaning our
  //* interceptors passed to initialize() are ignored.
  //* We add the transformer directly here instead.
  try {
    final clientDio = GetIt.instance<Dio>();
    if (kIsWeb) {
      clientDio.options.extra['withCredentials'] = true;
    }
    final alreadyAdded =
        clientDio.interceptors.any((i) => i is MedusaV1ResponseTransformer);
    if (!alreadyAdded) {
      clientDio.interceptors.insert(0, MedusaV1ResponseTransformer());
    }
    final hasAuth =
        clientDio.interceptors.any((i) => i == MedusaAdminDi.authInterceptor);
    if (!hasAuth) {
      clientDio.interceptors.add(MedusaAdminDi.authInterceptor);
    }
  } catch (_) {
    // Dio not registered — safe to ignore.
  }

  runApp(const MedusaAdminApp());
}

class MedusaAdminApp extends StatelessWidget {
  const MedusaAdminApp({super.key});

  AppRouter get _router => getIt<AppRouter>();

  @override
  Widget build(BuildContext context) {
    return CustomMultiBlocProvider(
      child: BlocBuilder<LanguageCubit, LanguageState>(
        builder: (context, languageState) {
          return BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, themeState) {
              return MaterialApp.router(
                title: AppConstants.appName,
                locale: languageState.locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                debugShowCheckedModeBanner: false,
                themeMode: themeState.themeMode,
                theme: FlexTheme.light(
                    themeState.flexScheme, themeState.useMaterial3),
                darkTheme: FlexTheme.dark(
                    themeState.flexScheme, themeState.useMaterial3),
                builder: EasyLoading.init(),
                routerConfig: _router.config(),
              );
            },
          );
        },
      ),
    );
  }
}
