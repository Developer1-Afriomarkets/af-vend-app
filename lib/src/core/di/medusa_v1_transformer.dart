import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:medusa_admin/src/core/constants/strings.dart';
import 'package:medusa_admin/src/core/di/di.dart';
import 'package:medusa_admin/src/core/utils/enums.dart';
import 'package:medusa_admin/src/features/auth/data/service/auth_preference_service.dart';
import 'package:medusa_admin/src/core/di/medusa_v1_client.dart';

/// A Dio interceptor that normalises Medusa V1 API responses into shapes
/// compatible with the V2 dart client models, and strips V2-specific query
/// parameters that V1 rejects with a 500.
class MedusaV1ResponseTransformer extends Interceptor {
  // ---------------------------------------------------------------------------
  // Request — strip V2-only query params, rewrite stores, and handle mocks
  // ---------------------------------------------------------------------------

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final uri = Uri.tryParse(options.path);
    final String path = (uri != null && uri.hasAbsolutePath)
        ? uri.path
        : (options.path.startsWith('/') ? options.path : '/${options.path}');

    final isOrderRetrieve = path.startsWith('/admin/orders/') && 
        !path.contains('/deliveries') && 
        options.method == 'GET';
    
    final isProductRetrieve = path.startsWith('/admin/products/') &&
        options.method == 'GET';

    if (isOrderRetrieve) {
      final fieldsVal = options.queryParameters['fields'];
      if (fieldsVal is String) {
        final List<String> v1Relations = [
          'shipping_address',
          'billing_address',
          'customer',
          'region',
          'shipping_methods',
          'payments',
          'refunds',
          'discounts',
          'fulfillments',
          'returns',
          'claims',
          'swaps',
          'items',
          'sales_channel'
        ];
        final fieldParts = fieldsVal.split(',');
        final existingExpand = options.queryParameters['expand']?.toString();
        final List<String> expandParts = existingExpand != null
            ? existingExpand.split(',').where((e) => e.isNotEmpty).toList()
            : [];
        for (final part in fieldParts) {
          final cleanPart = part.replaceAll('+', '').replaceAll('*', '').trim();
          final baseRelation = cleanPart.split('.').first;
          if (v1Relations.contains(baseRelation) && !expandParts.contains(baseRelation)) {
            expandParts.add(baseRelation);
          }
        }
        options.queryParameters['expand'] = expandParts.join(',');
        options.queryParameters.remove('fields');
      }
    } else if (isProductRetrieve) {
      final fieldsVal = options.queryParameters['fields'];
      if (fieldsVal is String) {
        final List<String> v1Relations = [
          'variants',
          'options',
          'images',
          'tags',
          'type',
          'collection',
          'sales_channels'
        ];
        final fieldParts = fieldsVal.split(',');
        final existingExpand = options.queryParameters['expand']?.toString();
        final List<String> expandParts = existingExpand != null
            ? existingExpand.split(',').where((e) => e.isNotEmpty).toList()
            : [];
        for (final part in fieldParts) {
          final cleanPart = part.replaceAll('+', '').replaceAll('*', '').trim();
          final baseRelation = cleanPart.split('.').first;
          if (v1Relations.contains(baseRelation) && !expandParts.contains(baseRelation)) {
            expandParts.add(baseRelation);
          }
        }
        options.queryParameters['expand'] = expandParts.join(',');
        options.queryParameters.remove('fields');
      }
    } else {
      // Clean fields and expand query parameters for V1 compatibility, mapping V2 * fields
      if (options.queryParameters.containsKey('fields')) {
        final fieldsVal = options.queryParameters['fields'];
        if (fieldsVal is String) {
          final fieldParts = fieldsVal.split(',');
          final v2Relations = fieldParts
              .where((f) => f.startsWith('*'))
              .map((f) => f.substring(1))
              .toList();
          final v1Fields = fieldParts
              .where((f) => !f.startsWith('*') && !f.contains('.'))
              .join(',');

          if (v2Relations.isNotEmpty) {
            final existingExpand = options.queryParameters['expand']?.toString();
            final List<String> expandParts = existingExpand != null
                ? existingExpand.split(',').where((e) => e.isNotEmpty).toList()
                : [];
            for (final rel in v2Relations) {
              if (!expandParts.contains(rel)) {
                expandParts.add(rel);
              }
            }
            options.queryParameters['expand'] = expandParts.join(',');
          }

          if (v1Fields.isNotEmpty) {
            options.queryParameters['fields'] = v1Fields;
          } else {
            options.queryParameters.remove('fields');
          }
        }
      }

      if (options.queryParameters.containsKey('expand')) {
        final expandVal = options.queryParameters['expand'];
        if (expandVal is String) {
          final v1Expand = expandVal.split(',').where((e) => !e.contains('.')).join(',');
          if (v1Expand.isNotEmpty) {
            options.queryParameters['expand'] = v1Expand;
          } else {
            options.queryParameters.remove('expand');
          }
        }
      }
    }

    // V1 Create Product payload wrapping and normalization
    if (path == '/admin/products' && options.method == 'POST') {
      var data = options.data;
      debugPrint('[V1Transformer] Create Product request data type: ${data?.runtimeType}');
      if (data is! Map && data != null) {
        try {
          data = (data as dynamic).toJson();
        } catch (e) {
          debugPrint('[V1Transformer] Failed to convert CreateProductReq to map: $e');
        }
      }
      if (data is Map) {
        final Map productData = data.containsKey('product') 
            ? (data['product'] as Map) 
            : data;
        _normalizeProductPayload(productData, isUpdate: false);
        options.data = productData; // Medusa V1 expects flat payload
      }
    }

    // V1 Update Product payload wrapping and normalization
    if (path.startsWith('/admin/products/') && 
        !path.contains('/variants') && 
        !path.contains('/options') && 
        options.method == 'POST') {
      var data = options.data;
      debugPrint('[V1Transformer] Update Product request data type: ${data?.runtimeType}');
      if (data is! Map && data != null) {
        try {
          data = (data as dynamic).toJson();
        } catch (e) {
          debugPrint('[V1Transformer] Failed to convert UpdateProductReq to map: $e');
        }
      }
      if (data is Map) {
        final Map productData = data.containsKey('product') 
            ? (data['product'] as Map) 
            : data;
        productData.remove('variants');
        _normalizeProductPayload(productData, isUpdate: true);
        options.data = productData; // Medusa V1 expects flat payload
      }
    }

    // Rewrites for V1 Store endpoints (V2 calls /admin/stores plural)
    if (path == '/admin/store' ||
        path == '/admin/stores' ||
        path.startsWith('/admin/store?') ||
        path.startsWith('/admin/stores?') ||
        path.startsWith('/admin/store/') ||
        path.startsWith('/admin/stores/')) {
      options.path = '/admin/store';
      if (options.method == 'POST' && options.data is Map) {
        final data = Map<String, dynamic>.from(options.data as Map);
        final v1Payload = <String, dynamic>{};
        if (data.containsKey('name')) {
          v1Payload['name'] = data['name'];
        }

        // Extract default currency and currencies list from supported_currencies
        if (data.containsKey('supported_currencies') && data['supported_currencies'] is List) {
          final scList = data['supported_currencies'] as List;
          final currencyCodes = <String>[];
          String? defCode;
          for (final item in scList) {
            if (item is Map) {
              final code = item['currency_code']?.toString().toLowerCase();
              if (code != null && code.isNotEmpty) {
                currencyCodes.add(code);
                if (item['is_default'] == true) {
                  defCode = code;
                }
              }
            }
          }
          if (currencyCodes.isNotEmpty) {
            v1Payload['currencies'] = currencyCodes;
          }
          if (defCode != null) {
            v1Payload['default_currency_code'] = defCode;
          }
        }

        if (data.containsKey('default_currency_code')) {
          v1Payload['default_currency_code'] = data['default_currency_code'];
        }
        if (data.containsKey('currencies') && data['currencies'] is List) {
          v1Payload['currencies'] = data['currencies'];
        }

        // Persist default_region_id in store metadata
        final meta = data.containsKey('metadata') && data['metadata'] is Map
            ? Map<String, dynamic>.from(data['metadata'] as Map)
            : <String, dynamic>{};
        if (data.containsKey('default_region_id') && data['default_region_id'] != null) {
          meta['default_region_id'] = data['default_region_id'];
        }
        if (meta.isNotEmpty) {
          v1Payload['metadata'] = meta;
        }

        if (data.containsKey('default_sales_channel_id')) {
          v1Payload['default_sales_channel_id'] = data['default_sales_channel_id'];
        }

        options.data = v1Payload;
      }
    }

    // Rewrites for V2 Promotions -> V1 Discounts
    if (path.startsWith('/admin/promotions')) {
      options.path = options.path.replaceFirst('/admin/promotions', '/admin/discounts');
    }

    // Request body transformer: V2 Promotions -> V1 Discounts
    if (path.startsWith('/admin/discounts')) {
      final data = options.data;
      if (data is Map) {
        final v1Payload = <String, dynamic>{};
        if (data.containsKey('code')) {
          v1Payload['code'] = data['code'];
        }
        
        final appMethod = data['application_method'];
        if (appMethod is Map) {
          final ruleMap = <String, dynamic>{};
          ruleMap['type'] = appMethod['type'] ?? 'percentage';
          ruleMap['value'] = appMethod['value'] ?? 0;
          ruleMap['allocation'] = appMethod['allocation'] ?? 'total';
          ruleMap['description'] = appMethod['description'] ?? '';
          v1Payload['rule'] = ruleMap;
        }

        final campaign = data['campaign'];
        if (campaign is Map) {
          if (campaign.containsKey('starts_at')) v1Payload['starts_at'] = campaign['starts_at'];
          if (campaign.containsKey('ends_at')) v1Payload['ends_at'] = campaign['ends_at'];
        }
        
        final addData = data['additional_data'];
        if (addData is Map) {
          if (addData.containsKey('regions')) v1Payload['regions'] = addData['regions'];
          if (addData.containsKey('is_dynamic')) v1Payload['is_dynamic'] = addData['is_dynamic'];
          if (addData.containsKey('usage_limit')) v1Payload['usage_limit'] = addData['usage_limit'];
          if (addData.containsKey('is_disabled')) v1Payload['is_disabled'] = addData['is_disabled'];
        }

        v1Payload.putIfAbsent('is_dynamic', () => false);
        v1Payload.putIfAbsent('regions', () => <String>[]);
        
        options.data = v1Payload;
      }
    }

    // Request body transformer: V2 Regions -> V1 Regions
    if (path == '/admin/regions' || (path.startsWith('/admin/regions/') && options.method == 'POST')) {
      final data = options.data;
      if (data is Map) {
        final metadata = data['metadata'];
        if (metadata is Map && metadata.containsKey('fulfillment_providers')) {
          data['fulfillment_providers'] = metadata['fulfillment_providers'];
          metadata.remove('fulfillment_providers');
        }
      }
    }

    // Mocks for endpoints V1 doesn't have
    if (path.contains('/admin/currencies')) {
      _handleCurrenciesRequest(options, handler);
      return;
    }

    if (path.contains('/admin/tax-regions')) {
      _handleTaxRegionsRequest(options, handler);
      return;
    }

    if (path.contains('/admin/customer-groups')) {
      final hasCustomerFilter = options.queryParameters.containsKey('customers') ||
          options.queryParameters.keys.any((k) => k.startsWith('customers'));
      if (hasCustomerFilter) {
        _handleCustomerGroupsFilteredRequest(options, handler);
        return;
      }
    }

    if (path.contains('/admin/inventory-items') ||
        path.contains('/admin/stock-locations') ||
        path.contains('/admin/reservations') ||
        path.contains('/admin/order-edits') ||
        path.contains('/admin/campaigns') ||
        path.contains('/admin/price-preferences')) {
      _handleV2OnlyEndpointMock(options, handler);
      return;
    }

    // V2 → V1 path rewrite: Order fulfillment creation
    // V2 uses POST /admin/orders/:id/fulfillments (plural)
    // V1 uses POST /admin/orders/:id/fulfillment (singular)
    final fulfillmentCreateRegex = RegExp(r'^/admin/orders/[^/]+/fulfillments$');
    if (fulfillmentCreateRegex.hasMatch(path) && options.method == 'POST') {
      options.path = options.path.replaceFirst('/fulfillments', '/fulfillment');
      debugPrint('[V1Transformer] Rewrote fulfillment path: ${options.path}');
    }

    // V2 → V1 path rewrite: Mark fulfillment as shipped
    // V2 uses POST /admin/orders/:id/fulfillments/:fid/shipment
    // V1 uses POST /admin/orders/:id/shipment
    final shipmentRegex = RegExp(r'^/admin/orders/([^/]+)/fulfillments/([^/]+)/shipment$');
    final shipmentMatch = shipmentRegex.firstMatch(path);
    if (shipmentMatch != null && options.method == 'POST') {
      final orderId = shipmentMatch.group(1)!;
      final fulfillmentId = shipmentMatch.group(2)!;
      options.path = '/admin/orders/$orderId/shipment';
      // Pass fulfillment_id in body so V1 knows which fulfillment to ship
      final existingData = options.data;
      final Map<String, dynamic> body = existingData is Map
          ? Map<String, dynamic>.from(existingData as Map)
          : <String, dynamic>{};
      body['fulfillment_id'] = fulfillmentId;
      options.data = body;
      debugPrint('[V1Transformer] Rewrote shipment path: ${options.path}');
    }

    // V2 → V1 path rewrite: Cancel fulfillment
    // V2 uses DELETE /admin/orders/:id/fulfillments/:fid/cancel
    // V1 uses POST /admin/orders/:id/fulfillments/:fid/cancel (same path, ignore)
    final cancelFulfillmentRegex = RegExp(r'^/admin/orders/[^/]+/fulfillments/[^/]+/cancel$');
    if (cancelFulfillmentRegex.hasMatch(path) && options.method == 'POST') {
      // V1 also uses POST for cancel — already correct, no rewrite needed
      debugPrint('[V1Transformer] Fulfillment cancel path OK: $path');
    }

    handler.next(options);
  }

  // ---------------------------------------------------------------------------
  // Auth header helper (used by internal Dio calls)
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{};
    final authType = AuthPreferenceService.authTypeGetter;
    final secureStorage = getIt<FlutterSecureStorage>();
    try {
      switch (authType) {
        case AuthenticationType.cookie:
          final String? cookie =
              await secureStorage.read(key: AppConstants.cookieKey);
          if (cookie?.isNotEmpty ?? false) {
            headers['Cookie'] = cookie!;
          }
          break;
        case AuthenticationType.token:
          final token =
              await secureStorage.read(key: AppConstants.tokenKey);
          if (token != null) {
            headers['x-medusa-access-token'] = token;
          }
          break;
        case AuthenticationType.supabase:
          final token =
              await secureStorage.read(key: AppConstants.supabaseTokenKey);
          if (token != null) {
            headers['sb-access-token'] = token;
          }
          break;
        case AuthenticationType.jwt:
          final String? jwt =
              await secureStorage.read(key: AppConstants.jwtKey);
          if (jwt?.isNotEmpty ?? false) {
            headers['Authorization'] = 'Bearer $jwt';
          }
          break;
      }
    } catch (_) {}
    return headers;
  }

  // ---------------------------------------------------------------------------
  // Mock handlers
  // ---------------------------------------------------------------------------

  void _handleCurrenciesRequest(
      RequestOptions options, RequestInterceptorHandler handler) {
    final allCurrencies = [
      {
        'code': 'usd',
        'symbol': '\$',
        'symbol_native': '\$',
        'name': 'US Dollar'
      },
      {'code': 'eur', 'symbol': '€', 'symbol_native': '€', 'name': 'Euro'},
      {
        'code': 'gbp',
        'symbol': '£',
        'symbol_native': '£',
        'name': 'British Pound'
      },
      {
        'code': 'ngn',
        'symbol': '₦',
        'symbol_native': '₦',
        'name': 'Nigerian Naira'
      },
      {
        'code': 'ghs',
        'symbol': 'GH₵',
        'symbol_native': 'GH₵',
        'name': 'Ghanaian Cedi'
      },
      {
        'code': 'cad',
        'symbol': 'CA\$',
        'symbol_native': '\$',
        'name': 'Canadian Dollar'
      },
      {
        'code': 'aud',
        'symbol': 'A\$',
        'symbol_native': '\$',
        'name': 'Australian Dollar'
      },
      {
        'code': 'jpy',
        'symbol': '¥',
        'symbol_native': '¥',
        'name': 'Japanese Yen'
      },
      {
        'code': 'cny',
        'symbol': 'CN¥',
        'symbol_native': '¥',
        'name': 'Chinese Yuan'
      },
      {
        'code': 'inr',
        'symbol': '₹',
        'symbol_native': '₹',
        'name': 'Indian Rupee'
      },
    ];

    List<Map<String, dynamic>> currencies = allCurrencies;
    final hasCodeParam = options.queryParameters.keys.any((k) => k == 'code' || k.startsWith('code[') || k.startsWith('code'));
    if (hasCodeParam) {
      final requestedCodes = <String>{};
      for (final entry in options.queryParameters.entries) {
        if (entry.key == 'code' || entry.key.startsWith('code[') || entry.key.startsWith('code')) {
          if (entry.value is List) {
            requestedCodes.addAll((entry.value as List).map((e) => e.toString().toLowerCase()));
          } else if (entry.value != null) {
            requestedCodes.add(entry.value.toString().toLowerCase());
          }
        }
      }
      currencies = allCurrencies
          .where((c) => requestedCodes.contains(c['code']?.toString().toLowerCase()))
          .toList();
    }

    handler.resolve(Response(
      requestOptions: options,
      data: {
        'currencies': currencies,
        'limit': 100,
        'offset': 0,
        'count': currencies.length,
      },
      statusCode: 200,
    ));
  }

  void _handleTaxRegionsRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final internalDio = Dio(BaseOptions(baseUrl: options.baseUrl));
      internalDio.options.headers.addAll(authHeaders);

      final response = await internalDio.get('/admin/regions');
      final rawData = response.data;

      final taxRegions = <Map<String, dynamic>>[];
      if (rawData is Map<String, dynamic> && rawData['regions'] is List) {
        for (final region in rawData['regions']) {
          if (region is Map<String, dynamic>) {
            final countries = region['countries'];
            final taxRates = region['tax_rates'] ?? [];
            if (countries is List) {
              for (final country in countries) {
                if (country is Map<String, dynamic>) {
                  taxRegions.add({
                    'id': region['id'],
                    'country_code':
                        country['iso_2'] ?? country['country_code'] ?? '',
                    'province_code': null,
                    'parent_id': null,
                    'parent': null,
                    'children': <dynamic>[],
                    'tax_rates': taxRates,
                    'created_at': region['created_at'],
                    'updated_at': region['updated_at'],
                  });
                }
              }
            }
          }
        }
      }

      handler.resolve(Response(
        requestOptions: options,
        data: {
          'tax_regions': taxRegions,
          'limit': 100,
          'offset': 0,
          'count': taxRegions.length,
        },
        statusCode: 200,
      ));
    } catch (e, s) {
      debugPrint('[V1Transformer] Error mocking tax-regions: $e\n$s');
      handler.resolve(Response(
        requestOptions: options,
        data: {
          'tax_regions': <dynamic>[],
          'limit': 100,
          'offset': 0,
          'count': 0,
        },
        statusCode: 200,
      ));
    }
  }

  void _handleCustomerGroupsFilteredRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      String? customerId;
      for (final entry in options.queryParameters.entries) {
        if (entry.key.startsWith('customers')) {
          if (entry.value is String) {
            customerId = entry.value as String;
          } else if (entry.value is Map) {
            customerId = entry.value['id']?.toString();
          }
        }
      }

      if (customerId == null) {
        handler.resolve(Response(
          requestOptions: options,
          data: {
            'customer_groups': <dynamic>[],
            'limit': 100,
            'offset': 0,
            'count': 0,
          },
          statusCode: 200,
        ));
        return;
      }

      final authHeaders = await _getAuthHeaders();
      final internalDio = Dio(BaseOptions(baseUrl: options.baseUrl));
      internalDio.options.headers.addAll(authHeaders);

      final response = await internalDio.get('/admin/customers/$customerId');
      final rawData = response.data;

      var groups = <dynamic>[];
      if (rawData is Map<String, dynamic> && rawData['customer'] is Map) {
        final customer = rawData['customer'];
        if (customer['groups'] is List) {
          groups = customer['groups'] as List;
        }
      }

      handler.resolve(Response(
        requestOptions: options,
        data: {
          'customer_groups': groups,
          'limit': 100,
          'offset': 0,
          'count': groups.length,
        },
        statusCode: 200,
      ));
    } catch (e, s) {
      debugPrint('[V1Transformer] Error mocking customer-groups filter: $e\n$s');
      handler.resolve(Response(
        requestOptions: options,
        data: {
          'customer_groups': <dynamic>[],
          'limit': 100,
          'offset': 0,
          'count': 0,
        },
        statusCode: 200,
      ));
    }
  }

  void _handleV2OnlyEndpointMock(
      RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
    String mainKey = 'items';
    if (path.contains('inventory-items')) {
      mainKey = 'inventory_items';
    } else if (path.contains('stock-locations')) {
      mainKey = 'stock_locations';
    } else if (path.contains('reservations')) {
      mainKey = 'reservations';
    } else if (path.contains('order-edits')) {
      mainKey = 'order_edits';
    } else if (path.contains('price-preferences')) {
      mainKey = 'price_preferences';
    } else if (path.contains('campaigns')) {
      mainKey = 'campaigns';
    }

    handler.resolve(Response(
      requestOptions: options,
      data: {
        mainKey: <dynamic>[],
        'limit': 100,
        'offset': 0,
        'count': 0,
      },
    ));
  }

  void _normalizeProductPayload(Map data, {bool isUpdate = false}) {
    // Map type_id to type object for V1 compatibility
    if (data.containsKey('type_id') && data['type_id'] != null) {
      data['type'] = {'id': data['type_id']};
    }

    // Normalize sales_channels for V1 format: [{ id: 'sc_...' }]
    // V1 POST /admin/products DOES support sales_channels.
    // Preserve and normalize before the cleanup loop below.
    List<Map<String, dynamic>>? normalizedSalesChannels;
    final rawSalesChannels = data['sales_channels'];
    if (rawSalesChannels is List && rawSalesChannels.isNotEmpty) {
      normalizedSalesChannels = rawSalesChannels
          .whereType<Map>()
          .map((sc) => <String, dynamic>{'id': sc['id'].toString()})
          .where((sc) => sc['id'] != null && sc['id'] != 'null')
          .toList();
    }

    // Remove V2 keys that are null or not supported at root in V1
    final keysToRemove = [
      'type_id',
      'external_id',
      'shipping_profile_id',
      'profile_id',
      'categories',
      'sales_channels', // will be re-added below in V1 format
      'store_id',
      'deleted_at',
      'updated_at',
      'created_at',
      'profiles',
      'profile',
      'store',
      'collection',
    ];
    for (final key in keysToRemove) {
      data.remove(key);
    }

    // Re-attach normalized sales_channels if we have any
    if (normalizedSalesChannels != null && normalizedSalesChannels.isNotEmpty) {
      data['sales_channels'] = normalizedSalesChannels;
    }


    // Clean null fields at root to prevent V1 validation complaints
    data.removeWhere((key, value) => value == null);

    // Convert empty string dimensions to null or numeric
    for (final key in ['weight', 'length', 'height', 'width']) {
      if (data.containsKey(key)) {
        final val = data[key];
        if (val == '' || val == null) {
          data.remove(key);
        } else if (val is String) {
          data[key] = double.tryParse(val) ?? int.tryParse(val);
        }
      }
    }

    // Normalize tags: in V1, tags is list of objects with "value" field
    if (data['tags'] is List) {
      final tagsList = data['tags'] as List;
      final normalizedTags = <Map<String, dynamic>>[];
      for (final t in tagsList) {
        if (t is Map) {
          if (t['value'] != null) {
            normalizedTags.add({
              'value': t['value'].toString(),
              if (t['id'] != null) 'id': t['id'].toString(),
            });
          }
        } else if (t is String) {
          normalizedTags.add({'value': t});
        }
      }
      data['tags'] = normalizedTags;
    }

    // 2. Normalize options
    if (data['options'] is List) {
      final optionsList = data['options'] as List;
      final normalizedOptions = <Map>[];
      for (final opt in optionsList) {
        if (opt is Map) {
          final optCopy = Map.from(opt);
          optCopy.remove('values'); // V1 options must not have "values"
          optCopy.removeWhere((k, v) => v == null);
          normalizedOptions.add(optCopy);
        }
      }
      data['options'] = normalizedOptions;
    }

    // 3. Normalize variants
    if (data['variants'] is List) {
      final variantsList = data['variants'] as List;
      final normalizedVariants = <Map>[];
      for (final variant in variantsList) {
        if (variant is Map) {
          final varCopy = Map.from(variant);
          // Remove V2 variant properties
          varCopy.remove('values');
          varCopy.remove('variant_rank');
          varCopy.remove('inventory_items');
          varCopy.remove('rank');

          varCopy.removeWhere((k, v) => v == null);

          // If metadata has inventory_quantity, extract it to the root of the variant for V1 compatibility
          if (varCopy['metadata'] is Map && varCopy['metadata']['inventory_quantity'] != null) {
            varCopy['inventory_quantity'] = varCopy['metadata']['inventory_quantity'];
            final Map newMeta = Map.from(varCopy['metadata'] as Map);
            newMeta.remove('inventory_quantity');
            varCopy['metadata'] = newMeta.isEmpty ? null : newMeta;
          }

          // Clean empty dimensions in variant
          for (final key in ['weight', 'length', 'height', 'width']) {
            if (varCopy.containsKey(key)) {
              final val = varCopy[key];
              if (val == '' || val == null) {
                varCopy.remove(key);
              } else if (val is String) {
                varCopy[key] = double.tryParse(val) ?? int.tryParse(val);
              }
            }
          }

          // Clean options: V2 has Map, V1 needs List of { "value": "..." } or { "option_id": "...", "value": "..." }
          if (varCopy['options'] is Map) {
            final optsMap = varCopy['options'] as Map;
            final optsList = <Map<String, dynamic>>[];
            optsMap.forEach((key, val) {
              final Map<String, dynamic> optObj = {
                'value': val.toString(),
              };
              if (key.startsWith('opt_')) {
                optObj['option_id'] = key;
              }
              optsList.add(optObj);
            });
            varCopy['options'] = optsList;
          }

          normalizedVariants.add(varCopy);
        }
      }
      data['variants'] = normalizedVariants;
    }
  }

  // ---------------------------------------------------------------------------
  // Response — normalise V1 shapes
  // ---------------------------------------------------------------------------

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final rawData = response.data;

    // Extract session cookie for V1 Auth
    final path = response.requestOptions.path;
    final method = response.requestOptions.method;
    if (path.contains('/admin/auth') && method == 'POST') {
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null && setCookie.isNotEmpty) {
        for (final headerVal in setCookie) {
          if (headerVal.contains('connect.sid=')) {
            final parts = headerVal.split(';');
            for (final part in parts) {
              final trimmed = part.trim();
              if (trimmed.startsWith('connect.sid=')) {
                final token = trimmed.split('=').last;
                debugPrint('[V1Transformer] Extracted V1 cookie token: $token');
                try {
                  getIt<InterceptedMedusa>().setCookieToken(token);
                  getIt<FlutterSecureStorage>().write(key: AppConstants.cookieKey, value: 'connect.sid=$token');
                } catch (e) {
                  debugPrint('[V1Transformer] Error storing session cookie: $e');
                }
                break;
              }
            }
          }
        }
      }
    }

    if (rawData == null) return handler.next(response);

    Map<String, dynamic> data;
    try {
      // jsonEncode + jsonDecode breaks any JS-typed web wrappers into plain Dart
      data = jsonDecode(jsonEncode(rawData)) as Map<String, dynamic>;
      
      // Extract API Token if present in login/user response
      if (path.contains('/admin/auth') && method == 'POST') {
        final user = data['user'];
        if (user != null && user is Map<String, dynamic>) {
          final apiToken = user['api_token'];
          if (apiToken != null && apiToken is String && apiToken.isNotEmpty) {
            debugPrint('[V1Transformer] Extracted V1 API Token: $apiToken');
            try {
              getIt<InterceptedMedusa>().setApiKey(apiToken);
              getIt<FlutterSecureStorage>().write(key: AppConstants.tokenKey, value: apiToken);
            } catch (e) {
              debugPrint('[V1Transformer] Error storing V1 API Token: $e');
            }
          }
        }
      }
    } catch (_) {
      return handler.next(response);
    }

    debugPrint('[V1Transformer] Processing response for $path');
    try {
      // Walk the entire JSON tree and patch V1 gaps
      _recursiveNormalize(data);

      // Wrap singular store → plural list for V2 client expectations
      if (path.contains('/admin/store')) {
        final store = data['store'];
        if (store is Map<String, dynamic>) {
          // 1. Populate default_region_id from metadata if present
          if (store['default_region_id'] == null && store['metadata'] is Map) {
            store['default_region_id'] = store['metadata']['default_region_id'];
          }

          // 2. Map V1 currencies -> V2 supported_currencies
          final defaultCurrencyCode = (store['default_currency_code'] ?? 'usd').toString().toLowerCase();
          final currencies = store['currencies'];
          if (!store.containsKey('supported_currencies')) {
            final scList = <Map<String, dynamic>>[];
            if (currencies is List) {
              for (final c in currencies) {
                if (c == null) continue;
                final code = (c is Map ? c['code'] : c.toString()).toString().toLowerCase();
                if (code.isEmpty) continue;
                final isDefault = code == defaultCurrencyCode;
                scList.add({
                  'id': 'curr_${store['id']}_$code',
                  'currency_code': code,
                  'store_id': store['id'],
                  'is_default': isDefault,
                  'currency': c is Map ? c : {
                    'code': code,
                    'symbol': code == 'ngn' ? '₦' : (code == 'usd' ? r'$' : code.toUpperCase()),
                    'name': code.toUpperCase(),
                    'symbol_native': code == 'ngn' ? '₦' : code.toUpperCase(),
                  },
                });
              }
            }
            if (scList.isEmpty && defaultCurrencyCode.isNotEmpty) {
              scList.add({
                'id': 'curr_${store['id']}_$defaultCurrencyCode',
                'currency_code': defaultCurrencyCode,
                'store_id': store['id'],
                'is_default': true,
                'currency': {
                  'code': defaultCurrencyCode,
                  'symbol': defaultCurrencyCode == 'ngn' ? '₦' : (defaultCurrencyCode == 'usd' ? r'$' : defaultCurrencyCode.toUpperCase()),
                  'name': defaultCurrencyCode.toUpperCase(),
                  'symbol_native': defaultCurrencyCode == 'ngn' ? '₦' : defaultCurrencyCode.toUpperCase(),
                },
              });
            }
            store['supported_currencies'] = scList;
          }

          if (!data.containsKey('stores')) {
            data['stores'] = [store];
            data['limit'] = 1;
            data['offset'] = 0;
            data['count'] = 1;
          }
        }
      }

      // If the response map has a list field but is missing pagination metadata, supply defaults.
      data.putIfAbsent('limit', () => 50);
      data.putIfAbsent('offset', () => 0);
      if (!data.containsKey('count')) {
        for (final val in data.values) {
          if (val is List) {
            data['count'] = val.length;
            break;
          }
        }
      }
      data.putIfAbsent('count', () => 0);

      // Wrap/Rename V1 discounts -> V2 promotions key
      if (path.contains('/admin/promotions') || path.contains('/admin/discounts')) {
        final discounts = data['discounts'];
        if (discounts != null && !data.containsKey('promotions')) {
          data['promotions'] = discounts;
        }
        final discount = data['discount'];
        if (discount != null && !data.containsKey('promotion')) {
          data['promotion'] = discount;
        }
      }

      // V1 → V2 upload response remap:
      // V1 POST /admin/uploads returns: { "uploads": [{ "url": "..." }] }
      // V2 client expects:              { "files":   [{ "url": "...", "id": "...", "key": "..." }] }
      if (path.contains('/admin/uploads') && method == 'POST') {
        final v1Uploads = data['uploads'];
        if (v1Uploads is List && !data.containsKey('files')) {
          final mappedFiles = v1Uploads.map((item) {
            if (item is Map<String, dynamic>) {
              return {
                'url': item['url'] ?? '',
                'id':  item['id']  ?? item['key'] ?? item['url'] ?? '',
                'key': item['key'] ?? item['url'] ?? '',
              };
            }
            return {'url': item.toString(), 'id': item.toString(), 'key': item.toString()};
          }).toList();
          data['files'] = mappedFiles;
          debugPrint('[V1Transformer] Remapped ${mappedFiles.length} upload(s): uploads -> files');
        }
      }

      debugPrint('[V1Transformer] Done for $path');
    } catch (e, s) {
      debugPrint('[V1Transformer] ERROR transforming $path: $e\n$s');
    }

    response.data = data;
    handler.next(response);
  }

  // ---------------------------------------------------------------------------
  // Recursive JSON tree walker
  // ---------------------------------------------------------------------------

  void _recursiveNormalize(dynamic node) {
    if (node is Map<String, dynamic>) {
      _normalizeMap(node);
      for (final val in node.values) {
        _recursiveNormalize(val);
      }
    } else if (node is List) {
      for (final item in node) {
        _recursiveNormalize(item);
      }
    }
  }

  static const _requiredListKeys = {
    'actions',
    'payment_collections',
    'payment_providers',
    'items',
    'promotions',
    'requirements',
    'tax_rates',
    'transaction_groups',
    'api_keys',
    'campaigns',
    'claim_items',
    'additional_items',
    'claims',
    'collections',
    'currencies',
    'customers',
    'addresses',
    'customer_groups',
    'promo_codes',
    'shipping_methods',
    'draft_orders',
    'return_items',
    'exchanges',
    'labels',
    'fulfillment_providers',
    'fulfillment_options',
    'inventory_items',
    'invites',
    'notifications',
    'orders',
    'orderChanges',
    'order_items',
    'shipping_options',
    'orderEdits',
    'payments',
    'plugins',
    'prices',
    'price_lists',
    'price_preferences',
    'created',
    'updated',
    'values',
    'options',
    'products',
    'category_children',
    'product_options',
    'variants',
    'product_categories',
    'product_tags',
    'product_types',
    'rules',
    'ids',
    'operators',
    'attributes',
    'refund_reasons',
    'regions',
    'reservations',
    'returns',
    'return_reasons',
    'sales_channels',
    'price_rules',
    'shipping_option_types',
    'shipping_profiles',
    'stock_locations',
    'add',
    'remove',
    'stores',
    'store_credit_accounts',
    'transactions',
    'tax_regions',
    'files',
    'users',
    'workflow_executions',
  };

  void _normalizeMap(Map<String, dynamic> map) {
    // 0. Generic list fallback: If any known required list key is present but null, default it to empty list.
    for (final key in _requiredListKeys) {
      if (map.containsKey(key) && map[key] == null) {
        map[key] = <dynamic>[];
      }
    }

    // ── 1. Product ──────────────────────────────────────────────────────────
    final isProduct = (map['id'] != null &&
            map['id'].toString().startsWith('prod_')) ||
        (map.containsKey('title') &&
            map.containsKey('handle') &&
            map.containsKey('variants'));
    if (isProduct) {
      map.putIfAbsent('status', () => 'draft');
      map.putIfAbsent('discountable', () => true);
      map.putIfAbsent('is_giftcard', () => false);
      _intToString(map, 'weight');
      _intToString(map, 'height');
      _intToString(map, 'width');
      _intToString(map, 'length');
    }

    // ── 2. ProductVariant ───────────────────────────────────────────────────
    final isVariant = (map['id'] != null &&
            map['id'].toString().startsWith('variant_')) ||
        (map.containsKey('allow_backorder') ||
            map.containsKey('manage_inventory'));
    if (isVariant) {
      map.putIfAbsent('allow_backorder', () => false);
      map.putIfAbsent('manage_inventory', () => true);
      _intToString(map, 'weight');
      _intToString(map, 'height');
      _intToString(map, 'width');
      _intToString(map, 'length');
    }

    // ── 3. Order ────────────────────────────────────────────────────────────
    final isOrder = (map['id'] != null &&
            map['id'].toString().startsWith('order_')) ||
        (map.containsKey('display_id') && map.containsKey('payment_status'));
    if (isOrder) {
      // V2 Order requires `version`
      map.putIfAbsent('version', () => 1);
      _ensureInt(map, 'display_id');

      // V1 uses `line_items`, V2 uses `items`
      if (map.containsKey('line_items') && !map.containsKey('items')) {
        map['items'] = map['line_items'];
      }

      // Populate metadata with V1 pricing details to expose them to OrderExtension getters
      final metadataMap = Map<String, dynamic>.from(map['metadata'] ?? <String, dynamic>{});
      metadataMap['currency_code'] = map['currency_code'] ?? 'usd';
      metadataMap['subtotal'] = map['subtotal'] ?? map['sub_total'] ?? 0;
      metadataMap['shipping_total'] = map['shipping_total'] ?? 0;
      metadataMap['tax_total'] = map['tax_total'] ?? 0;
      metadataMap['total'] = map['total'] ?? 0;
      metadataMap['refunded_total'] = map['refunded_total'] ?? 0;
      metadataMap['paid_total'] = map['paid_total'] ?? 0;
      metadataMap['shipping_address'] = map['shipping_address'];
      map['metadata'] = metadataMap;

      // Ensure summary fields exist for V2 display (V1 omits them)
      map.putIfAbsent('total', () => map['total'] ?? 0);
      map.putIfAbsent('subtotal', () => map['subtotal'] ?? map['sub_total'] ?? 0);
      map.putIfAbsent('tax_total', () => map['tax_total'] ?? 0);
      map.putIfAbsent('discount_total', () => map['discount_total'] ?? 0);
      map.putIfAbsent('shipping_total', () => map['shipping_total'] ?? 0);
    }

    // ── 4. OrderLineItem / LineItem (V1 line_items entries) ─────────────────
    // V1 line_items have `unit_price`, `quantity`, `title` but lack V2 fields.
    // We map to OrderLineItem format (all nullable in V2).
    final isLineItem = (map['id'] != null &&
            (map['id'].toString().startsWith('item_') ||
                (map.containsKey('quantity') &&
                    map.containsKey('unit_price') &&
                    map.containsKey('title') &&
                    !map.containsKey('payment_status'))));
    if (isLineItem) {
      // V2 OrderLineItem uses `unit_price` as num — already compatible
      // Ensure thumbnail is always present (can be null in V2 model)
      map.putIfAbsent('thumbnail', () => null);
      final desc = map['description'] ?? map['subtitle'] ?? map['variant_title'];
      if (desc != null && desc.toString().isNotEmpty) {
        map['variant_title'] = desc;
        map['subtitle'] = desc;
      }
      // Map V1 `variant` subtree fields into flat V2 fields when missing
      final variant = map['variant'];
      if (variant is Map<String, dynamic>) {
        map.putIfAbsent('variant_id', () => variant['id']);
        map.putIfAbsent('variant_sku', () => variant['sku']);
        map.putIfAbsent('variant_title', () => variant['title']);
        map.putIfAbsent(
            'product_id', () => variant['product_id'] ?? map['product_id']);
        // Also ensure variant itself is normalised
        _normalizeMap(variant);
      }
      final product = map['product'];
      if (product is Map<String, dynamic>) {
        map.putIfAbsent('product_title', () => product['title']);
        map.putIfAbsent('product_handle', () => product['handle']);
        map.putIfAbsent('product_description', () => product['description']);
      }
    }

    // ── 5. Store ────────────────────────────────────────────────────────────
    final isStore = map.containsKey('default_currency_code') ||
        (map['id'] != null && map['id'].toString().startsWith('store_'));
    if (isStore) {
      map.putIfAbsent('supported_currencies', () => <dynamic>[]);
      if (map['supported_currencies'] == null || (map['supported_currencies'] as List).isEmpty) {
        final currencies = map['currencies'];
        final String? defaultCode = map['default_currency_code'];
        final String storeId = map['id'] ?? 'store';
        if (currencies is List) {
          map['supported_currencies'] = currencies.map((c) {
            final String code =
                (c is String) ? c : (c is Map ? (c['code'] ?? '') : '');
            final bool isDefault =
                code.toLowerCase() == defaultCode?.toLowerCase();
            return {
              'id': '${storeId}_$code',
              'currency_code': code,
              'store_id': storeId,
              'is_default': isDefault,
              'currency': {
                'code': code,
                'symbol': _getCurrencySymbol(code),
                'symbol_native': _getCurrencySymbol(code),
                'name': code.toUpperCase(),
              }
            };
          }).toList();
        }
      }
    }

    // ── 6. SalesChannel ─────────────────────────────────────────────────────
    final isSalesChannel = (map['id'] != null &&
            map['id'].toString().startsWith('sc_')) ||
        map.containsKey('is_disabled');
    if (isSalesChannel) {
      map.putIfAbsent('is_disabled', () => false);
    }

    // ── 7. Customer ─────────────────────────────────────────────────────────
    // V2 Customer requires `has_account` (bool) — V1 omits it
    final isCustomer = (map['id'] != null &&
            map['id'].toString().startsWith('cus_')) ||
        (map.containsKey('email') &&
            map.containsKey('first_name') &&
            !map.containsKey('payment_status'));
    if (isCustomer) {
      map.putIfAbsent('has_account', () => false);
      map.putIfAbsent('addresses', () => <dynamic>[]);
      map.putIfAbsent('customer_groups', () => <dynamic>[]);
    }

    // ── 8. Region ───────────────────────────────────────────────────────────
    // V2 Region requires `id` and `name` — typically present in V1, but add
    // currency_code mapping from V1's `currency_code` field if needed.
    final isRegion = (map['id'] != null &&
            map['id'].toString().startsWith('reg_')) ||
        (map.containsKey('currency_code') &&
            map.containsKey('countries') &&
            map.containsKey('tax_rates'));
    if (isRegion) {
      // V1 sends `tax_rate` (scalar) and `includes_tax` — V2 ignores these
      // but they don't cause deserialization failures since Region has no
      // required numeric fields. Just ensure name is present.
      map.putIfAbsent('name', () => '');
      map.putIfAbsent('countries', () => <dynamic>[]);
      map.putIfAbsent('tax_rates', () => <dynamic>[]);
      map.putIfAbsent('payment_providers', () => <dynamic>[]);
      map.putIfAbsent('fulfillment_providers', () => <dynamic>[]);

      // Move V1 fields to metadata to expose them to Dart
      final metadataMap = Map<String, dynamic>.from(map['metadata'] ?? <String, dynamic>{});
      if (map.containsKey('payment_providers')) {
        metadataMap['payment_providers'] = map['payment_providers'];
      }
      if (map.containsKey('fulfillment_providers')) {
        metadataMap['fulfillment_providers'] = map['fulfillment_providers'];
      }
      if (map.containsKey('tax_rate')) {
        metadataMap['tax_rate'] = map['tax_rate'];
      }
      if (map.containsKey('tax_rates')) {
        metadataMap['tax_rates'] = map['tax_rates'];
      }
      map['metadata'] = metadataMap;
    }

    // ── 9. FulfillmentLabel ─────────────────────────────────────────────────
    // V2 FulfillmentLabel requires `id`
    final isFulfillmentLabel =
        map.containsKey('tracking_number') && map.containsKey('label_url');
    if (isFulfillmentLabel) {
      map.putIfAbsent('id', () => 'label_${map['tracking_number'] ?? 'unknown'}');
    }

    // ── 10. ProductCategory ─────────────────────────────────────────────────
    final isCategory = (map['id'] != null &&
            map['id'].toString().startsWith('pcat_')) ||
        (map.containsKey('category_children') ||
            map.containsKey('parent_category_id'));
    if (isCategory) {
      map.putIfAbsent('is_active', () => true);
      map.putIfAbsent('is_internal', () => false);
      map.putIfAbsent('category_children', () => <dynamic>[]);
    }

    // ── 11. PriceList ───────────────────────────────────────────────────────
    final isPriceList = (map['id'] != null &&
            map['id'].toString().startsWith('pl_')) ||
        (map.containsKey('prices') &&
            map.containsKey('title') &&
            map.containsKey('type'));
    if (isPriceList) {
      map.putIfAbsent('description', () => '');
      map.putIfAbsent('status', () => 'active');
      map.putIfAbsent('type', () => 'sale');
      map.putIfAbsent('prices', () => <dynamic>[]);
    }

    // ── 12. ShippingOption ──────────────────────────────────────────────────
    final isShippingOption = (map['id'] != null &&
            map['id'].toString().startsWith('so_')) ||
        (map.containsKey('price_type') &&
            (map.containsKey('amount') || map.containsKey('requirements')));
    if (isShippingOption) {
      final soId = map['id'] ?? 'so_unknown';
      if (map.containsKey('amount') && map['amount'] != null && !map.containsKey('prices')) {
        final regionMap = map['region'];
        final String currencyCode = (regionMap is Map) ? (regionMap['currency_code'] ?? 'usd') : 'usd';
        map['prices'] = [
          {
            'id': 'sop_${soId}_$currencyCode',
            'title': 'Price',
            'amount': map['amount'],
            'currency_code': currencyCode,
            'price_rules': <dynamic>[],
            'rules_count': 0,
            'raw_amount': {'amount': map['amount']},
            'min_quantity': 0,
            'max_quantity': 0,
            'price_set_id': 'pset_$soId',
          }
        ];
      }
      if (map.containsKey('requirements') && map['requirements'] is List && !map.containsKey('rules')) {
        final rulesList = <Map<String, dynamic>>[];
        for (final req in map['requirements']) {
          if (req is Map<String, dynamic>) {
            final typeStr = req['type']?.toString();
            if (typeStr != null) {
              final reqId = req['id'] ?? 'req_${req['type']}';
              rulesList.add({
                'id': reqId,
                'shipping_option_id': soId,
                'attribute': typeStr,
                'value': req['amount']?.toString() ?? '0',
                'operator': 'eq',
              });
            }
          }
        }
        map['rules'] = rulesList;
      }
    }

    // ── 13. Discount (V1 Discounts -> V2 Promotions) ────────────────────────
    final isDiscount = (map['id'] != null &&
            map['id'].toString().startsWith('disc_')) ||
        (map.containsKey('code') &&
            map.containsKey('is_dynamic') &&
            map.containsKey('rule'));
    if (isDiscount) {
      map.putIfAbsent('type', () => 'standard');
      map.putIfAbsent('status', () => map['is_disabled'] == true ? 'inactive' : 'active');
      map.putIfAbsent('is_automatic', () => false);
      
      final rule = map['rule'];
      if (rule is Map<String, dynamic> && !map.containsKey('application_method')) {
        map['application_method'] = {
          'id': 'app_method_${map['id']}',
          'type': rule['type'], // percentage, fixed, free_shipping
          'value': rule['value'],
          'allocation': rule['allocation'], // total, item
          'description': rule['description'] ?? '',
        };
      }

      // Preserve V1 regions list inside standard rules
      if (map.containsKey('regions') && map['regions'] is List) {
        final rulesList = List<dynamic>.from(map['rules'] ?? <dynamic>[]);
        final regionsList = map['regions'] as List;
        rulesList.add({
          'id': 'rule_regions_${map['id']}',
          'attribute': 'regions',
          'operator': 'eq',
          'values': regionsList.map((reg) {
            if (reg is Map) {
              return {
                'id': reg['id'],
                'value': reg['id']?.toString() ?? '',
                'label': jsonEncode(reg),
              };
            }
            return {
              'id': reg.toString(),
              'value': reg.toString(),
              'label': jsonEncode({'id': reg.toString(), 'name': reg.toString()}),
            };
          }).toList(),
        });
        map['rules'] = rulesList;
      }

      // Map description and dates into campaign
      if (!map.containsKey('campaign') || map['campaign'] == null) {
        map['campaign'] = {
          'id': 'camp_${map['id']}',
          'name': 'Campaign',
          'campaign_identifier': 'camp_id_${map['id']}',
          'description': rule is Map ? (rule['description'] ?? '') : '',
          'starts_at': map['starts_at'],
          'ends_at': map['ends_at'],
        };
      }
    }

    // ── 14. Country ─────────────────────────────────────────────────────────
    final isCountry = map.containsKey('iso_2') && map.containsKey('iso_3');
    if (isCountry) {
      if (map.containsKey('num_code') && map['num_code'] != null) {
        map['num_code'] = map['num_code'].toString();
      } else {
        map['num_code'] = '';
      }
      map.putIfAbsent('display_name', () => map['name'] ?? '');
    }
  }

  // ---------------------------------------------------------------------------
  // Utility helpers
  // ---------------------------------------------------------------------------

  String _getCurrencySymbol(String code) {
    switch (code.toLowerCase()) {
      case 'usd':
        return '\$';
      case 'eur':
        return '€';
      case 'gbp':
        return '£';
      case 'ngn':
        return '₦';
      case 'ghs':
        return 'GH₵';
      case 'cad':
        return 'CA\$';
      case 'aud':
        return 'A\$';
      case 'jpy':
        return '¥';
      case 'cny':
        return 'CN¥';
      case 'inr':
        return '₹';
      default:
        return code.toUpperCase();
    }
  }

  /// Converts num → String for fields V2 models declare as `String?`
  /// but V1 returns as a number (e.g. weight, height, width, length).
  void _intToString(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val != null && val is num) {
      map[key] =
          val is double ? val.toInt().toString() : val.toString();
    }
  }

  void _ensureInt(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val is String) {
      map[key] = int.tryParse(val);
    }
  }
}
