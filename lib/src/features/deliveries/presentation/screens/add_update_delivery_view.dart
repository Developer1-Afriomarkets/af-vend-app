import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medusa_admin/src/core/di/di.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/core/extensions/text_style_extension.dart';
import 'package:medusa_admin/src/core/extensions/medusa_model_extension.dart';
import 'package:medusa_admin/src/core/services/app_scope_service.dart';
import 'package:medusa_admin/src/features/auth/presentation/bloc/authentication/authentication_bloc.dart';
import 'package:medusa_admin/src/features/orders/domain/usecases/order/order_details_use_case.dart';
import 'package:medusa_admin_dart_client/medusa_admin_dart_client_v2.dart';

@RoutePage()
class AddUpdateDeliveryView extends StatefulWidget {
  const AddUpdateDeliveryView({
    super.key,
    this.delivery,
    this.preselectedOrderId,
    this.preselectedRegionId,
    this.preselectedOrder,
  });

  final Map<String, dynamic>? delivery;
  final String? preselectedOrderId;
  final String? preselectedRegionId;
  final Order? preselectedOrder;

  @override
  State<AddUpdateDeliveryView> createState() => _AddUpdateDeliveryViewState();
}

class _AddUpdateDeliveryViewState extends State<AddUpdateDeliveryView> {
  final supabase = Supabase.instance.client;
  final formKey = GlobalKey<FormState>();

  final driverNameCtrl = TextEditingController();
  final driverPhoneCtrl = TextEditingController();
  final vehiclePlateCtrl = TextEditingController();
  final vehicleMakeCtrl = TextEditingController();
  final destinationAddressCtrl = TextEditingController();
  final customerNameCtrl = TextEditingController();
  final customerPhoneCtrl = TextEditingController();

  List<Map<String, dynamic>> regions = [];
  List<Map<String, dynamic>> logisticsOrgs = [];
  List<Map<String, dynamic>> collectionStations = [];
  List<Order> availableOrders = [];

  Order? primaryOrder;
  bool isFetchingPrimaryOrder = false;

  String? selectedRegionId;
  String? selectedLogisticsOrgId;
  String? selectedOriginStationId;
  String? selectedDestStationId;
  String selectedDeliveryMode = 'doorstep';
  String selectedRouteCategory = 'intra_state';
  String selectedVehicleType = 'bike';
  List<String> selectedOrderIds = [];

  bool isIndependentDelivery = true; // Default: In-House / Merchant delivery!
  bool isLoadingRegions = true;
  bool isLoadingLogistics = true;
  bool isLoadingStations = true;
  bool isLoadingOrders = false;
  bool isSaving = false;

  bool get isEdit => widget.delivery != null;

  final List<Map<String, dynamic>> vehicleOptions = [
    {'type': 'bike', 'label': 'Motorcycle / Bike', 'icon': Icons.two_wheeler_rounded},
    {'type': 'bicycle', 'label': 'Bicycle', 'icon': Icons.pedal_bike_rounded},
    {'type': 'car', 'label': 'Car / Sedan', 'icon': Icons.directions_car_rounded},
    {'type': 'van', 'label': 'Delivery Van', 'icon': Icons.airport_shuttle_rounded},
    {'type': 'truck', 'label': 'Truck', 'icon': Icons.local_shipping_rounded},
  ];

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final del = widget.delivery!;
      driverNameCtrl.text = del['driver_name']?.toString() ?? '';
      driverPhoneCtrl.text = del['driver_phone']?.toString() ?? '';
      vehiclePlateCtrl.text = del['vehicle_vin_or_plate']?.toString() ?? '';
      destinationAddressCtrl.text = del['dest_pickup_station_address']?.toString() ?? '';
      selectedDeliveryMode = del['delivery_mode']?.toString().toLowerCase() ?? 'doorstep';
      selectedRouteCategory = del['route_category']?.toString().toLowerCase() ?? 'intra_state';
      selectedVehicleType = del['vehicle_type']?.toString().toLowerCase() ?? 'bike';
      selectedRegionId = del['region_id']?.toString();
      selectedLogisticsOrgId = del['logistics_org_id']?.toString();
      selectedOriginStationId = del['origin_collection_station_id']?.toString();
      selectedDestStationId = del['dest_collection_station_id']?.toString();

      final rawMeta = del['metadata'];
      if (rawMeta is Map) {
        isIndependentDelivery = rawMeta['fulfillment_type'] != 'third_party';
        customerNameCtrl.text = rawMeta['customer_name']?.toString() ?? '';
        customerPhoneCtrl.text = rawMeta['customer_phone']?.toString() ?? '';
      } else {
        isIndependentDelivery = (selectedLogisticsOrgId == null || selectedLogisticsOrgId!.isEmpty);
      }

      final rawVehicle = del['vehicle_name_make_model_color'];
      if (rawVehicle is List && rawVehicle.isNotEmpty) {
        vehicleMakeCtrl.text = rawVehicle.first.toString();
      }

      final rawOrderIds = del['order_ids'];
      if (rawOrderIds is List) {
        selectedOrderIds = rawOrderIds.map((e) => e.toString()).toList();
      } else if (rawOrderIds is String) {
        try {
          final decoded = jsonDecode(rawOrderIds);
          if (decoded is List) {
            selectedOrderIds = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
    } else {
      isIndependentDelivery = true; // Default in-house
      if (widget.preselectedOrder != null) {
        _applyOrderDetails(widget.preselectedOrder!);
      } else if (widget.preselectedOrderId != null) {
        selectedOrderIds = [widget.preselectedOrderId!];
        if (widget.preselectedRegionId != null) {
          selectedRegionId = widget.preselectedRegionId;
        }
        _fetchPrimaryOrder(widget.preselectedOrderId!);
      } else if (widget.preselectedRegionId != null) {
        selectedRegionId = widget.preselectedRegionId;
      }
    }

    _fetchInitialData();
  }

  void _applyOrderDetails(Order ord) {
    primaryOrder = ord;
    selectedRegionId = ord.regionId;
    if (!selectedOrderIds.contains(ord.id)) {
      selectedOrderIds.add(ord.id);
    }

    // Pre-fill destination address from customer's shipping address
    final addr = ord.shippingAddress;
    if (addr != null && destinationAddressCtrl.text.trim().isEmpty) {
      final parts = [
        addr.address1,
        addr.address2,
        addr.city,
        addr.province,
        addr.countryCode?.toUpperCase(),
      ].where((s) => s != null && s.toString().trim().isNotEmpty).toList();
      if (parts.isNotEmpty) {
        destinationAddressCtrl.text = parts.join(', ');
      }
    }

    // Pre-fill customer contact details
    final custName = ord.customerName;
    if (customerNameCtrl.text.trim().isEmpty && custName != 'N/A') {
      customerNameCtrl.text = custName;
    }
    final rawPhone = (ord.metadata?['shipping_address'] as Map?)?['phone']?.toString() ?? addr?.phone?.toString() ?? '';
    if (customerPhoneCtrl.text.trim().isEmpty && rawPhone.isNotEmpty) {
      customerPhoneCtrl.text = rawPhone;
    }

    // In-house default rider hint
    if (driverNameCtrl.text.trim().isEmpty) {
      driverNameCtrl.text = 'In-House Courier';
    }
  }

  Future<void> _fetchPrimaryOrder(String orderId) async {
    setState(() => isFetchingPrimaryOrder = true);
    try {
      final result = await OrderCrudUseCase.instance.retrieveOrder(id: orderId);
      result.when(
        (ord) {
          if (mounted) {
            setState(() {
              _applyOrderDetails(ord);
              isFetchingPrimaryOrder = false;
            });
            if (selectedRegionId != null) {
              _fetchOrdersForRegion(selectedRegionId!);
            }
          }
        },
        (err) {
          if (mounted) setState(() => isFetchingPrimaryOrder = false);
        },
      );
    } catch (_) {
      if (mounted) setState(() => isFetchingPrimaryOrder = false);
    }
  }

  @override
  void dispose() {
    driverNameCtrl.dispose();
    driverPhoneCtrl.dispose();
    vehiclePlateCtrl.dispose();
    vehicleMakeCtrl.dispose();
    destinationAddressCtrl.dispose();
    customerNameCtrl.dispose();
    customerPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      final results = await Future.wait([
        supabase.from('region').select('*'),
        supabase.from('logistics_orgs').select('*'),
        supabase.from('collection_stations').select('*'),
      ]);

      if (mounted) {
        setState(() {
          regions = List<Map<String, dynamic>>.from(results[0]);
          logisticsOrgs = List<Map<String, dynamic>>.from(results[1]);
          collectionStations = List<Map<String, dynamic>>.from(results[2]);
          isLoadingRegions = false;
          isLoadingLogistics = false;
          isLoadingStations = false;
        });
        if (selectedRegionId != null) {
          _fetchOrdersForRegion(selectedRegionId!);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingRegions = false;
          isLoadingLogistics = false;
          isLoadingStations = false;
        });
      }
    }
  }

  Future<void> _fetchOrdersForRegion(String regionId) async {
    setState(() {
      isLoadingOrders = true;
      if (!isEdit && widget.preselectedOrderId == null && primaryOrder == null) {
        selectedOrderIds.clear();
      }
      availableOrders.clear();
    });

    try {
      final queryParams = <String, dynamic>{
        'region_id': regionId,
        'limit': 50,
      };

      final currentStore = AppScopeService.currentStoreId;
      if (AppScopeService.activeScope == AppScope.vendor && currentStore != null) {
        queryParams['store_id'] = currentStore;
      }

      final response = await getIt<MedusaAdminV2>().orders.list(
        queryParameters: queryParams,
      );

      if (mounted) {
        final rawOrders = response.orders;
        final targetOrderId = primaryOrder?.id ?? widget.preselectedOrderId;

        final filtered = rawOrders.where((o) {
          // Exclude the primary order being dispatched
          if (targetOrderId != null && o.id == targetOrderId) {
            return false;
          }
          // Exclude canceled
          if (o.status == OrderStatus.canceled) {
            return false;
          }
          // Exclude fulfilled / shipped
          if (o.fulfillmentStatus == FulfillmentStatus.fulfilled || o.fulfillmentStatus == FulfillmentStatus.shipped) {
            return false;
          }
          // If in vendor scope, check store_id
          if (AppScopeService.activeScope == AppScope.vendor && currentStore != null) {
            final orderStoreId = o.metadata?['store_id']?.toString() ?? (o.metadata?['store'] is Map ? o.metadata!['store']['id']?.toString() : null);
            if (orderStoreId != null && orderStoreId != currentStore) {
              return false;
            }
          }
          return true;
        }).toList();

        setState(() {
          availableOrders = filtered;
          isLoadingOrders = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingOrders = false);
    }
  }

  String? _resolveCurrentVendorId() {
    try {
      final authState = context.read<AuthenticationBloc>().state;
      return authState.mapOrNull(loggedIn: (s) => s.user.id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedOrderIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one order to dispatch.')),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      final vendorId = _resolveCurrentVendorId() ?? 'usr_01J16HCWG0BRX883SXYFKFHJ81';

      final payload = <String, dynamic>{
        'region_id': selectedRegionId,
        'logistics_org_id': isIndependentDelivery
            ? null
            : (selectedLogisticsOrgId != null ? int.tryParse(selectedLogisticsOrgId!) : null),
        'origin_collection_station_id': isIndependentDelivery
            ? null
            : (selectedOriginStationId != null ? int.tryParse(selectedOriginStationId!) : null),
        'dest_collection_station_id': selectedDeliveryMode == 'pickup_station' && selectedDestStationId != null
            ? int.tryParse(selectedDestStationId!)
            : null,
        'dest_pickup_station_address': destinationAddressCtrl.text.trim().isNotEmpty
            ? destinationAddressCtrl.text.trim()
            : null,
        'order_ids': selectedOrderIds,
        'delivery_mode': selectedDeliveryMode,
        'route_category': selectedRouteCategory,
        'vehicle_type': selectedVehicleType,
        'vehicle_vin_or_plate': vehiclePlateCtrl.text.trim(),
        'vehicle_name_make_model_color': vehicleMakeCtrl.text.trim().isNotEmpty ? [vehicleMakeCtrl.text.trim()] : [],
        'driver_name': driverNameCtrl.text.trim(),
        'driver_phone': driverPhoneCtrl.text.trim(),
        'vendor_id': vendorId,
        'updated_at': DateTime.now().toIso8601String(),
        'metadata': {
          'fulfillment_type': isIndependentDelivery ? 'in_house' : 'third_party',
          'merchant_store_name': AppScopeService.displayName,
          if (customerNameCtrl.text.trim().isNotEmpty) 'customer_name': customerNameCtrl.text.trim(),
          if (customerPhoneCtrl.text.trim().isNotEmpty) 'customer_phone': customerPhoneCtrl.text.trim(),
          if (primaryOrder != null) ...{
            'primary_order_id': primaryOrder!.id,
            'primary_order_display_id': primaryOrder!.displayId,
          },
        },
      };

      if (isEdit) {
        await supabase
            .from('deliveries')
            .update(payload)
            .eq('id', widget.delivery!['id']);
      } else {
        payload['status'] = 'created';
        payload['created_at'] = DateTime.now().toIso8601String();
        await supabase.from('deliveries').insert(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndependentDelivery
                  ? 'In-house delivery run created successfully!'
                  : '3rd-Party logistics delivery dispatched!',
            ),
            backgroundColor: const Color(0xFF1B3A0A),
          ),
        );
        context.maybePop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save delivery dispatch: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final border = OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(12.0)),
      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
    );

    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(
          isEdit ? 'Edit Delivery Dispatch' : 'Direct Delivery Dispatch',
          style: GoogleFonts.comfortaa(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: isSaving ? null : _save,
            icon: isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                : const Icon(Icons.check, color: Color(0xFFE48629)),
            label: Text(
              'Save',
              style: TextStyle(
                color: isSaving ? Colors.grey : const Color(0xFFE48629),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Form(
            key: formKey,
            child: ListView(
              children: [
                // 1. Primary Dispatched Order Card (if preselected)
                if (primaryOrder != null || widget.preselectedOrderId != null)
                  _buildPrimaryOrderHeroCard(isDark),

                const Gap(14),

                // 2. Fulfillment Model Selector (In-House vs 3rd-Party)
                _buildFulfillmentModelCard(isDark),

                const Gap(14),

                // 3. Routing & Destination Card
                _buildRoutingCard(isDark, border),

                // 4. Logistics Partner (Only if 3rd-Party)
                if (!isIndependentDelivery) ...[
                  const Gap(14),
                  _buildThirdPartyPartnerCard(isDark, border),
                ],

                const Gap(14),

                // 5. Driver & Vehicle Details Card
                _buildDriverVehicleCard(isDark, border),

                const Gap(14),

                // 6. Orders Consolidation Card
                _buildOrderConsolidationCard(isDark),

                const Gap(24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryOrderHeroCard(bool isDark) {
    if (isFetchingPrimaryOrder) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFFE48629).withValues(alpha: 0.3)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator.adaptive(strokeWidth: 2)),
              Gap(12),
              Text('Loading order details...'),
            ],
          ),
        ),
      );
    }

    final ord = primaryOrder;
    final orderNum = ord?.displayId != null ? '#${ord!.displayId}' : (widget.preselectedOrderId ?? 'Order');
    final customerName = customerNameCtrl.text.isNotEmpty
        ? customerNameCtrl.text
        : (ord?.customerName ?? 'Customer');
    final customerPhone = customerPhoneCtrl.text;
    final totalFormatted = ord?.total != null
        ? '${(ord!.total! / 100).toStringAsFixed(2)} ${ord.currencyCode.toUpperCase()}'
        : '';
    final itemsCount = ord?.items?.length ?? 1;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B3A0A).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1B3A0A).withValues(alpha: 0.3),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1B3A0A).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 12,
                      backgroundColor: Color(0xFF1B3A0A),
                      child: Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.white),
                    ),
                    const Gap(8),
                    Text(
                      'Primary Dispatched Order $orderNum',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B3A0A),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE48629).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Active Run',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE48629),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Name & Phone
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF1B3A0A)),
                    const Gap(8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName.isNotEmpty && customerName != 'N/A' ? customerName : 'Customer',
                            style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (customerPhone.isNotEmpty) ...[
                            const Gap(2),
                            Row(
                              children: [
                                Text(
                                  customerPhone,
                                  style: context.bodySmall?.copyWith(color: Colors.grey.shade600),
                                ),
                                const Gap(8),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: customerPhone));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Customer phone copied to clipboard')),
                                    );
                                  },
                                  child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFFE48629)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (totalFormatted.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            totalFormatted,
                            style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF1B3A0A)),
                          ),
                          Text(
                            '$itemsCount item${itemsCount == 1 ? '' : 's'}',
                            style: context.bodySmall?.copyWith(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),
                  ],
                ),

                const Gap(10),
                const Divider(height: 1),
                const Gap(10),

                // Destination Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFFE48629)),
                    const Gap(8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Destination (Customer Doorstep)',
                            style: context.bodySmall?.copyWith(color: Colors.grey.shade600, fontSize: 11),
                          ),
                          const Gap(2),
                          Text(
                            destinationAddressCtrl.text.isNotEmpty
                                ? destinationAddressCtrl.text
                                : 'Address from order shipping details',
                            style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFulfillmentModelCard(bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.handshake_outlined, size: 20, color: Color(0xFF1B3A0A)),
                const Gap(8),
                Text('Delivery Fulfillment Model', style: context.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Gap(12),
            Row(
              children: [
                // In-House Option
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        isIndependentDelivery = true;
                        selectedLogisticsOrgId = null;
                        selectedOriginStationId = null;
                        if (driverNameCtrl.text.isEmpty) {
                          driverNameCtrl.text = 'In-House Courier';
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isIndependentDelivery
                            ? const Color(0xFF1B3A0A).withValues(alpha: 0.08)
                            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isIndependentDelivery ? const Color(0xFF1B3A0A) : Colors.grey.shade300,
                          width: isIndependentDelivery ? 1.8 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                color: isIndependentDelivery ? const Color(0xFF1B3A0A) : Colors.grey,
                                size: 22,
                              ),
                              if (isIndependentDelivery)
                                const Icon(Icons.check_circle, color: Color(0xFF1B3A0A), size: 18),
                            ],
                          ),
                          const Gap(8),
                          Text(
                            'In-House Delivery',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isIndependentDelivery ? const Color(0xFF1B3A0A) : null,
                            ),
                          ),
                          const Gap(2),
                          Text(
                            'Your own store rider / staff',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Gap(12),

                // 3rd-Party Partner Option
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        isIndependentDelivery = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !isIndependentDelivery
                            ? const Color(0xFFE48629).withValues(alpha: 0.08)
                            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !isIndependentDelivery ? const Color(0xFFE48629) : Colors.grey.shade300,
                          width: !isIndependentDelivery ? 1.8 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                Icons.local_shipping_rounded,
                                color: !isIndependentDelivery ? const Color(0xFFE48629) : Colors.grey,
                                size: 22,
                              ),
                              if (!isIndependentDelivery)
                                const Icon(Icons.check_circle, color: Color(0xFFE48629), size: 18),
                            ],
                          ),
                          const Gap(8),
                          Text(
                            '3rd-Party Fleet',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: !isIndependentDelivery ? const Color(0xFFE48629) : null,
                            ),
                          ),
                          const Gap(2),
                          Text(
                            'Logistics partner firm (SwiftAir, etc.)',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutingCard(bool isDark, OutlineInputBorder border) {
    final storeName = AppScopeService.displayName.isNotEmpty ? AppScopeService.displayName : 'Your Store';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route_rounded, size: 20, color: Color(0xFF1B3A0A)),
                const Gap(8),
                Text('Route & Destination', style: context.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Gap(14),

            // Origin Summary for In-House
            if (isIndependentDelivery) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.store, color: Color(0xFF1B3A0A), size: 20),
                    const Gap(10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dispatch Origin', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            '$storeName (Merchant Warehouse / Shop)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(14),
            ],

            // Region Dropdown
            Text('Region', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const Gap(6),
            isLoadingRegions
                ? const Center(child: CircularProgressIndicator.adaptive())
                : DropdownButtonFormField<String>(
                    style: context.bodyMedium,
                    decoration: InputDecoration(
                      enabledBorder: border,
                      border: border,
                      prefixIcon: const Icon(CupertinoIcons.globe),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    validator: (val) => val == null ? 'Region is required' : null,
                    hint: const Text('Select Region'),
                    initialValue: selectedRegionId,
                    items: regions.map((reg) {
                      return DropdownMenuItem<String>(
                        value: reg['id']?.toString(),
                        child: Text(reg['name']?.toString() ?? 'Unknown'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => selectedRegionId = val);
                      if (val != null) _fetchOrdersForRegion(val);
                    },
                  ),
            const Gap(14),

            // Route Category & Delivery Mode
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Route Scope', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const Gap(6),
                      DropdownButtonFormField<String>(
                        style: context.bodyMedium,
                        decoration: InputDecoration(
                          enabledBorder: border,
                          border: border,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        initialValue: selectedRouteCategory,
                        items: const [
                          DropdownMenuItem(value: 'intra_state', child: Text('Intra-State (Local)')),
                          DropdownMenuItem(value: 'inter_state', child: Text('Inter-State')),
                          DropdownMenuItem(value: 'international', child: Text('International')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => selectedRouteCategory = val);
                        },
                      ),
                    ],
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Delivery Mode', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const Gap(6),
                      DropdownButtonFormField<String>(
                        style: context.bodyMedium,
                        decoration: InputDecoration(
                          enabledBorder: border,
                          border: border,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        initialValue: selectedDeliveryMode,
                        items: const [
                          DropdownMenuItem(value: 'doorstep', child: Text('Doorstep Delivery')),
                          DropdownMenuItem(value: 'pickup_station', child: Text('Station Pickup')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => selectedDeliveryMode = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(14),

            // Customer Destination Address (Pre-filled from Order)
            if (selectedDeliveryMode == 'doorstep') ...[
              Text('Customer Delivery Address / Landmarks', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const Gap(6),
              TextFormField(
                controller: destinationAddressCtrl,
                maxLines: 2,
                validator: (val) => val == null || val.trim().isEmpty ? 'Destination delivery address is required' : null,
                decoration: InputDecoration(
                  hintText: 'e.g. 14 Admiralty Way, Lekki Phase 1, Lagos',
                  prefixIcon: const Icon(Icons.location_on_rounded),
                  enabledBorder: border,
                  border: border,
                ),
              ),
            ] else ...[
              Text('Destination Collection Station', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const Gap(6),
              DropdownButtonFormField<String>(
                style: context.bodyMedium,
                decoration: InputDecoration(
                  enabledBorder: border,
                  border: border,
                  prefixIcon: const Icon(Icons.move_to_inbox_rounded),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                hint: const Text('Select Destination Station'),
                initialValue: selectedDestStationId,
                items: collectionStations.map((station) {
                  return DropdownMenuItem<String>(
                    value: station['id']?.toString(),
                    child: Text(station['name']?.toString() ?? 'Station #${station['id']}'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedDestStationId = val),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThirdPartyPartnerCard(bool isDark, OutlineInputBorder border) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business_center_rounded, size: 20, color: Color(0xFFE48629)),
                const Gap(8),
                Text('Logistics Fleet Partner', style: context.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Gap(14),

            Text('Logistics Organization', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const Gap(6),
            isLoadingLogistics
                ? const Center(child: CircularProgressIndicator.adaptive())
                : DropdownButtonFormField<String>(
                    style: context.bodyMedium,
                    decoration: InputDecoration(
                      enabledBorder: border,
                      border: border,
                      prefixIcon: const Icon(CupertinoIcons.building_2_fill),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    hint: const Text('Select Partner Organization'),
                    initialValue: selectedLogisticsOrgId,
                    items: logisticsOrgs.map((org) {
                      return DropdownMenuItem<String>(
                        value: org['id']?.toString(),
                        child: Text(org['name']?.toString() ?? 'Partner #${org['id']}'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedLogisticsOrgId = val),
                  ),
            const Gap(14),

            Text('Origin Hub Station (Optional)', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const Gap(6),
            DropdownButtonFormField<String>(
              style: context.bodyMedium,
              decoration: InputDecoration(
                enabledBorder: border,
                border: border,
                prefixIcon: const Icon(Icons.outbox_rounded),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              hint: const Text('Select Origin Station (or direct vendor pickup)'),
              initialValue: selectedOriginStationId,
              items: collectionStations.map((station) {
                return DropdownMenuItem<String>(
                  value: station['id']?.toString(),
                  child: Text(station['name']?.toString() ?? 'Station #${station['id']}'),
                );
              }).toList(),
              onChanged: (val) => setState(() => selectedOriginStationId = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverVehicleCard(bool isDark, OutlineInputBorder border) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isIndependentDelivery ? Icons.two_wheeler_rounded : Icons.badge_rounded,
                  size: 20,
                  color: isIndependentDelivery ? const Color(0xFF1B3A0A) : const Color(0xFF2563EB),
                ),
                const Gap(8),
                Text(
                  isIndependentDelivery ? 'In-House Rider & Vehicle' : 'Driver & Vehicle Assignment',
                  style: context.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Gap(14),

            // Vehicle Type Selector Chips
            Text('Vehicle Type', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const Gap(8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: vehicleOptions.map((v) {
                  final isSelected = selectedVehicleType == v['type'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      avatar: Icon(v['icon'] as IconData, size: 16, color: isSelected ? Colors.white : Colors.grey),
                      label: Text(v['label'] as String, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF1B3A0A),
                      labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                      onSelected: (val) {
                        if (val) setState(() => selectedVehicleType = v['type'] as String);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const Gap(14),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: driverNameCtrl,
                    decoration: InputDecoration(
                      labelText: isIndependentDelivery ? 'Rider / Driver Name' : 'Driver Full Name',
                      hintText: isIndependentDelivery ? 'e.g. Musa / In-House' : null,
                      prefixIcon: const Icon(Icons.person_rounded),
                      enabledBorder: border,
                      border: border,
                    ),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: TextFormField(
                    controller: driverPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Driver Phone',
                      hintText: 'e.g. 08012345678',
                      prefixIcon: const Icon(Icons.phone_rounded),
                      enabledBorder: border,
                      border: border,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: vehiclePlateCtrl,
                    decoration: InputDecoration(
                      labelText: 'Plate / VIN #',
                      prefixIcon: const Icon(Icons.pin_rounded),
                      enabledBorder: border,
                      border: border,
                    ),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: TextFormField(
                    controller: vehicleMakeCtrl,
                    decoration: InputDecoration(
                      labelText: 'Make/Model/Color',
                      hintText: 'e.g. Boxer, Red',
                      prefixIcon: const Icon(Icons.color_lens_rounded),
                      enabledBorder: border,
                      border: border,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderConsolidationCard(bool isDark) {
    final isPrimaryMode = (primaryOrder != null || widget.preselectedOrderId != null);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPrimaryMode ? 'Bundle Additional Orders (Optional)' : 'Orders to Dispatch (${selectedOrderIds.length})',
                      style: context.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Gap(2),
                    Text(
                      isPrimaryMode
                          ? 'Bundle other pending orders in this region into this run'
                          : 'Select orders to include in this dispatch manifest',
                      style: context.bodySmall?.copyWith(color: Colors.grey.shade600, fontSize: 11),
                    ),
                  ],
                ),
                if (isLoadingOrders)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
              ],
            ),
            const Gap(12),

            if (selectedRegionId == null)
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text('Please select a region above to load pending orders.', style: TextStyle(color: Colors.grey)),
              )
            else if (isLoadingOrders)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator.adaptive(),
                ),
              )
            else if (availableOrders.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        isPrimaryMode
                            ? 'No additional pending orders in this region.'
                            : 'No pending orders ready for dispatch in this region.',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: availableOrders.map((order) {
                  final isSelected = selectedOrderIds.contains(order.id);
                  final customer = order.customerName;
                  final total = order.total != null
                      ? '${(order.total! / 100).toStringAsFixed(2)} ${order.currencyCode.toUpperCase()}'
                      : 'N/A';

                  return CheckboxListTile(
                    value: isSelected,
                    activeColor: const Color(0xFFE48629),
                    title: Text('Order #${order.displayId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Customer: $customer • Total: $total'),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          if (!selectedOrderIds.contains(order.id)) {
                            selectedOrderIds.add(order.id);
                          }
                        } else {
                          // Prevent unchecking the primary order
                          if (widget.preselectedOrderId != null && order.id == widget.preselectedOrderId) {
                            return;
                          }
                          selectedOrderIds.remove(order.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
