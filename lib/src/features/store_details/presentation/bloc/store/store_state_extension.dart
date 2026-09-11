import 'package:medusa_admin/src/features/store_details/presentation/bloc/store/store_bloc.dart';
import 'package:medusa_admin_dart_client/medusa_admin_dart_client_v2.dart';

extension StoreStateExtension on StoreState {
  Store? get currentStore => maybeWhen(
        store: (s) => s,
        stores: (r) => r.stores.firstOrNull,
        orElse: () => null,
      );
}
