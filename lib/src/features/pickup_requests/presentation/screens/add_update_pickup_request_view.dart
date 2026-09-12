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
import 'package:medusa_admin/src/core/services/app_scope_service.dart';

@RoutePage()
class AddUpdatePickupRequestView extends StatefulWidget {
  const AddUpdatePickupRequestView({
    super.key,
    this.pickupRequest,
    this.preselectedOrderId,
    this.preselectedRegionId,
  });

  final Map<String, dynamic>? pickupRequest;
  final String? preselectedOrderId;
  final String? preselectedRegionId;

  @override
  State<AddUpdatePickupRequestView> createState() => _AddUpdatePickupRequestViewState();
}

class _AddUpdatePickupRequestViewState extends State<AddUpdatePickupRequestView> {
  final supabase = Supabase.instance.client;
  final formKey = GlobalKey<FormState>();
  final noteCtrl = TextEditingController();

  List<Map<String, dynamic>> logisticsOrgs = [];
  List<Map<String, dynamic>> regions = [];
  List<Map<String, dynamic>> collectionStations = [];
  List<Order> availableOrders = [];

  String? selectedLogisticsOrgId;
  String? selectedRegionId;
  String? selectedCollectionStationId;
  List<String> selectedOrderIds = [];

  bool isPackaged = false;
  bool isLoadingLogistics = true;
  bool isLoadingRegions = true;
  bool isLoadingStations = true;
  bool isLoadingOrders = false;
  bool isSaving = false;

  bool get isEdit => widget.pickupRequest != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final req = widget.pickupRequest!;
      selectedLogisticsOrgId = req['logistics_org_id']?.toString();
      selectedRegionId = req['region_id']?.toString();
      selectedCollectionStationId = req['collection_station_id']?.toString();
      noteCtrl.text = req['note']?.toString() ?? '';
      isPackaged = req['packaged'] == true;

      final rawOrderIds = req['order_ids'];
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

    _fetchLogisticsOrgs();
    _fetchRegions();
    _fetchCollectionStations();
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLogisticsOrgs() async {
    try {
      final response = await supabase.from('logistics_orgs').select('*');
      if (mounted) {
        setState(() {
          logisticsOrgs = List<Map<String, dynamic>>.from(response);
          isLoadingLogistics = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingLogistics = false);
    }
  }

  Future<void> _fetchRegions() async {
    try {
      final response = await supabase.from('region').select('*');
      if (mounted) {
        setState(() {
          regions = List<Map<String, dynamic>>.from(response);
          isLoadingRegions = false;
        });
        if (selectedRegionId != null) {
          _fetchOrdersForRegion(selectedRegionId!);
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingRegions = false);
    }
  }

  Future<void> _fetchCollectionStations() async {
    try {
      final response = await supabase.from('collection_stations').select('*');
      if (mounted) {
        setState(() {
          collectionStations = List<Map<String, dynamic>>.from(response);
          isLoadingStations = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingStations = false);
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
        final filtered = rawOrders.where((o) {
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
        const SnackBar(content: Text('Please select at least one order for pickup.')),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      final vendorId = _resolveCurrentVendorId() ?? 'usr_01J16HCWG0BRX883SXYFKFHJ81';
      final payload = <String, dynamic>{
        'logistics_org_id': selectedLogisticsOrgId != null ? int.tryParse(selectedLogisticsOrgId!) : null,
        'collection_station_id': selectedCollectionStationId != null ? int.tryParse(selectedCollectionStationId!) : null,
        'region_id': selectedRegionId,
        'order_ids': selectedOrderIds,
        'note': noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
        'packaged': isPackaged,
        'processed': isPackaged,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isPackaged) {
        payload['packaged_at'] = DateTime.now().toIso8601String();
        payload['processed_at'] = DateTime.now().toIso8601String();
      }

      if (isEdit) {
        await supabase
            .from('pickup_requests')
            .update(payload)
            .eq('id', widget.pickupRequest!['id']);
      } else {
        payload['status'] = isPackaged ? 'packaged' : 'pending';
        payload['vendor_id'] = vendorId;
        payload['requested_at'] = DateTime.now().toIso8601String();
        payload['created_at'] = DateTime.now().toIso8601String();
        await supabase.from('pickup_requests').insert(payload);
      }

      if (mounted) {
        context.maybePop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save pickup request: $e')),
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

    final filteredStations = collectionStations.where((s) {
      if (selectedRegionId == null) return true;
      return s['region_id'] == selectedRegionId;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(
          isEdit ? 'Edit Pickup Request' : 'New Pickup Request',
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
                // Routing & Hub Card
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
                            const Icon(Icons.hub_rounded, size: 20, color: Color(0xFF1B3A0A)),
                            const Gap(8),
                            Text('Hub & Logistics Routing', style: context.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Gap(14),

                        // Region
                        Text('Target Region', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
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
                                  setState(() {
                                    selectedRegionId = val;
                                    selectedCollectionStationId = null;
                                  });
                                  if (val != null) _fetchOrdersForRegion(val);
                                },
                              ),
                        const Gap(14),

                        // Collection Station
                        Text('Drop-off / Collection Station', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const Gap(6),
                        isLoadingStations
                            ? const Center(child: CircularProgressIndicator.adaptive())
                            : DropdownButtonFormField<String>(
                                style: context.bodyMedium,
                                decoration: InputDecoration(
                                  enabledBorder: border,
                                  border: border,
                                  prefixIcon: const Icon(Icons.store_mall_directory_rounded),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                hint: const Text('Select Collection Hub Station'),
                                initialValue: selectedCollectionStationId,
                                items: filteredStations.map((station) {
                                  return DropdownMenuItem<String>(
                                    value: station['id']?.toString(),
                                    child: Text(station['name']?.toString() ?? 'Station #${station['id']}'),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => selectedCollectionStationId = val),
                              ),
                        const Gap(14),

                        // Logistics Organization
                        Text('Logistics Partner', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
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
                                hint: const Text('Select Logistics Partner'),
                                initialValue: selectedLogisticsOrgId,
                                items: logisticsOrgs.map((org) {
                                  return DropdownMenuItem<String>(
                                    value: org['id']?.toString(),
                                    child: Text(org['name']?.toString() ?? 'Unknown'),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => selectedLogisticsOrgId = val),
                              ),
                      ],
                    ),
                  ),
                ),
                const Gap(14),

                // Order Packaging Status Card
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
                            const Icon(Icons.inventory_2_rounded, size: 20, color: Color(0xFFE48629)),
                            const Gap(8),
                            Text('Packaging Readiness', style: context.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Gap(12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Items are Packaged & Ready', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Mark this if all order items are sealed and ready for rider pickup'),
                          activeTrackColor: const Color(0xFF1B3A0A),
                          value: isPackaged,
                          onChanged: (val) => setState(() => isPackaged = val),
                        ),
                        const Gap(10),
                        TextFormField(
                          controller: noteCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Rider Pickup Notes (Optional)',
                            hintText: 'e.g. Shop 14 Balogun Market, fragile box',
                            enabledBorder: border,
                            border: border,
                            prefixIcon: const Icon(Icons.notes_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(14),

                // Orders Selection Card
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
                              'Orders for Pickup (${selectedOrderIds.length})',
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
