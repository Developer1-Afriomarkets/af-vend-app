import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medusa_admin/src/core/constants/colors.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/core/extensions/text_style_extension.dart';
import 'package:medusa_admin/src/core/routing/app_router.dart';
import 'package:medusa_admin/src/core/services/app_scope_service.dart';
import 'package:medusa_admin/src/features/auth/presentation/bloc/authentication/authentication_bloc.dart';
import 'package:medusa_admin/src/features/dashboard/presentation/widgets/scope_switcher_sheet.dart';

@RoutePage()
class DeliveriesView extends StatefulWidget {
  const DeliveriesView({super.key, this.isNested = false});
  final bool isNested;

  @override
  State<DeliveriesView> createState() => _DeliveriesViewState();
}

class _DeliveriesViewState extends State<DeliveriesView> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> deliveries = [];
  List<Map<String, dynamic>> filteredDeliveries = [];
  bool isLoading = true;
  String searchQuery = '';
  String selectedStatus = 'All';
  bool filterByMyStore = true;
  bool filterMyOrgOnly = true;
  bool filterAssignedToMe = true;

  @override
  void initState() {
    super.initState();
    filterByMyStore = (AppScopeService.activeScope == AppScope.vendor);
    _fetchDeliveries();
  }

  String? get _currentUserId {
    try {
      final authState = context.read<AuthenticationBloc>().state;
      return authState.maybeMap(
        loggedIn: (s) => s.user.id,
        orElse: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchDeliveries() async {
    setState(() => isLoading = true);
    try {
      final orgId = AppScopeService.currentLogisticsOrgId;
      final isLogistics = AppScopeService.activeScope == AppScope.logistics;
      final delQuery = (isLogistics && orgId != null && orgId.isNotEmpty)
          ? supabase.from('deliveries').select('*').eq('logistics_org_id', orgId).order('created_at', ascending: false)
          : supabase.from('deliveries').select('*').order('created_at', ascending: false);

      final results = await Future.wait([
        delQuery,
        supabase.from('region').select('id, name'),
        supabase.from('collection_stations').select('id, name, address'),
        supabase.from('logistics_orgs').select('id, name'),
      ]);

      final rawDeliveries = List<Map<String, dynamic>>.from(results[0]);
      final rawRegions = List<Map<String, dynamic>>.from(results[1]);
      final rawStations = List<Map<String, dynamic>>.from(results[2]);
      final rawOrgs = List<Map<String, dynamic>>.from(results[3]);

      final regionMap = {for (var r in rawRegions) r['id']?.toString(): r['name']?.toString()};
      final stationMap = {for (var s in rawStations) s['id']?.toString(): s['name']?.toString()};
      final orgMap = {for (var o in rawOrgs) o['id']?.toString(): o['name']?.toString()};

      for (var del in rawDeliveries) {
        final regId = del['region_id']?.toString();
        del['resolved_region_name'] = regionMap[regId] ?? 'N/A';

        final origId = del['origin_collection_station_id']?.toString();
        del['resolved_origin_station'] = stationMap[origId];

        final destId = del['dest_collection_station_id']?.toString();
        del['resolved_dest_station'] = stationMap[destId];

        final orgId = del['logistics_org_id']?.toString();
        del['resolved_org_name'] = orgMap[orgId];
      }

      if (mounted) {
        setState(() {
          deliveries = rawDeliveries;
          _applyFilters();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading deliveries: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    final activeScope = AppScopeService.activeScope;
    final myId = _currentUserId;

    setState(() {
      filteredDeliveries = deliveries.where((del) {
        final status = del['status']?.toString().toLowerCase() ?? '';
        bool matchesStatus = selectedStatus == 'All';
        if (!matchesStatus) {
          if (selectedStatus == 'Pending') {
            matchesStatus = (status == 'pending' || status == 'created');
          } else if (selectedStatus == 'Ongoing') {
            matchesStatus = (status == 'ongoing' || status == 'processing' || status == 'in_transit');
          } else if (selectedStatus == 'Completed') {
            matchesStatus = (status == 'completed' || status == 'delivered');
          } else {
            matchesStatus = (status == selectedStatus.toLowerCase());
          }
        }

        // Scope-based multitenancy filtering
        if (activeScope == AppScope.vendor) {
          if (filterByMyStore && myId != null) {
            final vendorId = del['vendor_id']?.toString();
            if (vendorId != myId) {
              return false;
            }
          }
        } else if (activeScope == AppScope.logistics) {
          if (filterMyOrgOnly) {
            final orgId = AppScopeService.currentLogisticsOrgId;
            final delOrgId = del['logistics_org_id']?.toString();
            // A logistics org must strictly see only deliveries assigned to its organization
            if (orgId != null && orgId.isNotEmpty) {
              if (delOrgId != orgId) {
                return false;
              }
            }
          }
        } else if (activeScope == AppScope.rider) {
          if (filterAssignedToMe && myId != null) {
            final driverId = del['driver']?.toString();
            final driverName = del['driver_name']?.toString().toLowerCase() ?? '';
            final myName = AppScopeService.displayName.toLowerCase();
            final isAssignedToMe = (driverId == myId) ||
                (myName.isNotEmpty && driverName.isNotEmpty && (driverName == myName || driverName.contains(myName) || myName.contains(driverName)));
            if (!isAssignedToMe) {
              return false;
            }
          }
        }

        final driverName = del['driver_name']?.toString().toLowerCase() ?? '';
        final vehicleInfo = del['vehicle_info']?.toString().toLowerCase() ?? '';
        final regionName = (del['resolved_region_name'] ?? '')?.toString().toLowerCase() ?? '';
        final orgName = (del['resolved_org_name'] ?? '')?.toString().toLowerCase() ?? '';

        final matchesSearch = searchQuery.isEmpty ||
            driverName.contains(searchQuery.toLowerCase()) ||
            vehicleInfo.contains(searchQuery.toLowerCase()) ||
            regionName.contains(searchQuery.toLowerCase()) ||
            orgName.contains(searchQuery.toLowerCase()) ||
            status.contains(searchQuery.toLowerCase());

        return matchesStatus && matchesSearch;
      }).toList();
    });
  }

  IconData _getVehicleIcon(String? vehicleType) {
    switch (vehicleType?.toLowerCase()) {
      case 'bike':
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'car':
      case 'sedan':
        return Icons.directions_car;
      case 'truck':
      case 'heavy truck':
        return Icons.local_shipping;
      case 'van':
      default:
        return Icons.airport_shuttle;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isNested) {
      return _buildContent(context);
    }

    return Scaffold(
      drawer: null,
      appBar: AppBar(
        title: const Text('Deliveries'),
        actions: [
          const ScopeBadge(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDeliveries,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.pushRoute(AddUpdateDeliveryRoute());
          if (result == true) {
            _fetchDeliveries();
          }
        },
        backgroundColor: const Color(0xFFE48629),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final smallTextStyle = context.bodySmall;
    final manatee = ColorManager.manatee;
    final activeScope = AppScopeService.activeScope;

    return Column(
      children: [
        // Scope & Filter bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              CupertinoSearchTextField(
                style: TextStyle(color: context.theme.textTheme.bodyLarge?.color),
                placeholder: 'Search driver, vehicle, partner, region...',
                onChanged: (val) {
                  searchQuery = val;
                  _applyFilters();
                },
              ),
              const Gap(8),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (activeScope == AppScope.vendor) ...[
                            ChoiceChip(
                              label: const Text('My Store'),
                              selected: filterByMyStore,
                              onSelected: (selected) {
                                setState(() {
                                  filterByMyStore = selected;
                                  _applyFilters();
                                });
                              },
                              avatar: const Icon(Icons.storefront, size: 14),
                            ),
                            const Gap(6),
                          ] else if (activeScope == AppScope.logistics) ...[
                            ChoiceChip(
                              label: const Text('My Org Fleet'),
                              selected: filterMyOrgOnly,
                              onSelected: (selected) {
                                setState(() {
                                  filterMyOrgOnly = selected;
                                  _applyFilters();
                                });
                              },
                              avatar: const Icon(Icons.business, size: 14),
                            ),
                            const Gap(6),
                          ] else if (activeScope == AppScope.rider) ...[
                            ChoiceChip(
                              label: const Text('Assigned to Me'),
                              selected: filterAssignedToMe,
                              onSelected: (selected) {
                                setState(() {
                                  filterAssignedToMe = selected;
                                  _applyFilters();
                                });
                              },
                              avatar: const Icon(Icons.person_pin, size: 14),
                            ),
                            const Gap(6),
                          ],
                          ...['All', 'Pending', 'Ongoing', 'Completed'].map((status) {
                            final isSelected = selectedStatus == status;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ChoiceChip(
                                label: Text(status),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      selectedStatus = status;
                                      _applyFilters();
                                    });
                                  }
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Deliveries List
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : filteredDeliveries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey),
                          const Gap(16),
                          Text('No deliveries found', style: context.bodyLarge),
                          const Gap(8),
                          Text(
                            selectedStatus != 'All'
                                ? 'Try changing the status filter'
                                : 'Tap the + button to dispatch a delivery run',
                            style: smallTextStyle?.copyWith(color: manatee),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      itemCount: filteredDeliveries.length,
                      separatorBuilder: (context, index) => const Gap(10),
                      itemBuilder: (context, index) {
                        final delivery = filteredDeliveries[index];
                        final rawStatus = delivery['status']?.toString().toUpperCase() ?? 'PENDING';
                        final status = (rawStatus == 'PROCESSING' || rawStatus == 'ONGOING')
                            ? 'IN TRANSIT'
                            : (rawStatus == 'CREATED')
                                ? 'PENDING'
                                : rawStatus;
                        final driverName = delivery['driver_name']?.toString() ?? 'Unassigned';
                        final driverPhone = delivery['driver_phone']?.toString();
                        final regionName = delivery['resolved_region_name']?.toString() ?? 'N/A';
                        final deliveryMode = delivery['delivery_mode']?.toString() ?? 'Standard';
                        final routeCategory = delivery['route_category']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'INTRA STATE';
                        final vehicleType = delivery['vehicle_type']?.toString() ?? 'Van';
                        final partnerName = delivery['resolved_org_name']?.toString();
                        final originStation = delivery['resolved_origin_station']?.toString();
                        final destStation = delivery['resolved_dest_station']?.toString();

                        final rawOrderIds = delivery['order_ids'];
                        int orderCount = 0;
                        if (rawOrderIds is List) {
                          orderCount = rawOrderIds.length;
                        } else if (rawOrderIds is String) {
                          if (rawOrderIds.startsWith('{') && rawOrderIds.endsWith('}')) {
                            orderCount = rawOrderIds.substring(1, rawOrderIds.length - 1).split(',').where((s) => s.trim().isNotEmpty).length;
                          } else {
                            try {
                              final decoded = jsonDecode(rawOrderIds);
                              if (decoded is List) orderCount = decoded.length;
                            } catch (_) {}
                            if (orderCount == 0 && rawOrderIds.trim().isNotEmpty) {
                              orderCount = 1;
                            }
                          }
                        }

                        DateTime? createdAt;
                        if (delivery['created_at'] != null) {
                          createdAt = DateTime.tryParse(delivery['created_at'].toString());
                        }
                        final dateString = createdAt != null
                            ? DateFormat.yMMMd().format(createdAt)
                            : 'N/A';

                        // Determine status badge colors
                        Color statusColor;
                        Color statusBgColor;
                        if (status == 'COMPLETED' || status == 'DELIVERED') {
                          statusColor = const Color(0xFF1B3A0A);
                          statusBgColor = const Color(0xFF1B3A0A).withValues(alpha: 0.12);
                        } else if (status == 'ONGOING' || status == 'PROCESSING' || status == 'IN TRANSIT') {
                          statusColor = Colors.blue.shade700;
                          statusBgColor = Colors.blue.withValues(alpha: 0.12);
                        } else {
                          statusColor = const Color(0xFFE48629);
                          statusBgColor = const Color(0xFFE48629).withValues(alpha: 0.12);
                        }

                        return Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            side: BorderSide(
                              color: statusColor.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16.0),
                            onTap: () async {
                              final result = await context.pushRoute(
                                DeliveriesDetailsRoute(deliveryId: delivery['id'].toString()),
                              );
                              if (result == true) {
                                _fetchDeliveries();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header: Status, Route category, Date
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusBgColor,
                                              borderRadius: BorderRadius.circular(8.0),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.0,
                                              ),
                                            ),
                                          ),
                                          const Gap(8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6.0),
                                            ),
                                            child: Text(
                                              routeCategory,
                                              style: TextStyle(
                                                fontSize: 10.0,
                                                fontWeight: FontWeight.w600,
                                                color: manatee,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        dateString,
                                        style: smallTextStyle?.copyWith(color: manatee),
                                      ),
                                    ],
                                  ),
                                  const Gap(12),

                                  // Driver & Vehicle
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: const Color(0xFFE48629).withValues(alpha: 0.15),
                                        child: Icon(_getVehicleIcon(vehicleType), size: 18, color: const Color(0xFFE48629)),
                                      ),
                                      const Gap(10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              driverName,
                                              style: context.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                            ),
                                            if (driverPhone != null && driverPhone.isNotEmpty)
                                              Text(
                                                driverPhone,
                                                style: smallTextStyle?.copyWith(color: manatee),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1B3A0A).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$orderCount Order${orderCount == 1 ? '' : 's'}',
                                          style: smallTextStyle?.copyWith(
                                            color: const Color(0xFF1B3A0A),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Stations route if present
                                  if (originStation != null || destStation != null) ...[
                                    const Gap(10),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.place_outlined, size: 14, color: Colors.grey),
                                          const Gap(4),
                                          Expanded(
                                            child: Text(
                                              '${originStation ?? 'Hub'} ➔ ${destStation ?? 'Destination'}',
                                              style: smallTextStyle?.copyWith(fontWeight: FontWeight.w500),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const Divider(height: 20, thickness: 0.8),

                                  // Footer
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          partnerName != null
                                              ? '$partnerName • $regionName'
                                              : '$deliveryMode • $regionName',
                                          style: smallTextStyle?.copyWith(color: manatee),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 13,
                                        color: manatee.withValues(alpha: 0.5),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
