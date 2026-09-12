import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart' hide Order;
import 'package:medusa_admin/src/core/error/medusa_error.dart';
import 'package:medusa_admin/src/core/di/di.dart';
import 'package:medusa_admin_dart_client/medusa_admin_dart_client_v2.dart';
import 'package:multiple_result/multiple_result.dart';

@lazySingleton
class OrderCrudUseCase {
  final MedusaAdminV2 _medusaAdmin;

  OrderCrudUseCase(this._medusaAdmin);

  static OrderCrudUseCase get instance => getIt<OrderCrudUseCase>();

  OrdersRepository get _orderRepository => _medusaAdmin.orders;

  OrderEditsRepository get _orderEditRepository => _medusaAdmin.orderEdits;

  NotificationsRepository get _notificationRepository =>
      _medusaAdmin.notifications;

  UsersRepository get _userRepository => _medusaAdmin.users;

  FulfillmentsRepository get _fulfillmentRepository =>
      _medusaAdmin.fulfillments;

  Future<Result<Order, MedusaError>> retrieveOrder({
    required String id,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final result = await _orderRepository.retrieve(
        id,
        queryParameters: queryParameters,
      );
      return Success(result.order);
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

  Future<Result<OrderEditListRes, MedusaError>> retrieveAllOrderEdit({
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final result = await _orderEditRepository.list(
        query: queryParameters,
      );
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

  // Future<Result<OrderEdit, MedusaError>> cancelOrderEdit({
  //   required String id,
  //   Map<String, dynamic>? queryParameters,
  // }) async {
  //   try {
  //     final result = await _orderEditRepository.cancelOrderEdit(id: id);
  //     return Success(result!);
  //   } on DioException catch (e) {
  //     return Error(MedusaError.fromHttp(
  //       status: e.response?.statusCode,
  //       body: e.response?.data,
  //       cause: e,
  //     ));
  //   } catch (error, stack) {
  //     if (kDebugMode) {
  //       log(error.toString());
  //       log(stack.toString());
  //     }
  //     return Error(MedusaError(code: 'unknown', type: 'unknown', message: error.toString()));
  //   }
  // }

  Future<Result<Order, MedusaError>> confirmOrderEdit({
    required String id,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final result = await _orderEditRepository.confirm(id: id);
      return Success(result.orderPreview);
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

  Future<Result<Order, MedusaError>> createFulfillment({
    required String orderId,
    required PostOrdersFulfillmentsReq payload,
  }) async {
    try {
      final result = await _orderRepository.createFulfillment(orderId, payload);
      return Success(result.order);
    } on DioException catch (e) {
      // Robust Fallback: Medusa core expects `item_id` rather than `line_item_id`
      try {
        final rawItems = payload.items.map((it) {
          final id = it.lineItemId ?? it.id;
          return {
            'item_id': id,
            'line_item_id': id,
            'quantity': it.quantity ?? 1,
          };
        }).toList();

        final response = await getIt<Dio>().post(
          '/admin/orders/$orderId/fulfillments',
          data: {
            'items': rawItems,
            if (payload.locationId != null) 'location_id': payload.locationId,
            if (payload.noNotification != null)
              'no_notification': payload.noNotification,
            if (payload.metadata != null) 'metadata': payload.metadata,
          },
        );

        if (response.data is Map<String, dynamic> &&
            response.data['order'] != null) {
          final ord =
              Order.fromJson(response.data['order'] as Map<String, dynamic>);
          return Success(ord);
        }
      } catch (_) {}

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

  Future<Result<NotificationsListRes, MedusaError>> retrieveNotifications({
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final result = await _notificationRepository.list(
        query: queryParameters,
      );
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

  Future<Result<Order, MedusaError>> archiveOrder({
    required String id,
  }) async {
    try {
      final result = await _orderRepository.archive(id);
      return Success(result.order);
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

  Future<Result<User, MedusaError>> retrieveUser({
    required String id,
  }) async {
    try {
      final response = await _userRepository.retrieve(id);
      return Success(response.user);
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

  Future<Result<Order, MedusaError>> updateOrder(
      {required String id, required PostOrdersOrderReq payload}) async {
    try {
      final response = await _orderRepository.update(id, payload);
      return Success(response.order);
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

  // Future<Result<Order, MedusaError>> createOrderShipment({
  //   required String id,
  //   required String fulfillmentId,
  //   List<String>? trackingNumbers,
  // }) async {
  //   try {
  //     final response = await _forderRepository.createOrderShipment(
  //         id: id, fulfillmentId: fulfillmentId, trackingNumbers: trackingNumbers);
  //     if (response != null) {
  //       return Success(response);
  //     } else {
  //       return Error(Failure.from(response));
  //     }
  //   } on DioException catch (e) {
  //     return Error(MedusaError.fromHttp(
  //       status: e.response?.statusCode,
  //       body: e.response?.data,
  //       cause: e,
  //     ));
  //   } catch (error, stack) {
  //     if (kDebugMode) {
  //       log(error.toString());
  //       log(stack.toString());
  //     }
  //     return Error(MedusaError(code: 'unknown', type: 'unknown', message: error.toString()));
  //   }
  // }
  //
  // Future<Result<Order, MedusaError>> createRefund({
  //   required String id,
  //   required CreateRefundOrdersReq payload,
  // }) async {
  //   try {
  //     final response = await _orderRepository.createRefund(
  //       id: id,
  //       userCreateRefundOrdersReq: payload,
  //     );
  //     if (response != null) {
  //       return Success(response);
  //     } else {
  //       return Error(Failure.from(response));
  //     }
  //   } on DioException catch (e) {
  //     return Error(MedusaError.fromHttp(
  //       status: e.response?.statusCode,
  //       body: e.response?.data,
  //       cause: e,
  //     ));
  //   } catch (error, stack) {
  //     if (kDebugMode) {
  //       log(error.toString());
  //       log(stack.toString());
  //     }
  //     return Error(MedusaError(code: 'unknown', type: 'unknown', message: error.toString()));
  //   }
  // }
  //
  Future<Result<Order, MedusaError>> createShipment({
    required String id,
    required String fulfillmentId,
  }) async {
    try {
      final response = await _orderRepository.createShipment(
        id,
        fulfillmentId,
        const CreateOrderShipmentReq(items: []),
      );
      return Success(response.order);
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

  Future<Result<Payment, MedusaError>> capturePayment({
    required String paymentId,
  }) async {
    try {
      final response = await _medusaAdmin.payments.capture(id: paymentId);
      return Success(response.payment);
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

  Future<Result<Fulfillment, MedusaError>> cancelFulfillment({
    required String fulfillmentId,
  }) async {
    try {
      final response = await _fulfillmentRepository.cancel(fulfillmentId);
      return Success(response.fulfillment);
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
