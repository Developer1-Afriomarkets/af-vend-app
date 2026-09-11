import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';

class StationsAndPartnersTab extends StatefulWidget {
  const StationsAndPartnersTab({super.key});

  @override
  State<StationsAndPartnersTab> createState() => _StationsAndPartnersTabState();
}

class _StationsAndPartnersTabState extends State<StationsAndPartnersTab> {
  final supabase = Supabase.instance.client;
  int _selectedView = 0; // 0 = Stations, 1 = Partners
  bool _isLoading = true;
  String _searchQuery = '';

  List<Map<String, dynamic>> _stations = [];
  List<Map<String, dynamic>> _partners = [];
  Map<String, String> _regionNames = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        supabase.from('collection_stations').select('*').order('id', ascending: true),
        supabase.from('logistics_orgs').select('*').order('id', ascending: true),
        supabase.from('region').select('id, name'),
      ]);

      final rawStations = List<Map<String, dynamic>>.from(results[0]);
      final rawPartners = List<Map<String, dynamic>>.from(results[1]);
      final rawRegions = List<Map<String, dynamic>>.from(results[2]);

      final regMap = {for (var r in rawRegions) r['id']?.toString() ?? '': r['name']?.toString() ?? ''};

      if (mounted) {
        setState(() {
          _stations = rawStations;
          _partners = rawPartners;
          _regionNames = regMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stations & partners: $e')),
        );
      }
    }
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri.parse('tel:${phone.trim().replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: phone));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied $phone to clipboard')),
        );
      }
    }
  }

  Future<void> _sendEmail(String? email) async {
    if (email == null || email.trim().isEmpty) return;
    final uri = Uri.parse('mailto:${email.trim()}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    final filteredStations = _stations.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (s['name'] ?? '').toString().toLowerCase();
      final address = (s['address'] ?? '').toString().toLowerCase();
      final reg = (_regionNames[s['region_id']] ?? '').toLowerCase();
      return name.contains(q) || address.contains(q) || reg.contains(q);
    }).toList();

    final filteredPartners = _partners.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (p['name'] ?? '').toString().toLowerCase();
      final email = (p['contact_info']?['email'] ?? '').toString().toLowerCase();
      final phone = (p['contact_info']?['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || phone.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // Segmented Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedView = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedView == 0
                            ? const Color(0xFF1B3A0A)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedView == 0
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF1B3A0A).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.store_mall_directory_rounded,
                            size: 16,
                            color: _selectedView == 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                          const Gap(6),
                          Text(
                            'Collection Stations (${_stations.length})',
                            style: GoogleFonts.comfortaa(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedView == 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedView = 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedView == 1
                            ? const Color(0xFFE48629)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedView == 1
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFE48629).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_shipping_rounded,
                            size: 16,
                            color: _selectedView == 1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                          const Gap(6),
                          Text(
                            'Logistics Partners (${_partners.length})',
                            style: GoogleFonts.comfortaa(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedView == 1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),

          // Search Field
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: _selectedView == 0 ? 'Search stations, cities, regions...' : 'Search partners, phones, emails...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
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
          const Gap(16),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_selectedView == 0) ...[
            // Stations List
            if (filteredStations.isEmpty)
              _buildEmptyState('No collection stations found matching query.')
            else
              ...filteredStations.map((station) => _buildStationCard(station, isDark)),
          ] else ...[
            // Partners List
            if (filteredPartners.isEmpty)
              _buildEmptyState('No logistics partners found matching query.')
            else
              ...filteredPartners.map((partner) => _buildPartnerCard(partner, isDark)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 40, color: Colors.grey),
          const Gap(8),
          Text(message, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStationCard(Map<String, dynamic> station, bool isDark) {
    final regionName = _regionNames[station['region_id']] ?? 'Universal Region';
    final contact = station['contact_info'];
    final phone = contact is Map ? contact['phone']?.toString() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2419) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3D22) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B3A0A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.store_mall_directory_rounded,
                    color: Color(0xFF2E6B15),
                    size: 22,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station['name'] ?? 'Collection Station',
                        style: GoogleFonts.comfortaa(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Gap(2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE48629).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              regionName,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE48629),
                              ),
                            ),
                          ),
                          const Gap(6),
                          Text(
                            'Hub #${station['id']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFE48629)),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      station['address'] ?? 'Address on file',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: station['address'] ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address copied to clipboard')),
                      );
                    },
                    child: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (phone != null && phone.isNotEmpty) ...[
              const Gap(10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _makeCall(phone),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.phone_rounded, size: 15),
                    label: Text(phone, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerCard(Map<String, dynamic> partner, bool isDark) {
    final contact = partner['contact_info'];
    final email = contact is Map ? contact['email']?.toString() : null;
    final phone = contact is Map ? contact['phone']?.toString() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF221F18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3D3422) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE48629).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: Color(0xFFE48629),
                    size: 22,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partner['name'] ?? 'Logistics Organization',
                        style: GoogleFonts.comfortaa(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Gap(2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.verified_rounded, size: 10, color: Colors.green),
                                Gap(4),
                                Text(
                                  'Verified Partner',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Gap(6),
                          Text(
                            'Partner ID #${partner['id']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(14),
            Row(
              children: [
                if (phone != null && phone.isNotEmpty) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _makeCall(phone),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B3A0A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.call_rounded, size: 14),
                      label: Text(phone, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                if (email != null && email.isNotEmpty) ...[
                  if (phone != null && phone.isNotEmpty) const Gap(8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _sendEmail(email),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.email_outlined, size: 14),
                      label: Text(email, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
