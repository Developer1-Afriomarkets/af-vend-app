import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/core/routing/app_router.dart';
import 'package:medusa_admin/src/core/services/app_scope_service.dart';
import 'package:medusa_admin/src/features/auth/presentation/bloc/authentication/authentication_bloc.dart';

@RoutePage()
class PickupRequestsView extends StatefulWidget {
  const PickupRequestsView({super.key, this.isNested = false});
  final bool isNested;

  @override
  State<PickupRequestsView> createState() => _PickupRequestsViewState();
}

class _PickupRequestsViewState extends State<PickupRequestsView> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> pickupRequests = [];
  List<Map<String, dynamic>> filteredRequests = [];
  bool isLoading = true;
  String searchQuery = '';
  String selectedStatus = 'All';
  bool myStoreOnly = true;

  final List<String> statusFilterOptions = [
    'All',
    'Pending',
    'Packaged',
    'Processed',
    'Picked Up',
    'At Station',
    'Completed'
  ];

  @override
  void initState() {
    super.initState();
    _fetchPickupRequests();
  }

  String? _resolveCurrentVendorId() {
    try {
      final authState = context.read<AuthenticationBloc>().state;
      return authState.mapOrNull(loggedIn: (s) => s.user.id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchPickupRequests() async {
    setState(() => isLoading = true);
    try {
      final results = await Future.wait([
        supabase.from('pickup_requests').select('*').order('created_at', ascending: false),
        supabase.from('region').select('id, name'),
        supabase.from('logistics_orgs').select('id, name'),
        supabase.from('collection_stations').select('id, name, address'),
      ]);

      final rawRequests = List<Map<String, dynamic>>.from(results[0]);
      final rawRegions = List<Map<String, dynamic>>.from(results[1]);
      final rawLogistics = List<Map<String, dynamic>>.from(results[2]);
      final rawStations = List<Map<String, dynamic>>.from(results[3]);

      final regionMap = {for (var r in rawRegions) r['id']?.toString() ?? '': r['name']?.toString() ?? ''};
      final logisticsMap = {for (var l in rawLogistics) l['id']?.toString() ?? '': l['name']?.toString() ?? ''};
      final stationMap = {for (var s in rawStations) s['id']?.toString() ?? '': s['name']?.toString() ?? ''};

      for (var req in rawRequests) {
        final regId = req['region_id']?.toString() ?? '';
        final logId = req['logistics_org_id']?.toString() ?? '';
        final stationId = req['collection_station_id']?.toString() ?? '';

        req['resolved_region_name'] = regionMap[regId] ?? 'Universal';
        req['resolved_logistics_name'] = logisticsMap[logId] ?? 'Afriomarkets Fleet';
        req['resolved_station_name'] = stationMap[stationId] ?? 'Direct Hub';
      }

      if (mounted) {
        setState(() {
          pickupRequests = rawRequests;
          _applyFilters();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading pickup requests: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    final currentUserId = _resolveCurrentVendorId();
    final isVendorScope = AppScopeService.isVendor;

    setState(() {
      filteredRequests = pickupRequests.where((req) {
        // Vendor scope filter
        if (isVendorScope && myStoreOnly && currentUserId != null) {
          final reqVendor = req['vendor_id']?.toString();
          if (reqVendor != null && reqVendor != currentUserId) {
            return false;
          }
        }

        // Logistics scope filter
        if (AppScopeService.isLogistics) {
          final orgId = AppScopeService.currentLogisticsOrgId;
          if (orgId != null && orgId.isNotEmpty) {
            final reqOrg = req['logistics_org_id']?.toString();
            if (reqOrg != null && reqOrg.isNotEmpty && reqOrg != orgId) {
              return false;
            }
          }
        }

        // Status filter
        final status = (req['status'] ?? 'pending').toString().toLowerCase();
        final matchesStatus = selectedStatus == 'All' ||
            status == selectedStatus.toLowerCase().replaceAll(' ', '_') ||
            (selectedStatus == 'Packaged' && req['packaged'] == true);

        // Search query
        final logisticsName = (req['resolved_logistics_name'] ?? '').toString().toLowerCase();
        final stationName = (req['resolved_station_name'] ?? '').toString().toLowerCase();
        final regionName = (req['resolved_region_name'] ?? '').toString().toLowerCase();
        final reqId = req['id']?.toString().toLowerCase() ?? '';

        final matchesSearch = searchQuery.isEmpty ||
            logisticsName.contains(searchQuery.toLowerCase()) ||
            stationName.contains(searchQuery.toLowerCase()) ||
            regionName.contains(searchQuery.toLowerCase()) ||
            status.contains(searchQuery.toLowerCase()) ||
            reqId.contains(searchQuery.toLowerCase());

        return matchesStatus && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isNested) {
      return _buildContent(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Pickup Requests', style: GoogleFonts.comfortaa(fontWeight: FontWeight.bold)),
      ),
      body: _buildContent(context),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      heroTag: 'create_pickup_request_fab',
      onPressed: () async {
        final res = await context.pushRoute(AddUpdatePickupRequestRoute());
        if (res == true) _fetchPickupRequests();
      },
      backgroundColor: const Color(0xFFE48629),
      elevation: 4,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: Text(
        'New Request',
        style: GoogleFonts.comfortaa(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isDark = context.isDark;

    return RefreshIndicator(
      onRefresh: _fetchPickupRequests,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            children: [
              // Search & Scope Filter Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) {
                        searchQuery = val;
                        _applyFilters();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search requests, hubs, partners...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
                        ),
                      ),
                    ),
                  ),
                  if (AppScopeService.isVendor) ...[
                    const Gap(8),
                    FilterChip(
                      label: Text(myStoreOnly ? 'My Store' : 'All Stores', style: const TextStyle(fontSize: 11.5)),
                      selected: myStoreOnly,
                      selectedColor: const Color(0xFF1B3A0A).withValues(alpha: 0.18),
                      checkmarkColor: const Color(0xFF1B3A0A),
                      onSelected: (val) {
                        setState(() {
                          myStoreOnly = val;
                          _applyFilters();
                        });
                      },
                    ),
                  ],
                ],
              ),
              const Gap(10),

              // Status Filter Chips Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: statusFilterOptions.map((status) {
                    final isSelected = selectedStatus == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(status, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        selected: isSelected,
                        selectedColor: const Color(0xFFE48629),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                        onSelected: (val) {
                          setState(() {
                            selectedStatus = status;
                            _applyFilters();
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Gap(12),

              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (filteredRequests.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                      const Gap(12),
                      Text(
                        'No pickup requests found.',
                        style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const Gap(4),
                      const Text(
                        'Create a new pickup request or adjust your filters.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ...filteredRequests.map((req) => _buildRequestCard(req, isDark)),
              const Gap(70), // Bottom padding for FAB
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: _buildFab(),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req, bool isDark) {
    final reqId = req['id']?.toString() ?? '';
    final status = (req['status'] ?? 'pending').toString().toLowerCase();
    final isPackaged = req['packaged'] == true;
    final stationName = req['resolved_station_name'] ?? 'Direct Hub';
    final logisticsName = req['resolved_logistics_name'] ?? 'Afriomarkets Fleet';
    final regionName = req['resolved_region_name'] ?? 'Universal';
    final rawOrderIds = req['order_ids'];
    int orderCount = 0;
    if (rawOrderIds is List) {
      orderCount = rawOrderIds.length;
    } else if (rawOrderIds is String) {
      try {
        final decoded = jsonDecode(rawOrderIds);
        if (decoded is List) orderCount = decoded.length;
      } catch (_) {}
      if (orderCount == 0) {
        final cleaned = rawOrderIds.replaceAll('{', '').replaceAll('}', '').replaceAll('"', '').trim();
        if (cleaned.isNotEmpty) {
          orderCount = cleaned.split(',').where((e) => e.trim().isNotEmpty).length;
        }
      }
    }

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'packaged':
        statusColor = const Color(0xFF2E6B15);
        statusLabel = 'PACKAGED';
        break;
      case 'picked_up':
        statusColor = const Color(0xFF2563EB);
        statusLabel = 'PICKED UP';
        break;
      case 'at_station':
        statusColor = const Color(0xFF7C3AED);
        statusLabel = 'AT STATION';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'COMPLETED';
        break;
      default:
        statusColor = const Color(0xFFE48629);
        statusLabel = 'PENDING';
    }

    String formattedDate = '';
    if (req['created_at'] != null) {
      try {
        final dt = DateTime.parse(req['created_at']);
        formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
      } catch (_) {}
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF2E3D22) : Colors.grey.shade200),
      ),
      color: isDark ? const Color(0xFF1E2419) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final res = await context.pushRoute(PickupRequestsDetailsRoute(requestId: reqId));
          if (res == true) _fetchPickupRequests();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: ID, Badge, Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B3A0A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF2E6B15), size: 18),
                      ),
                      const Gap(10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Request #$reqId',
                            style: GoogleFonts.comfortaa(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          if (formattedDate.isNotEmpty)
                            Text(
                              formattedDate,
                              style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white54 : Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              const Gap(14),

              // Hub & Partner Information
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.store_mall_directory_rounded, size: 16, color: Color(0xFFE48629)),
                    const Gap(6),
                    Expanded(
                      child: Text(
                        stationName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        logisticsName,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(10),

              // Footer: Region & Packaging & Orders Count
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE48629).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      regionName,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFE48629)),
                    ),
                  ),
                  const Gap(8),
                  if (isPackaged)
                    Row(
                      children: const [
                        Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                        Gap(3),
                        Text('Packaged', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
                      ],
                    )
                  else
                    Row(
                      children: const [
                        Icon(Icons.pending_actions_rounded, size: 14, color: Color(0xFFE48629)),
                        Gap(3),
                        Text('Packaging Pending', style: TextStyle(fontSize: 11, color: Color(0xFFE48629))),
                      ],
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$orderCount Orders',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
