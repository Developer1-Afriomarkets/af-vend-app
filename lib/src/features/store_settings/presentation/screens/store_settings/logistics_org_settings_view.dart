import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/core/extensions/snack_bar_extension.dart';
import 'package:medusa_admin/src/core/services/app_scope_service.dart';

class LogisticsOrgSettingsView extends StatefulWidget {
  const LogisticsOrgSettingsView({super.key});

  @override
  State<LogisticsOrgSettingsView> createState() => _LogisticsOrgSettingsViewState();
}

class _LogisticsOrgSettingsViewState extends State<LogisticsOrgSettingsView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _cacCtrl = TextEditingController();
  final _tinCtrl = TextEditingController();

  // Fleet
  final _vansCtrl = TextEditingController(text: '0');
  final _bikesCtrl = TextEditingController(text: '0');
  final _trucksCtrl = TextEditingController(text: '0');

  String _selectedSla = 'same_day';
  bool _isActive = true;
  List<String> _coverageZones = [];
  final _zoneInputCtrl = TextEditingController();

  String? _orgId;

  @override
  void initState() {
    super.initState();
    _loadOrgData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _regionCtrl.dispose();
    _contactPersonCtrl.dispose();
    _cacCtrl.dispose();
    _tinCtrl.dispose();
    _vansCtrl.dispose();
    _bikesCtrl.dispose();
    _trucksCtrl.dispose();
    _zoneInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrgData() async {
    setState(() => _isLoading = true);
    try {
      final orgId = AppScopeService.currentLogisticsOrgId;
      _orgId = orgId;

      if (orgId == null || orgId.isEmpty) {
        final meta = AppScopeService.cachedMetadata ?? {};
        _nameCtrl.text = (meta['logistics_org_name'] ?? meta['company_name'] ?? 'Swift Air').toString();
        _emailCtrl.text = (meta['email'] ?? '').toString();
        _phoneCtrl.text = (meta['phone'] ?? '').toString();
        _regionCtrl.text = (meta['region'] ?? 'Lagos').toString();
        setState(() => _isLoading = false);
        return;
      }

      final res = await _supabase.from('logistics_orgs').select('*').eq('id', orgId).maybeSingle();
      if (res != null) {
        _nameCtrl.text = (res['name'] ?? '').toString();
        final contact = res['contact_info'] is Map ? res['contact_info'] as Map<String, dynamic> : <String, dynamic>{};
        _emailCtrl.text = (contact['email'] ?? '').toString();
        _phoneCtrl.text = (contact['phone'] ?? '').toString();
        _addressCtrl.text = (contact['address'] ?? '').toString();
        _regionCtrl.text = (contact['region'] ?? 'Lagos').toString();
        _contactPersonCtrl.text = (contact['contact_person'] ?? '').toString();
        _cacCtrl.text = (contact['cac_number'] ?? contact['rc_number'] ?? '').toString();
        _tinCtrl.text = (contact['tin'] ?? '').toString();
        _selectedSla = (contact['delivery_sla'] ?? 'same_day').toString();
        _isActive = contact['is_active'] != false;

        final fleet = contact['fleet_summary'];
        if (fleet is Map) {
          _vansCtrl.text = (fleet['vans'] ?? 0).toString();
          _bikesCtrl.text = (fleet['bikes'] ?? 0).toString();
          _trucksCtrl.text = (fleet['trucks'] ?? 0).toString();
        }

        final zones = contact['coverage_zones'];
        if (zones is List) {
          _coverageZones = zones.map((e) => e.toString()).toList();
        } else {
          _coverageZones = ['Ikeja', 'Victoria Island', 'Lekki', 'Surulere', 'Yaba'];
        }
      }
    } catch (e) {
      debugPrint('Error loading org: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveOrgData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final vans = int.tryParse(_vansCtrl.text.trim()) ?? 0;
      final bikes = int.tryParse(_bikesCtrl.text.trim()) ?? 0;
      final trucks = int.tryParse(_trucksCtrl.text.trim()) ?? 0;

      final contactInfo = {
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'region': _regionCtrl.text.trim(),
        'contact_person': _contactPersonCtrl.text.trim(),
        'cac_number': _cacCtrl.text.trim(),
        'tin': _tinCtrl.text.trim(),
        'delivery_sla': _selectedSla,
        'is_active': _isActive,
        'coverage_zones': _coverageZones,
        'fleet_summary': {
          'vans': vans,
          'bikes': bikes,
          'trucks': trucks,
          'total': vans + bikes + trucks,
        },
      };

      final updatedName = _nameCtrl.text.trim();
      final orgId = _orgId ?? AppScopeService.currentLogisticsOrgId;

      if (orgId != null && orgId.isNotEmpty) {
        await _supabase.from('logistics_orgs').update({
          'name': updatedName,
          'contact_info': contactInfo,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orgId);
      }

      final meta = AppScopeService.cachedMetadata ?? {};
      meta['logistics_org_name'] = updatedName;
      meta['company_name'] = updatedName;
      await AppScopeService.setUserMetadata(meta);

      if (mounted) {
        context.showSnackBar('Organization Profile & Affairs saved successfully!');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to save changes: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addZone() {
    final text = _zoneInputCtrl.text.trim();
    if (text.isNotEmpty && !_coverageZones.contains(text)) {
      setState(() {
        _coverageZones.add(text);
        _zoneInputCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Logistics Org Affairs',
          style: GoogleFonts.comfortaa(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (AppScopeService.isLogisticsAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _saveOrgData,
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
              label: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  if (!AppScopeService.isLogisticsAdmin) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 22),
                          Gap(10),
                          Expanded(
                            child: Text(
                              'Staff Member Access (Read-Only): Organization affairs, coverage areas, and payout accounts are managed exclusively by the fleet administrator.',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF0284C7), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF064E3B), Color(0xFF022C22)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.building2, color: Color(0xFF6EE7B7), size: 24),
                        ),
                        const Gap(14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Logistics Partner',
                                style: GoogleFonts.comfortaa(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                _orgId != null ? 'Registered Hub ID: #$_orgId' : 'Partner Organization',
                                style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _isActive ? 'ACTIVE' : 'PAUSED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _isActive ? const Color(0xFF10B981) : Colors.orangeAccent,
                              ),
                            ),
                            Switch(
                              value: _isActive,
                              activeThumbColor: const Color(0xFF10B981),
                              onChanged: (val) => setState(() => _isActive = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Gap(20),

                  _buildSectionHeader('Corporate Identity & Registration', LucideIcons.shieldCheck),
                  _buildCard(
                    isDark,
                    [
                      _buildTextField(
                        controller: _nameCtrl,
                        label: 'Organization / Company Name',
                        hint: 'e.g. Swift Air Logistics',
                        icon: LucideIcons.building,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Company name is required' : null,
                      ),
                      const Gap(12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cacCtrl,
                              label: 'CAC / RC Number',
                              hint: 'RC-1849204',
                              icon: LucideIcons.fileText,
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: _buildTextField(
                              controller: _tinCtrl,
                              label: 'Tax ID (TIN)',
                              hint: 'Optional',
                              icon: LucideIcons.receipt,
                            ),
                          ),
                        ],
                      ),
                      const Gap(12),
                      _buildTextField(
                        controller: _contactPersonCtrl,
                        label: 'Lead Operations Contact Person',
                        hint: 'e.g. Head of Dispatch',
                        icon: LucideIcons.userCheck,
                      ),
                    ],
                  ),

                  const Gap(20),

                  _buildSectionHeader('Depot & Communication Channels', LucideIcons.phoneCall),
                  _buildCard(
                    isDark,
                    [
                      _buildTextField(
                        controller: _emailCtrl,
                        label: 'Official Operations Email',
                        hint: 'dispatch@swiftair.com',
                        icon: LucideIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const Gap(12),
                      _buildTextField(
                        controller: _phoneCtrl,
                        label: 'Dispatch Hotline Phone',
                        hint: '+234 800 000 0000',
                        icon: LucideIcons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      const Gap(12),
                      _buildTextField(
                        controller: _addressCtrl,
                        label: 'Central Depot / Sorting Hub Address',
                        hint: 'e.g. 12 Airport Road, Ikeja',
                        icon: LucideIcons.mapPin,
                      ),
                      const Gap(12),
                      _buildTextField(
                        controller: _regionCtrl,
                        label: 'Primary Operating State / Jurisdiction',
                        hint: 'e.g. Lagos State',
                        icon: LucideIcons.globe,
                      ),
                    ],
                  ),

                  const Gap(20),

                  _buildSectionHeader('Delivery SLA & Coverage Localities', LucideIcons.clock),
                  _buildCard(
                    isDark,
                    [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedSla,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Guaranteed Delivery SLA',
                          prefixIcon: const Icon(LucideIcons.timer, size: 18, color: Color(0xFF059669)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'same_day', child: Text('Same-Day Delivery Guarantee', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'next_day', child: Text('Next-Day Standard Delivery', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'express_3h', child: Text('Express 3-Hour Rapid Dispatch', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'scheduled', child: Text('Scheduled Timed Drops', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedSla = val);
                        },
                      ),
                      const Gap(16),
                      Text(
                        'Active Coverage Zones & Localities',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                      const Gap(8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _coverageZones.map((z) {
                          return Chip(
                            label: Text(z, style: const TextStyle(fontSize: 12)),
                            backgroundColor: const Color(0xFF059669).withValues(alpha: 0.12),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setState(() => _coverageZones.remove(z));
                            },
                          );
                        }).toList(),
                      ),
                      const Gap(10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _zoneInputCtrl,
                              decoration: InputDecoration(
                                hintText: 'Add locality (e.g. Ikoyi)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              onSubmitted: (_) => _addZone(),
                            ),
                          ),
                          const Gap(8),
                          IconButton.filled(
                            onPressed: _addZone,
                            icon: const Icon(Icons.add),
                            style: IconButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Gap(20),

                  _buildSectionHeader('Active Fleet Composition', LucideIcons.truck),
                  _buildCard(
                    isDark,
                    [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _bikesCtrl,
                              label: 'Motorcycles',
                              hint: '0',
                              icon: Icons.two_wheeler_rounded,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: _buildTextField(
                              controller: _vansCtrl,
                              label: 'Delivery Vans',
                              hint: '0',
                              icon: Icons.airport_shuttle_rounded,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: _buildTextField(
                              controller: _trucksCtrl,
                              label: 'Heavy Trucks',
                              hint: '0',
                              icon: Icons.local_shipping_rounded,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Gap(32),

                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveOrgData,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _isSaving ? 'Saving Changes...' : 'Save Organization Affairs',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                  ),

                  const Gap(40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF059669)),
          const Gap(8),
          Text(
            title,
            style: GoogleFonts.comfortaa(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(bool isDark, List<Widget> children) {
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
          children: children,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF059669)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
