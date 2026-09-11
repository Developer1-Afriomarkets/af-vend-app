import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medusa_admin/src/core/di/di.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/core/extensions/medusa_model_extension.dart';
import 'package:medusa_admin/src/core/routing/app_router.dart';
import 'package:medusa_admin_dart_client/medusa_admin_dart_client_v2.dart';

@RoutePage()
class PickupRequestsDetailsView extends StatefulWidget {
  const PickupRequestsDetailsView({super.key, required this.requestId});
  final String requestId;

  @override
  State<PickupRequestsDetailsView> createState() => _PickupRequestsDetailsViewState();
}

class _PickupRequestsDetailsViewState extends State<PickupRequestsDetailsView> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? request;
  Map<String, dynamic>? collectionStation;
  Map<String, dynamic>? logisticsOrg;
  List<Order> orders = [];
  bool isLoading = true;
  bool isLoadingOrders = true;
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    _fetchRequestDetails();
  }

  Future<void> _fetchRequestDetails() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('pickup_requests')
          .select('*')
          .eq('id', widget.requestId)
          .single();

      final regId = response['region_id']?.toString();
      if (regId != null && regId.isNotEmpty) {
        try {
          final regRes = await supabase.from('region').select('name').eq('id', regId).maybeSingle();
          if (regRes != null) {
            response['resolved_region_name'] = regRes['name']?.toString() ?? 'Universal';
          }
        } catch (_) {}
      }

      final logId = response['logistics_org_id']?.toString();
      if (logId != null && logId.isNotEmpty) {
        try {
          final logRes = await supabase.from('logistics_orgs').select('*').eq('id', logId).maybeSingle();
          if (logRes != null) {
            logisticsOrg = logRes;
            response['resolved_logistics_name'] = logRes['name']?.toString() ?? 'Afriomarkets Fleet';
          }
        } catch (_) {}
      }

      final stationId = response['collection_station_id']?.toString();
      if (stationId != null && stationId.isNotEmpty) {
        try {
          final stationRes = await supabase.from('collection_stations').select('*').eq('id', stationId).maybeSingle();
          if (stationRes != null) {
            collectionStation = stationRes;
            response['resolved_station_name'] = stationRes['name']?.toString() ?? 'Direct Hub';
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          request = response;
          isLoading = false;
        });
        _fetchOrders();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          isLoadingOrders = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load request: $e')),
        );
      }
    }
  }

  List<String> _parseOrderIds(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
      final cleaned = raw.replaceAll('{', '').replaceAll('}', '').replaceAll('"', '').trim();
      if (cleaned.isNotEmpty) {
        return cleaned.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }
    return [];
  }

  Future<void> _fetchOrders() async {
    final orderIds = _parseOrderIds(request?['order_ids']);
    if (orderIds.isEmpty) {
      if (mounted) setState(() => isLoadingOrders = false);
      return;
    }

    try {
      final List<Order> fetchedOrders = [];
      for (final id in orderIds) {
        try {
          final res = await getIt<MedusaAdminV2>().orders.retrieve(id);
          if (res.order != null) fetchedOrders.add(res.order!);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          orders = fetchedOrders;
          isLoadingOrders = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingOrders = false);
    }
  }

  Future<void> _updateStatus(String newStatus, {bool? markPackaged}) async {
    final req = request;
    if (req == null) return;

    setState(() => isUpdating = true);
    try {
      final updates = <String, dynamic>{
        'status': newStatus.toLowerCase(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (markPackaged == true) {
        updates['packaged'] = true;
        updates['processed'] = true;
        updates['packaged_at'] = DateTime.now().toIso8601String();
        updates['processed_at'] = DateTime.now().toIso8601String();
      }

      await supabase.from('pickup_requests').update(updates).eq('id', req['id']);

      setState(() {
        req['status'] = newStatus.toLowerCase();
        if (markPackaged == true) {
          req['packaged'] = true;
          req['processed'] = true;
        }
        isUpdating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.toUpperCase()}'),
            backgroundColor: const Color(0xFF1B3A0A),
          ),
        );
      }
    } catch (e) {
      setState(() => isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Future<void> _deleteRequest() async {
    final req = request;
    if (req == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pickup Request'),
        content: const Text('Are you sure you want to delete this pickup request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => isUpdating = true);
      try {
        await supabase.from('pickup_requests').delete().eq('id', req['id']);
        if (mounted) {
          context.maybePop(true);
        }
      } catch (e) {
        setState(() => isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete request: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final req = request;
    if (req == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: const Center(child: Text('Pickup request not found.')),
      );
    }

    final currentStatus = (req['status'] ?? 'pending').toString().toLowerCase();
    final isPackaged = req['packaged'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pickup Request #${req['id']}',
          style: GoogleFonts.comfortaa(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () async {
              final res = await context.pushRoute(AddUpdatePickupRequestRoute(pickupRequest: req));
              if (res == true) _fetchRequestDetails();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: isUpdating ? null : _deleteRequest,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          children: [
            // Lifecycle Stepper Card
            _buildLifecycleStepper(currentStatus, isDark),
            const Gap(14),

            // Operational Action Buttons Card
            _buildQuickActionButtons(currentStatus, isPackaged, isDark),
            const Gap(14),

            // Collection Hub Card
            if (collectionStation != null) ...[
              _buildStationCard(collectionStation!, isDark),
              const Gap(14),
            ],

            // Logistics Partner & Region Details
            _buildPartnerSummaryCard(req, isDark),
            const Gap(14),

            // Orders in this request
            _buildOrdersCard(isDark),
            const Gap(20),
          ],
        ),
      ),
    );
  }

  Widget _buildLifecycleStepper(String status, bool isDark) {
    final steps = ['pending', 'packaged', 'picked_up', 'at_station', 'completed'];
    final labels = ['Pending', 'Packaged', 'Picked Up', 'At Hub', 'Completed'];

    int activeIndex = steps.indexOf(status);
    if (activeIndex == -1) activeIndex = 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2419) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2E3D22) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pickup Progress',
            style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const Gap(14),
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                final stepIdx = index ~/ 2;
                final isDone = stepIdx < activeIndex;
                return Expanded(
                  child: Container(
                    height: 3,
                    color: isDone ? const Color(0xFF1B3A0A) : (isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                );
              } else {
                final stepIdx = index ~/ 2;
                final isPassed = stepIdx <= activeIndex;
                final isCurrent = stepIdx == activeIndex;

                return Column(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isPassed ? const Color(0xFF1B3A0A) : (isDark ? Colors.white10 : Colors.grey.shade200),
                        shape: BoxShape.circle,
                        border: isCurrent ? Border.all(color: const Color(0xFFE48629), width: 2) : null,
                      ),
                      child: Icon(
                        isPassed ? Icons.check : Icons.circle,
                        size: 13,
                        color: isPassed ? Colors.white : Colors.grey,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      labels[stepIdx],
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent
                            ? const Color(0xFFE48629)
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                );
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons(String status, bool isPackaged, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242017) : const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE48629).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.touch_app_rounded, color: Color(0xFFE48629), size: 18),
              Gap(8),
              Text(
                'Quick Actions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ],
          ),
          const Gap(10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!isPackaged)
                ElevatedButton.icon(
                  onPressed: isUpdating ? null : () => _updateStatus('packaged', markPackaged: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B3A0A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.inventory_2_rounded, size: 16),
                  label: const Text('Mark Packaged', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              if (status == 'pending' || status == 'packaged')
                OutlinedButton.icon(
                  onPressed: isUpdating ? null : () => _updateStatus('picked_up'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.local_shipping_rounded, size: 16, color: Color(0xFF2563EB)),
                  label: const Text('Confirm Pickup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              if (status == 'picked_up')
                OutlinedButton.icon(
                  onPressed: isUpdating ? null : () => _updateStatus('at_station'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.store_mall_directory_rounded, size: 16, color: Color(0xFF7C3AED)),
                  label: const Text('Arrived at Hub', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              if (status != 'completed')
                OutlinedButton.icon(
                  onPressed: isUpdating ? null : () => _updateStatus('completed'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.done_all_rounded, size: 16, color: Colors.green),
                  label: const Text('Mark Completed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStationCard(Map<String, dynamic> station, bool isDark) {
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
                const Icon(Icons.store_mall_directory_rounded, color: Color(0xFF1B3A0A), size: 20),
                const Gap(8),
                Text('Assigned Collection Hub', style: GoogleFonts.comfortaa(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const Gap(10),
            Text(station['name'] ?? 'Collection Station', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
            const Gap(4),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 15, color: Color(0xFFE48629)),
                const Gap(6),
                Expanded(child: Text(station['address'] ?? 'No address provided', style: const TextStyle(fontSize: 12))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerSummaryCard(Map<String, dynamic> req, bool isDark) {
    final note = req['note']?.toString();
    final logisticsName = req['resolved_logistics_name'] ?? 'Afriomarkets Fleet';
    final regionName = req['resolved_region_name'] ?? 'Universal';

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
                const Icon(Icons.info_outline_rounded, color: Color(0xFFE48629), size: 20),
                const Gap(8),
                Text('Request Summary', style: GoogleFonts.comfortaa(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const Gap(12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Logistics Partner:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(logisticsName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Operating Region:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(regionName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            if (note != null && note.isNotEmpty) ...[
              const Divider(height: 16),
              const Text('Rider Pickup Notes:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Gap(4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(note, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersCard(bool isDark) {
    final orderIds = _parseOrderIds(request?['order_ids']);
    final confirmations = request?['order_confirmations'];
    Map<String, dynamic> confMap = {};
    if (confirmations is List) {
      for (final c in confirmations) {
        if (c is Map && c['order_id'] != null) {
          confMap[c['order_id'].toString()] = c;
        }
      }
    }

    final totalCount = orderIds.isNotEmpty ? orderIds.length : orders.length;

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
                Text(
                  'Linked Orders ($totalCount)',
                  style: GoogleFonts.comfortaa(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (isLoadingOrders)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator.adaptive(strokeWidth: 2)),
              ],
            ),
            const Gap(12),
            if (orderIds.isEmpty && orders.isEmpty && !isLoadingOrders)
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text('No order records linked to this pickup request.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              )
            else if (orders.isNotEmpty)
              ...orders.map((order) {
                final total = order.total != null
                    ? '${(order.total! / 100).toStringAsFixed(2)} ${order.currencyCode.toUpperCase()}'
                    : 'N/A';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE48629).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFE48629), size: 18),
                  ),
                  title: Text('Order #${order.displayId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: Text('Customer: ${order.customerName} • $total', style: const TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                  onTap: () => context.pushRoute(OrderDetailsRoute(orderId: order.id)),
                );
              })
            else
              ...orderIds.map((id) {
                final conf = confMap[id];
                final isConfirmed = conf != null;
                final shortId = id.length > 12 ? id.substring(id.length - 10) : id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE48629).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFE48629), size: 18),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #$shortId',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Gap(2),
                            Text(
                              id,
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isConfirmed
                              ? const Color(0xFF1B3A0A).withValues(alpha: 0.12)
                              : Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isConfirmed ? 'CONFIRMED' : 'PACKAGED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isConfirmed ? const Color(0xFF1B3A0A) : Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const Gap(4),
                      IconButton(
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        onPressed: () => context.pushRoute(OrderDetailsRoute(orderId: id)),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
