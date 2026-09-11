import 'package:dio/dio.dart';
import 'package:medusa_js_dart/medusa_js_dart.dart';
import 'package:medusa_js_dart/src/clients/admin/admin.dart' as admin_client;
import 'package:medusa_js_dart/src/clients/store/store.dart' as store_client;

/// A wrapper around [Medusa] that injects a shared [Dio] instance.
///
/// We do NOT extend [Medusa] because its constructor calls `_createClients`
/// which assigns `late final` fields — re-assigning them in a subclass
/// constructor causes a [LateInitializationError].
class InterceptedMedusa {
  InterceptedMedusa(this.configuration, this.dio)
      : admin = admin_client.Admin(dio),
        store = store_client.Store(dio);

  Configuration configuration;
  final Dio dio;

  final admin_client.Admin admin;
  final store_client.Store store;

  /// Forwards to [configuration.copyWith] for API compatibility.
  void setApiKey(String apiKey) {
    configuration = configuration.copyWith(
      authenticationType: AuthenticationType.apiKey,
      apiKey: apiKey,
    );
  }

  void setCookieToken(String cookieToken) {
    configuration = configuration.copyWith(
      authenticationType: AuthenticationType.cookie,
      cookieToken: cookieToken,
    );
  }

  String? getApiKey() => configuration.apiKey;

  String? getCookieToken() => configuration.cookieToken;
}
