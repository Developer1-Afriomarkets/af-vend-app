import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medusa_admin/src/core/constants/colors.dart';
import 'package:medusa_admin/src/core/extensions/text_style_extension.dart';
import 'package:medusa_admin/src/core/services/app_scope_service.dart';

@RoutePage()
class LogisticsOnboardingWizardView extends StatefulWidget {
  const LogisticsOnboardingWizardView({super.key});

  @override
  State<LogisticsOnboardingWizardView> createState() => _LogisticsOnboardingWizardViewState();
}

class _LogisticsOnboardingWizardViewState extends State<LogisticsOnboardingWizardView> {
  final supabase = Supabase.instance.client;
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Form Controllers - Step 1
  final _orgNameCtrl = TextEditingController();
  final _regNumberCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Step 2 - Coverage & Hub
  String _selectedRegionId = 'reg_nigeria_central';
  String _selectedRegionName = 'Nigeria (Lagos / Nationwide)';
  bool _isCreatingNewHub = true; // true = own hub, false = partner with existing
  String? _selectedStationId;

  final _hubNameCtrl = TextEditingController(text: 'Main Sorting Depot');
  final _hubAddressCtrl = TextEditingController();
  final _hubCityCtrl = TextEditingController();
  final _hubPhoneCtrl = TextEditingController();
  final _customZoneCtrl = TextEditingController();

  final List<String> _selectedCoverageZones = [
    'Lagos (Mainland)',
    'Lagos (Island)',
    'Abuja (FCT)',
  ];

  final Map<String, List<String>> _regionSuggestedZones = {
    'reg_nigeria_central': [
      'Lagos (Mainland)',
      'Lagos (Island)',
      'Abuja (FCT)',
      'Port Harcourt',
      'Ibadan',
      'Kano',
      'Enugu',
      'Nationwide Line-Haul',
    ],
    'reg_ghana_central': [
      'Greater Accra',
      'Kumasi (Ashanti)',
      'Tema Port Zone',
      'Takoradi',
      'Tamale',
      'Cape Coast',
    ],
    'reg_uk_central': [
      'Greater London',
      'Birmingham',
      'Manchester',
      'Leeds',
      'Nationwide Express',
    ],
    'reg_kenya_central': [
      'Nairobi County',
      'Mombasa',
      'Kisumu',
      'Nakuru',
      'Eldoret',
    ],
  };

  // Step 3
  int _bikeCount = 4;
  int _vanCount = 2;
  int _truckCount = 0;
  String _deliverySla = 'same_day';

  List<Map<String, dynamic>> _availableStations = [];
  bool _isLoadingStations = true;

  @override
  void initState() {
    super.initState();
    _fetchCollectionStations();
  }

  Future<void> _fetchCollectionStations() async {
    try {
      final res = await supabase.from('collection_stations').select('*').order('id');
      if (mounted) {
        setState(() {
          _availableStations = List<Map<String, dynamic>>.from(res);
          if (_availableStations.isNotEmpty) {
            _selectedStationId = _availableStations.first['id'].toString();
          }
          _isLoadingStations = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStations = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _orgNameCtrl.dispose();
    _regNumberCtrl.dispose();
    _contactPersonCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _hubNameCtrl.dispose();
    _hubAddressCtrl.dispose();
    _hubCityCtrl.dispose();
    _hubPhoneCtrl.dispose();
    _customZoneCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_orgNameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide Organization Name and Phone Number')),
        );
        return;
      }
    }
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitOnboarding() async {
    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'name': _orgNameCtrl.text.trim(),
        'contact_person': _contactPersonCtrl.text.trim().isNotEmpty
            ? _contactPersonCtrl.text.trim()
            : 'Operations Lead',
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        'region': _selectedRegionName,
        'coverage_zones': _selectedCoverageZones,
        'delivery_sla': _deliverySla,
        'fleet_summary': {
          'bikes': _bikeCount,
          'vans': _vanCount,
          'trucks': _truckCount,
        },
      };

      // 1. Insert into logistics_orgs
      final orgRes = await supabase.from('logistics_orgs').insert(payload).select().maybeSingle();
      final orgId = orgRes?['id']?.toString();

      // 2. If creating their own hub, register it into collection_stations so it becomes immediately usable
      if (_isCreatingNewHub && _hubNameCtrl.text.trim().isNotEmpty) {
        try {
          await supabase.from('collection_stations').insert({
            'name': _hubNameCtrl.text.trim(),
            'address': _hubAddressCtrl.text.trim().isNotEmpty ? _hubAddressCtrl.text.trim() : 'Central Depot Address',
            'city': _hubCityCtrl.text.trim().isNotEmpty ? _hubCityCtrl.text.trim() : _selectedRegionName,
            'phone': _hubPhoneCtrl.text.trim().isNotEmpty ? _hubPhoneCtrl.text.trim() : _phoneCtrl.text.trim(),
            'org_id': orgId,
            'is_hub': true,
          });
        } catch (e) {
          debugPrint('[LogisticsOnboarding] Station insert fallback: $e');
        }
      }

      // 3. Switch active scope to logistics
      await AppScopeService.addAllowedScope(AppScope.logistics, switchToNewScope: true);

      if (mounted) {
        setState(() => _isSubmitting = false);
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF1B3A0A)),
                Gap(8),
                Text('Onboarding Complete!'),
              ],
            ),
            content: Text(
              '${_orgNameCtrl.text.trim()} has been registered with the Afrio Logistics Grid.'
              'Your operational scope has been set to Logistics Hub & Dispatch.',
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B3A0A)),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.maybePop();
                },
                child: const Text('Go to Logistics Hub'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Onboarding failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Organization & Identity',
      'Hub & Coverage',
      'Fleet & Capacity',
      'Review & Activate',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logistics Onboarding'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              _prevStep();
            } else {
              context.maybePop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stepper indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  Row(
                    children: List.generate(4, (index) {
                      final isPassed = index <= _currentStep;
                      return Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: isPassed
                                  ? const Color(0xFFE48629)
                                  : Colors.grey.withValues(alpha: 0.3),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isPassed ? Colors.white : Colors.grey,
                                ),
                              ),
                            ),
                            if (index < 3)
                              Expanded(
                                child: Container(
                                  height: 2,
                                  color: index < _currentStep
                                      ? const Color(0xFFE48629)
                                      : Colors.grey.withValues(alpha: 0.3),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                  const Gap(8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Step ${_currentStep + 1} of 4: ${titles[_currentStep]}',
                      style: context.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1B3A0A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Wizard Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Identity(),
                  _buildStep2HubCoverage(),
                  _buildStep3Fleet(),
                  _buildStep4Review(),
                ],
              ),
            ),

            // Bottom action buttons
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _prevStep,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const Gap(12),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _isSubmitting
                          ? null
                          : _currentStep == 3
                              ? _submitOnboarding
                              : _nextStep,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1B3A0A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _currentStep == 3 ? 'Activate Fleet & Scope' : 'Continue',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Identity() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Register your organization as an accredited Afrio delivery and dispatch operator.',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const Gap(16),
        TextField(
          controller: _orgNameCtrl,
          decoration: InputDecoration(
            labelText: 'Organization / Company Name *',
            hintText: 'e.g. Accra Speed Dispatch Ltd',
            prefixIcon: const Icon(Icons.business),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const Gap(14),
        TextField(
          controller: _regNumberCtrl,
          decoration: InputDecoration(
            labelText: 'Business Registration No / TIN (Optional)',
            hintText: 'e.g. CS-908234-GH',
            prefixIcon: const Icon(Icons.receipt_long),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const Gap(14),
        TextField(
          controller: _contactPersonCtrl,
          decoration: InputDecoration(
            labelText: 'Contact Person / Fleet Manager',
            hintText: 'e.g. Kwesi Mensah',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const Gap(14),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Official Contact Phone *',
            hintText: '+233 24 123 4567',
            prefixIcon: const Icon(Icons.phone),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const Gap(14),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Official Email (Optional)',
            hintText: 'operations@swiftlogistics.com',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2HubCoverage() {
    final suggestedZones = _regionSuggestedZones[_selectedRegionId] ?? [
      'Metro Commercial Zone',
      'Port / Airport Corridor',
      'Regional Suburbs',
      'Inter-State Routes',
    ];

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Define your operating territories and specify your central depot or partner collection hub.',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const Gap(16),

        // 1. Operating Territory
        DropdownButtonFormField<String>(
          initialValue: _selectedRegionId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Operating Country / Primary Market *',
            prefixIcon: const Icon(Icons.public, color: Color(0xFF1B3A0A)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: const [
            DropdownMenuItem(value: 'reg_nigeria_central', child: Text('Nigeria (Lagos / Nationwide)', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'reg_ghana_central', child: Text('Ghana (Accra / Kumasi)', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'reg_uk_central', child: Text('United Kingdom (London / Manchester)', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'reg_kenya_central', child: Text('Kenya (Nairobi / Mombasa)', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedRegionId = val;
                if (val.contains('nigeria')) _selectedRegionName = 'Nigeria';
                if (val.contains('ghana')) _selectedRegionName = 'Ghana';
                if (val.contains('uk')) _selectedRegionName = 'United Kingdom';
                if (val.contains('kenya')) _selectedRegionName = 'Kenya';

                // Pre-populate with first two suggested
                final defaults = _regionSuggestedZones[val] ?? [];
                if (defaults.isNotEmpty) {
                  _selectedCoverageZones.clear();
                  _selectedCoverageZones.addAll(defaults.take(3));
                }
              });
            }
          },
        ),
        const Gap(20),

        // 2. Coverage Cities & Delivery Zones
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Coverage Cities & Delivery Zones',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              '${_selectedCoverageZones.length} selected',
              style: const TextStyle(fontSize: 12, color: Color(0xFFE48629), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Gap(4),
        const Text(
          'Select all areas your dispatch fleet services, or add your custom coverage routes.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const Gap(10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestedZones.map((zone) {
            final isSelected = _selectedCoverageZones.contains(zone);
            return FilterChip(
              label: Text(zone),
              selected: isSelected,
              selectedColor: const Color(0xFFE48629).withValues(alpha: 0.2),
              checkmarkColor: const Color(0xFFE48629),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF1B3A0A) : Colors.black87,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFFE48629) : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCoverageZones.add(zone);
                  } else {
                    _selectedCoverageZones.remove(zone);
                  }
                });
              },
            );
          }).toList(),
        ),

        // Custom zone input
        const Gap(12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customZoneCtrl,
                decoration: InputDecoration(
                  hintText: 'Add custom city / LGA / territory',
                  isDense: true,
                  prefixIcon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: (val) {
                  final text = val.trim();
                  if (text.isNotEmpty && !_selectedCoverageZones.contains(text)) {
                    setState(() {
                      _selectedCoverageZones.add(text);
                      _customZoneCtrl.clear();
                    });
                  }
                },
              ),
            ),
            const Gap(8),
            FilledButton.tonal(
              onPressed: () {
                final text = _customZoneCtrl.text.trim();
                if (text.isNotEmpty && !_selectedCoverageZones.contains(text)) {
                  setState(() {
                    _selectedCoverageZones.add(text);
                    _customZoneCtrl.clear();
                  });
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),

        const Gap(24),

        // 3. Central Depot / Hub Mode Selection
        const Text(
          'Hub Station & Operations Depot',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const Gap(8),

        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _isCreatingNewHub = true),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isCreatingNewHub ? const Color(0xFFE48629) : Colors.grey.withValues(alpha: 0.3),
                      width: _isCreatingNewHub ? 2 : 1,
                    ),
                    color: _isCreatingNewHub ? const Color(0xFFE48629).withValues(alpha: 0.08) : Colors.transparent,
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.add_business, color: _isCreatingNewHub ? const Color(0xFFE48629) : Colors.grey),
                      const Gap(6),
                      const Text(
                        'Our Own Hub Depot',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        'Set up your main sorting depot',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Gap(12),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _isCreatingNewHub = false),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_isCreatingNewHub ? const Color(0xFFE48629) : Colors.grey.withValues(alpha: 0.3),
                      width: !_isCreatingNewHub ? 2 : 1,
                    ),
                    color: !_isCreatingNewHub ? const Color(0xFFE48629).withValues(alpha: 0.08) : Colors.transparent,
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.hub_outlined, color: !_isCreatingNewHub ? const Color(0xFFE48629) : Colors.grey),
                      const Gap(6),
                      const Text(
                        'Link Partner Hub',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        'Connect to existing network station',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const Gap(16),

        // Depot Form or Partner List
        if (_isCreatingNewHub) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).cardColor,
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New Depot Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Gap(12),
                TextField(
                  controller: _hubNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Depot / Station Name *',
                    hintText: 'e.g. Ikeja Central Sorting Hub',
                    prefixIcon: const Icon(Icons.warehouse_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const Gap(12),
                TextField(
                  controller: _hubAddressCtrl,
                  decoration: InputDecoration(
                    labelText: 'Depot Physical Address *',
                    hintText: 'e.g. Plot 14, Commercial Avenue',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const Gap(12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hubCityCtrl,
                        decoration: InputDecoration(
                          labelText: 'City / State *',
                          hintText: 'e.g. Ikeja, Lagos',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: TextField(
                        controller: _hubPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Hub Hotline',
                          hintText: 'e.g. +234 1 234 5678',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          if (_isLoadingStations)
            const Center(child: CircularProgressIndicator.adaptive())
          else if (_availableStations.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.amber.withValues(alpha: 0.1),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber),
                  Gap(10),
                  Expanded(
                    child: Text(
                      'No shared network hubs found for this region yet. Please switch to "Our Own Hub Depot" to register your initial station.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _availableStations.map((station) {
                final id = station['id'].toString();
                final isSelected = _selectedStationId == id;
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFFE48629) : Colors.grey.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.store_mall_directory,
                      color: isSelected ? const Color(0xFFE48629) : Colors.grey,
                    ),
                    title: Text(station['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${station['address'] ?? ''}, ${station['city'] ?? ''}'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Color(0xFFE48629))
                        : null,
                    onTap: () => setState(() => _selectedStationId = id),
                  ),
                );
              }).toList(),
            ),
        ],
        const Gap(20),
      ],
    );
  }

  Widget _buildStep3Fleet() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Declare your fleet capacity and dispatch preferences for automatic job allocations.',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const Gap(16),
        _buildCounterTile('Delivery Bikes / Motorcycles', Icons.two_wheeler, _bikeCount, (val) {
          setState(() => _bikeCount = val);
        }),
        const Gap(12),
        _buildCounterTile('Vans / Sprinters', Icons.airport_shuttle, _vanCount, (val) {
          setState(() => _vanCount = val);
        }),
        const Gap(12),
        _buildCounterTile('Heavy Haulage Trucks', Icons.local_shipping, _truckCount, (val) {
          setState(() => _truckCount = val);
        }),
        const Gap(20),
        const Text('Service Level Commitment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const Gap(8),
        RadioListTile<String>(
          title: const Text('Same-Day Doorstep Dispatch (< 6 hrs)'),
          subtitle: const Text('Priority routing for local deliveries within city limits'),
          value: 'same_day',
          groupValue: _deliverySla,
          activeColor: const Color(0xFF1B3A0A),
          onChanged: (val) => setState(() => _deliverySla = val!),
        ),
        RadioListTile<String>(
          title: const Text('Next-Day & Hub Consolidation (24-48 hrs)'),
          subtitle: const Text('Consolidated shipments between collection stations'),
          value: 'next_day',
          groupValue: _deliverySla,
          activeColor: const Color(0xFF1B3A0A),
          onChanged: (val) => setState(() => _deliverySla = val!),
        ),
      ],
    );
  }

  Widget _buildCounterTile(String title, IconData icon, int count, ValueChanged<int> onChanged) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE48629).withValues(alpha: 0.12),
              child: Icon(icon, color: const Color(0xFFE48629), size: 20),
            ),
            const Gap(12),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: count > 0 ? () => onChanged(count - 1) : null,
            ),
            Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => onChanged(count + 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4Review() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Please review your logistics partnership profile before activation:',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const Gap(16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1B3A0A), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF1B3A0A),
                      child: Icon(Icons.local_shipping, color: Colors.white),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _orgNameCtrl.text.trim().isNotEmpty
                                ? _orgNameCtrl.text.trim()
                                : 'Partner Organization',
                            style: context.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Coverage: $_selectedRegionName',
                            style: context.bodySmall?.copyWith(color: ColorManager.manatee),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildSummaryRow('Contact Lead', _contactPersonCtrl.text.trim().isNotEmpty ? _contactPersonCtrl.text.trim() : 'N/A'),
                _buildSummaryRow('Phone', _phoneCtrl.text.trim()),
                if (_emailCtrl.text.trim().isNotEmpty)
                  _buildSummaryRow('Email', _emailCtrl.text.trim()),
                _buildSummaryRow('Fleet Composition', '$_bikeCount Bikes • $_vanCount Vans • $_truckCount Trucks'),
                _buildSummaryRow('Commitment', _deliverySla == 'same_day' ? 'Same-Day Express' : 'Next-Day Transit'),
              ],
            ),
          ),
        ),
        const Gap(16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE48629).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Color(0xFFE48629), size: 20),
              Gap(10),
              Expanded(
                child: Text(
                  'Activating will automatically switch your working profile to Logistics Hub & Dispatch, giving you direct controls over collection stations and delivery fleet runs.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1B3A0A)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
