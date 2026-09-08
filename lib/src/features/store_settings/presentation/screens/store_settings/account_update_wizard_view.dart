import 'dart:developer';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medusa_admin/src/core/di/di.dart';
import 'package:medusa_admin/src/core/extensions/snack_bar_extension.dart';
import 'package:medusa_admin/src/core/utils/easy_loading.dart';
import 'package:medusa_admin/src/features/store_details/presentation/bloc/store/store_bloc.dart';
import 'package:medusa_admin/src/features/team/presentation/bloc/user_crud/user_crud_bloc.dart';
import 'package:medusa_admin_dart_client/medusa_admin_dart_client_v2.dart';

@RoutePage()
class AccountUpdateWizardView extends StatefulWidget {
  const AccountUpdateWizardView({super.key});

  @override
  State<AccountUpdateWizardView> createState() => _AccountUpdateWizardViewState();
}

class _AccountUpdateWizardViewState extends State<AccountUpdateWizardView> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;
  bool _isLoadingData = true;

  // Step 1: Personal Details
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+234');
  String _selectedCountry = 'Nigeria';

  // Step 2: Store Details
  final _storeNameCtrl = TextEditingController();
  String _selectedState = 'Lagos';
  final _cityCtrl = TextEditingController();
  final _streetAddressCtrl = TextEditingController();

  // Step 3: Market Details
  String _selectedMarket = 'Balogun Market';
  final _customMarketCtrl = TextEditingController();
  final _nearbyLandmarkCtrl = TextEditingController();
  final _marketLineCtrl = TextEditingController();
  final _shopBlockCtrl = TextEditingController();

  String? _userId;
  String? _storeId;

  final List<String> _nigerianStates = [
    'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue',
    'Borno', 'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu',
    'FCT - Abuja', 'Gombe', 'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina',
    'Kebbi', 'Kogi', 'Kwara', 'Lagos', 'Nasarawa', 'Niger', 'Ogun', 'Ondo',
    'Osun', 'Oyo', 'Plateau', 'Rivers', 'Sokoto', 'Taraba', 'Yobe', 'Zamfara'
  ];

  final List<String> _popularMarkets = [
    'Balogun Market',
    'Alaba International Market',
    'Computer Village Ikeja',
    'Trade Fair Complex',
    'Tejuosho Market Yaba',
    'Ariaria International Market Aba',
    'Main Market Onitsha',
    'Bodija Market Ibadan',
    'Wuse Market Abuja',
    'Garki Model Market Abuja',
    'Dugbe Market Ibadan',
    'Oil Mill Market Port Harcourt',
    'Mile 1 Market Port Harcourt',
    'Singa Market Kano',
    'Kurmi Market Kano',
    'Other (Specify Below)'
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _storeNameCtrl.dispose();
    _cityCtrl.dispose();
    _streetAddressCtrl.dispose();
    _customMarketCtrl.dispose();
    _nearbyLandmarkCtrl.dispose();
    _marketLineCtrl.dispose();
    _shopBlockCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    setState(() => _isLoadingData = true);
    try {
      final client = getIt<MedusaAdminV2>();
      final meRes = await client.users.retrieveMe();
      final user = meRes.user;
      _userId = user.id;

      _firstNameCtrl.text = user.firstName ?? '';
      _lastNameCtrl.text = user.lastName ?? '';
      _emailCtrl.text = user.email ?? '';

      // phone/country are stored in store metadata and loaded below

      // Load Store
      final storeRes = await client.store.list();
      final store = storeRes.stores.firstOrNull;
      if (store != null) {
        _storeId = store.id;
        _storeNameCtrl.text = store.name;
        final storeMeta = store.metadata ?? {};
        if (storeMeta['state'] != null) {
          final s = storeMeta['state'].toString();
          if (_nigerianStates.contains(s)) {
            _selectedState = s;
          }
        }
        if (storeMeta['city'] != null) _cityCtrl.text = storeMeta['city'].toString();
        if (storeMeta['address'] != null) _streetAddressCtrl.text = storeMeta['address'].toString();
        if (storeMeta['market'] != null) {
          final m = storeMeta['market'].toString();
          if (_popularMarkets.contains(m)) {
            _selectedMarket = m;
          } else {
            _selectedMarket = 'Other (Specify Below)';
            _customMarketCtrl.text = m;
          }
        }
        if (storeMeta['nearby_market'] != null) _nearbyLandmarkCtrl.text = storeMeta['nearby_market'].toString();
        if (storeMeta['market_line'] != null) _marketLineCtrl.text = storeMeta['market_line'].toString();
        if (storeMeta['market_block'] != null) _shopBlockCtrl.text = storeMeta['market_block'].toString();
        if (storeMeta['phone'] != null && storeMeta['phone'].toString().isNotEmpty) {
          _phoneCtrl.text = storeMeta['phone'].toString();
        }
      }
    } catch (e) {
      log('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  String _getEffectiveMarket() {
    if (_selectedMarket == 'Other (Specify Below)') {
      return _customMarketCtrl.text.trim().isNotEmpty ? _customMarketCtrl.text.trim() : 'Unspecified Market';
    }
    return _selectedMarket;
  }

  String _buildFullStoreAddress() {
    final parts = <String>[];
    if (_shopBlockCtrl.text.trim().isNotEmpty) parts.add(_shopBlockCtrl.text.trim());
    if (_marketLineCtrl.text.trim().isNotEmpty) parts.add(_marketLineCtrl.text.trim());
    final effectiveMarket = _getEffectiveMarket();
    if (effectiveMarket.isNotEmpty) parts.add(effectiveMarket);
    if (_streetAddressCtrl.text.trim().isNotEmpty) parts.add(_streetAddressCtrl.text.trim());
    if (_cityCtrl.text.trim().isNotEmpty) parts.add(_cityCtrl.text.trim());
    if (_selectedState.isNotEmpty) parts.add('$_selectedState State');
    parts.add(_selectedCountry);
    return parts.join(', ');
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handleNext() {
    if (_currentStep == 0) {
      if (_firstNameCtrl.text.trim().isEmpty) {
        context.showSnackBar('Please enter your first name');
        return;
      }
      if (_lastNameCtrl.text.trim().isEmpty) {
        context.showSnackBar('Please enter your last name');
        return;
      }
      _goToStep(1);
      return;
    }

    if (_currentStep == 1) {
      if (_storeNameCtrl.text.trim().isEmpty) {
        context.showSnackBar('Please enter your store name');
        return;
      }
      if (_cityCtrl.text.trim().isEmpty) {
        context.showSnackBar('Please enter your city');
        return;
      }
      _goToStep(2);
      return;
    }

    if (_currentStep == 2) {
      if (_selectedMarket == 'Other (Specify Below)' && _customMarketCtrl.text.trim().isEmpty) {
        context.showSnackBar('Please enter your market name');
        return;
      }
      _goToStep(3);
      return;
    }

    if (_currentStep == 3) {
      _saveAll();
    }
  }

  Future<void> _saveAll() async {
    loading();
    try {
      final client = getIt<MedusaAdminV2>();
      final fullAddress = _buildFullStoreAddress();
      final effectiveMarket = _getEffectiveMarket();

      // 1. Update User
      if (_userId != null) {
        await client.users.update(
          _userId!,
          UserUpdateReq(
            firstName: _firstNameCtrl.text.trim(),
            lastName: _lastNameCtrl.text.trim(),
          ),
        );
      }

      // 2. Update Store
      if (_storeId != null) {
        await client.store.update(
          _storeId!,
          UpdateStoreReq(
            name: _storeNameCtrl.text.trim(),
            metadata: {
              'state': _selectedState,
              'city': _cityCtrl.text.trim(),
              'address': _streetAddressCtrl.text.trim(),
              'market': effectiveMarket,
              'nearby_market': _nearbyLandmarkCtrl.text.trim(),
              'market_line': _marketLineCtrl.text.trim(),
              'market_block': _shopBlockCtrl.text.trim(),
              'full_store_address': fullAddress,
              'phone': _phoneCtrl.text.trim(),
              'country': _selectedCountry,
            },
          ),
        );
      }

      dismissLoading();
      if (mounted) {
        context.showSnackBar('Store and personal details updated successfully!');
        // Trigger Bloc reloads
        context.read<StoreBloc>().add(const StoreEvent.loadStores(null));
        context.read<UserCrudBloc>().add(const UserCrudEvent.loadCurrentUser());
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      dismissLoading();
      if (mounted) {
        context.showSnackBar('Failed to update: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final popped = await context.maybePop();
            if (!popped && context.mounted) {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: const Text('Store & Profile Wizard'),
        elevation: 0,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStepperHeader(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildPersonalDetailsStep(),
                      _buildStoreDetailsStep(),
                      _buildMarketDetailsStep(),
                      _buildReviewStep(),
                    ],
                  ),
                ),
                _buildBottomNav(),
              ],
            ),
    );
  }

  Widget _buildStepperHeader() {
    final stepLabels = ['Personal', 'Store', 'Market', 'Review'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.15))),
      ),
      child: Row(
        children: List.generate(stepLabels.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepIndex = index ~/ 2;
            final isPassed = _currentStep > stepIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: isPassed ? Theme.of(context).colorScheme.primary : Colors.grey.withOpacity(0.3),
              ),
            );
          }
          final stepIndex = index ~/ 2;
          final isCurrent = _currentStep == stepIndex;
          final isCompleted = _currentStep > stepIndex;
          final primaryColor = Theme.of(context).colorScheme.primary;

          return GestureDetector(
            onTap: () {
              if (stepIndex < _currentStep) _goToStep(stepIndex);
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: isCompleted
                      ? primaryColor
                      : isCurrent
                          ? primaryColor.withOpacity(0.15)
                          : Colors.grey.withOpacity(0.2),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? primaryColor : Colors.grey.shade600,
                          ),
                        ),
                ),
                const Gap(6),
                Text(
                  stepLabels[stepIndex],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    color: isCurrent ? primaryColor : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPersonalDetailsStep() {
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        _buildSectionTitle('Personal Information', 'Your identity details associated with this vendor store.'),
        const Gap(16),
        _buildTextField(
          controller: _firstNameCtrl,
          label: 'First Name',
          icon: LucideIcons.user,
          hint: 'Enter your first name',
        ),
        const Gap(14),
        _buildTextField(
          controller: _lastNameCtrl,
          label: 'Last Name',
          icon: LucideIcons.userCheck,
          hint: 'Enter your last name',
        ),
        const Gap(14),
        _buildTextField(
          controller: _emailCtrl,
          label: 'Email Address',
          icon: LucideIcons.mail,
          readOnly: true,
          hint: 'Email address',
        ),
        const Gap(14),
        _buildTextField(
          controller: _phoneCtrl,
          label: 'Phone Number',
          icon: LucideIcons.phone,
          keyboardType: TextInputType.phone,
          hint: '+234 800 000 0000',
        ),
        const Gap(14),
        _buildDropdown(
          label: 'Country',
          icon: LucideIcons.globe,
          value: _selectedCountry,
          items: ['Nigeria', 'Ghana', 'Kenya', 'South Africa'],
          onChanged: (val) {
            if (val != null) setState(() => _selectedCountry = val);
          },
        ),
      ],
    );
  }

  Widget _buildStoreDetailsStep() {
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        _buildSectionTitle('Store & Business Details', 'Information about your business, physical store and city.'),
        const Gap(16),
        _buildTextField(
          controller: _storeNameCtrl,
          label: 'Store / Business Name',
          icon: LucideIcons.store,
          hint: 'e.g. Afrio Electronics & Gadgets',
        ),
        const Gap(14),
        _buildDropdown(
          label: 'State / Province',
          icon: LucideIcons.mapPin,
          value: _selectedState,
          items: _nigerianStates,
          onChanged: (val) {
            if (val != null) setState(() => _selectedState = val);
          },
        ),
        const Gap(14),
        _buildTextField(
          controller: _cityCtrl,
          label: 'City / Town',
          icon: LucideIcons.building2,
          hint: 'e.g. Ikeja, Lagos Island, Aba',
        ),
        const Gap(14),
        _buildTextField(
          controller: _streetAddressCtrl,
          label: 'Street / Local Address',
          icon: LucideIcons.map,
          maxLines: 2,
          hint: 'e.g. 14 Broad Street, Marina',
        ),
      ],
    );
  }

  Widget _buildMarketDetailsStep() {
    final isOther = _selectedMarket == 'Other (Specify Below)';
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        _buildSectionTitle('Market Location', 'Specify the commercial market or complex where your store is located.'),
        const Gap(16),
        _buildDropdown(
          label: 'Commercial Market',
          icon: LucideIcons.shoppingBag,
          value: _selectedMarket,
          items: _popularMarkets,
          onChanged: (val) {
            if (val != null) setState(() => _selectedMarket = val);
          },
        ),
        if (isOther) ...[
          const Gap(14),
          _buildTextField(
            controller: _customMarketCtrl,
            label: 'Market Name',
            icon: LucideIcons.store,
            hint: 'e.g. New Market Onitsha',
          ),
          const Gap(14),
          _buildTextField(
            controller: _nearbyLandmarkCtrl,
            label: 'Nearby Landmark / Well-Known Market',
            icon: LucideIcons.compass,
            hint: 'e.g. Near Oshodi Bus Terminal',
          ),
        ],
        const Gap(14),
        _buildTextField(
          controller: _marketLineCtrl,
          label: 'Market Line / Section',
          icon: LucideIcons.gitFork,
          hint: 'e.g. Line B, Zone 3, Cloth Section',
        ),
        const Gap(14),
        _buildTextField(
          controller: _shopBlockCtrl,
          label: 'Shop / Block / Stall Number',
          icon: LucideIcons.doorOpen,
          hint: 'e.g. Shop 12, Block C',
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final fullAddress = _buildFullStoreAddress();
    final effectiveMarket = _getEffectiveMarket();

    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        _buildSectionTitle('Review & Confirm', 'Verify your personal, store, and market details before saving.'),
        const Gap(16),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryRow(LucideIcons.user, 'Full Name', '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'),
                const Divider(height: 20),
                _buildSummaryRow(LucideIcons.mail, 'Email', _emailCtrl.text.trim()),
                const Divider(height: 20),
                _buildSummaryRow(LucideIcons.phone, 'Phone', _phoneCtrl.text.trim()),
                const Divider(height: 20),
                _buildSummaryRow(LucideIcons.store, 'Store Name', _storeNameCtrl.text.trim()),
                const Divider(height: 20),
                _buildSummaryRow(LucideIcons.shoppingBag, 'Market', effectiveMarket),
                if (_marketLineCtrl.text.trim().isNotEmpty) ...[
                  const Divider(height: 20),
                  _buildSummaryRow(LucideIcons.gitFork, 'Line / Section', _marketLineCtrl.text.trim()),
                ],
                if (_shopBlockCtrl.text.trim().isNotEmpty) ...[
                  const Divider(height: 20),
                  _buildSummaryRow(LucideIcons.doorOpen, 'Shop / Block', _shopBlockCtrl.text.trim()),
                ],
              ],
            ),
          ),
        ),
        const Gap(16),
        Card(
          elevation: 1,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.mapPin, color: Theme.of(context).colorScheme.primary, size: 20),
                    const Gap(8),
                    Text(
                      'Generated Full Store Address',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const Gap(8),
                Text(
                  fullAddress,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const Gap(10),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Gap(4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const Gap(6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: readOnly,
            fillColor: readOnly ? Colors.grey.withOpacity(0.08) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const Gap(6),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : items.first,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final isLast = _currentStep == _totalSteps - 1;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            OutlinedButton.icon(
              onPressed: () => _goToStep(_currentStep - 1),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const Gap(12),
          ],
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _handleNext,
              icon: Icon(isLast ? Icons.check_circle_outline : Icons.arrow_forward, size: 18),
              label: Text(
                isLast ? 'Save & Finish' : 'Next Step',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
