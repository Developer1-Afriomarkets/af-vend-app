import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medusa_admin/src/core/di/di.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/core/extensions/text_style_extension.dart';
import 'package:medusa_admin/src/core/extensions/medusa_model_extension.dart';
import 'package:medusa_admin/src/features/auth/presentation/bloc/authentication/authentication_bloc.dart';
import 'package:medusa_admin_dart_client/medusa_admin_dart_client_v2.dart';

@RoutePage()
class AddUpdateDeliveryView extends StatefulWidget {
  const AddUpdateDeliveryView({
    super.key,
    this.delivery,
    this.preselectedOrderId,
    this.preselectedRegionId,
  });

  final Map<String, dynamic>? delivery;
  final String? preselectedOrderId;
  final String? preselectedRegionId;

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

  List<Map<String, dynamic>> regions = [];
  List<Map<String, dynamic>> logisticsOrgs = [];
  List<Map<String, dynamic>> collectionStations = [];
  List<Order> availableOrders = [];

  String? selectedRegionId;
  String? selectedLogisticsOrgId;
  String? selectedOriginStationId;
  String? selectedDestStationId;
  String selectedDeliveryMode = 'doorstep';
  String selectedRouteCategory = 'intra_state';
  String selectedVehicleType = 'bike';
  List<String> selectedOrderIds = [];

  bool isLoadingRegions = true;
  bool isLoadingLogistics = true;
  bool isLoadingStations = true;
  bool isLoadingOrders = false;
  bool isSaving = false;

  bool get isEdit => widget.delivery != null;

  final List<Map<String, dynamic>> vehicleOptions = [
    {'type': 'bike', 'label': 'Motorcycle / Bike', 'icon': Icons.two_wheeler_rounded},
    {'type': 'car', 'label': 'Car / Sedan', 'icon': Icons.directions_car_rounded},
    {'type': 'van', 'label': 'Delivery Van', 'icon': Icons.airport_shuttle_rounded},
    {'type': 'truck', 'label': 'Heavy Truck', 'icon': Icons.local_shipping_rounded},
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
      if (widget.preselectedOrderId != null) {
        selectedOrderIds = [widget.preselectedOrderId!];
      }
      if (widget.preselectedRegionId != null) {
        selectedRegionId = widget.preselectedRegionId;
      }
    }

    _fetchInitialData();
  }

  @override
  void dispose() {
    driverNameCtrl.dispose();
    driverPhoneCtrl.dispose();
    vehiclePlateCtrl.dispose();
    vehicleMakeCtrl.dispose();
    destinationAddressCtrl.dispose();
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
      if (!isEdit && widget.preselectedOrderId == null) {
        selectedOrderIds.clear();
      }
      availableOrders.clear();
    });

    try {
      final response = await getIt<MedusaAdminV2>().orders.list(
        queryParameters: {
          'region_id': regionId,
          'limit': 50,
        },
      );
      if (mounted) {
        setState(() {
          availableOrders = response.orders;
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
        'logistics_org_id': selectedLogisticsOrgId != null ? int.tryParse(selectedLogisticsOrgId!) : null,
        'origin_collection_station_id': selectedOriginStationId != null ? int.tryParse(selectedOriginStationId!) : null,
        'dest_collection_station_id': selectedDestStationId != null ? int.tryParse(selectedDestStationId!) : null,
        'dest_pickup_station_address': destinationAddressCtrl.text.trim().isNotEmpty ? destinationAddressCtrl.text.trim() : null,
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
        context.maybePop(true);
      }
    } catch (e) {
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save delivery dispatch: $e')),
      );
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
          isEdit ? 'Edit Delivery Dispatch' : 'New Delivery Dispatch',
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
                // Routing & Category Card
                Card(
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
                            Text('Route & Mode', style: context.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Gap(14),

                        // Region
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

                        // Route Category
                        Text('Route Category', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const Gap(6),
                        DropdownButtonFormField<String>(
                          style: context.bodyMedium,
                          decoration: InputDecoration(
                            enabledBorder: border,
                            border: border,
                            prefixIcon: const Icon(Icons.alt_route_rounded),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          initialValue: selectedRouteCategory,
                          items: const [
                            DropdownMenuItem(value: 'intra_state', child: Text('Intra-State (Within State / City)')),
                            DropdownMenuItem(value: 'inter_state', child: Text('Inter-State (Cross-State Transit)')),
                            DropdownMenuItem(value: 'international', child: Text('International / Cross-Border')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => selectedRouteCategory = val);
                          },
                        ),
                        const Gap(14),

                        // Delivery Mode
                        Text('Delivery Mode', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const Gap(6),
                        DropdownButtonFormField<String>(
                          style: context.bodyMedium,
                          decoration: InputDecoration(
                            enabledBorder: border,
                            border: border,
                            prefixIcon: const Icon(Icons.local_shipping_outlined),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          initialValue: selectedDeliveryMode,
                          items: const [
                            DropdownMenuItem(value: 'doorstep', child: Text('Doorstep Delivery to Customer')),
                            DropdownMenuItem(value: 'pickup_station', child: Text('Collection Station / Hub Pickup')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => selectedDeliveryMode = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(14),

                // Hubs & Partner Card
                Card(
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
                            const Icon(Icons.store_mall_directory_rounded, size: 20, color: Color(0xFFE48629)),
                            const Gap(8),
                            Text('Hubs & Fleet Partner', style: context.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Gap(14),

                        // Logistics Partner
                        Text('Logistics Partner Organization', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
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
                                hint: const Text('Select Partner (or Independent)'),
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

                        // Origin Station
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
                          hint: const Text('Select Origin Station'),
                          initialValue: selectedOriginStationId,
                          items: collectionStations.map((station) {
                            return DropdownMenuItem<String>(
                              value: station['id']?.toString(),
                              child: Text(station['name']?.toString() ?? 'Station #${station['id']}'),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => selectedOriginStationId = val),
                        ),
                        const Gap(14),

                        // Destination Station or Address
                        if (selectedDeliveryMode == 'pickup_station') ...[
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
                        ] else ...[
                          Text('Customer Delivery Address / Landmarks', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const Gap(6),
                          TextFormField(
                            controller: destinationAddressCtrl,
                            decoration: InputDecoration(
                              hintText: 'e.g. 14 Admiralty Way, Lekki Phase 1',
                              prefixIcon: const Icon(Icons.location_on_rounded),
                              enabledBorder: border,
                              border: border,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Gap(14),

                // Driver & Vehicle Fleet Card
                Card(
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
                            const Icon(Icons.badge_rounded, size: 20, color: Color(0xFF2563EB)),
                            const Gap(8),
                            Text('Driver & Vehicle Details', style: context.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                                  labelText: 'Driver Full Name',
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
                ),
                const Gap(14),

                // Order Picker Card
                Card(
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
                            Text(
                              'Orders to Dispatch (${selectedOrderIds.length})',
                              style: context.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
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
                        selectedRegionId == null
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text('Please select a region above to load pending orders.', style: TextStyle(color: Colors.grey)),
                              )
                            : isLoadingOrders
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: CircularProgressIndicator.adaptive(),
                                    ),
                                  )
                                : availableOrders.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: Text('No orders found for this region.'),
                                      )
                                    : Column(
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
                                                  selectedOrderIds.add(order.id);
                                                } else {
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
