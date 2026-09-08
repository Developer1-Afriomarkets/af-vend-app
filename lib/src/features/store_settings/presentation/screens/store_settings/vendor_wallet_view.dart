import 'dart:developer';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medusa_admin/src/core/di/di.dart';
import 'package:medusa_admin/src/core/extensions/snack_bar_extension.dart';
import 'package:medusa_admin/src/core/utils/easy_loading.dart';

@RoutePage()
class VendorWalletView extends StatefulWidget {
  const VendorWalletView({super.key});

  @override
  State<VendorWalletView> createState() => _VendorWalletViewState();
}

class _VendorWalletViewState extends State<VendorWalletView> with SingleTickerProviderStateMixin {
  String _getCurrencySymbol(String? code) {
    if (code == null) return '₦';
    switch (code.toUpperCase()) {
      case 'NGN': return '₦';
      case 'USD': return r'$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'GHS': return 'GH₵';
      case 'CAD': return r'CA$';
      case 'AUD': return r'AU$';
      default: return '${code.toUpperCase()} ';
    }
  }

  late TabController _tabController;
  bool _isLoading = true;

  // Wallet Overview Data
  Map<String, dynamic>? _walletData;
  Map<String, dynamic>? _bankAccount;
  List<dynamic> _ledger = [];
  List<dynamic> _payouts = [];

  // Bank Setup Controls
  List<dynamic> _banks = [];
  bool _isLoadingBanks = false;
  String? _selectedBankCode;
  String? _selectedBankName;
  final _accountNumberCtrl = TextEditingController();
  final _resolvedAccountNameCtrl = TextEditingController();
  bool _isResolvingAccount = false;
  bool _isAccountResolved = false;

  // Payout Controls
  final _payoutAmountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllWalletData();
    _loadBankList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _accountNumberCtrl.dispose();
    _resolvedAccountNameCtrl.dispose();
    _payoutAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllWalletData() async {
    setState(() => _isLoading = true);
    try {
      final dio = getIt<Dio>();
      
      // Load Wallet Overview
      final walletRes = await dio.get('/admin/vendor/wallet');
      if (walletRes.statusCode == 200 && walletRes.data != null) {
        _walletData = walletRes.data as Map<String, dynamic>;
        _bankAccount = _walletData?['bankAccount'] as Map<String, dynamic>?;
        _ledger = (_walletData?['ledger'] as List<dynamic>?) ?? [];
      }

      // Load Payout History
      final payoutRes = await dio.get('/admin/vendor/payouts');
      if (payoutRes.statusCode == 200 && payoutRes.data != null) {
        _payouts = (payoutRes.data['payouts'] as List<dynamic>?) ?? [];
      }
    } catch (e) {
      log('Error fetching vendor wallet data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBankList() async {
    setState(() => _isLoadingBanks = true);
    try {
      final dio = getIt<Dio>();
      final res = await dio.get('/admin/vendor/banks?country=nigeria');
      if (res.statusCode == 200 && res.data != null) {
        final list = (res.data['banks'] as List<dynamic>?) ?? [];
        setState(() {
          _banks = list;
          if (_banks.isNotEmpty) {
            _selectedBankCode = _banks.first['code']?.toString();
            _selectedBankName = _banks.first['name']?.toString();
          }
        });
      }
    } catch (e) {
      log('Error loading bank list: $e');
    } finally {
      if (mounted) setState(() => _isLoadingBanks = false);
    }
  }

  Future<void> _resolveBankAccount() async {
    final accNum = _accountNumberCtrl.text.trim();
    if (accNum.length < 10 || _selectedBankCode == null) {
      context.showSnackBar('Please enter a valid 10-digit account number');
      return;
    }

    setState(() => _isResolvingAccount = true);
    try {
      final dio = getIt<Dio>();
      final res = await dio.post('/admin/vendor/bank-account/resolve', data: {
        'account_number': accNum,
        'bank_code': _selectedBankCode,
      });

      if (res.statusCode == 200 && res.data != null && res.data['success'] == true) {
        setState(() {
          _resolvedAccountNameCtrl.text = res.data['account_name'] ?? 'Account Verified';
          _isAccountResolved = true;
        });
        context.showSnackBar('Account resolved: ${_resolvedAccountNameCtrl.text}');
      } else {
        context.showSnackBar('Unable to resolve account name. Please verify details.');
      }
    } catch (e) {
      context.showSnackBar('Error resolving bank account: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isResolvingAccount = false);
    }
  }

  Future<void> _requestOtp(String purpose) async {
    loading();
    try {
      final dio = getIt<Dio>();
      final res = await dio.post('/admin/vendor/otp/send', data: {'purpose': purpose});
      dismissLoading();
      if (res.statusCode == 200) {
        context.showSnackBar('Verification OTP dispatched to your registered contact.');
      }
    } catch (e) {
      dismissLoading();
      context.showSnackBar('Failed to dispatch OTP: ${e.toString()}');
    }
  }

  Future<void> _showSaveBankDialog() async {
    if (!_isAccountResolved) {
      context.showSnackBar('Please resolve your account number first.');
      return;
    }
    await _requestOtp('bank_account_update');

    final otpCtrl = TextEditingController();
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify & Save Bank Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bank: ${_selectedBankName ?? ''}'),
            Text('Account Number: ${_accountNumberCtrl.text.trim()}'),
            Text('Account Name: ${_resolvedAccountNameCtrl.text}'),
            const Gap(16),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Enter 6-Digit OTP',
                hintText: '123456',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save Account')),
        ],
      ),
    );

    if (confirmed == true && otpCtrl.text.trim().isNotEmpty) {
      loading();
      try {
        final dio = getIt<Dio>();
        final res = await dio.post('/admin/vendor/bank-account/save', data: {
          'bank_code': _selectedBankCode,
          'bank_name': _selectedBankName,
          'account_number': _accountNumberCtrl.text.trim(),
          'otp_code': otpCtrl.text.trim(),
        });
        dismissLoading();
        if (res.statusCode == 200 && res.data['success'] == true) {
          context.showSnackBar('Business bank account saved successfully!');
          _loadAllWalletData();
        } else {
          context.showSnackBar(res.data['message'] ?? 'Failed to save bank account');
        }
      } catch (e) {
        dismissLoading();
        context.showSnackBar('Error: ${e.toString()}');
      }
    }
  }

  Future<void> _showPayoutRequestDialog() async {
    if (_bankAccount == null || _bankAccount!['account_number'] == null) {
      context.showSnackBar('Please configure your payout bank account first.');
      return;
    }
    await _requestOtp('payout_request');

    final wallet = _walletData?['wallet'] as Map<String, dynamic>?;
    final totalBalanceMap = (wallet?['total_balance'] as Map<String, dynamic>?) ?? {};
    final availableCurrencies = <String>[];
    for (final key in totalBalanceMap.keys) {
      final k = key.toString().toUpperCase();
      if (!availableCurrencies.contains(k)) availableCurrencies.add(k);
    }
    if (availableCurrencies.isEmpty) availableCurrencies.addAll(['NGN', 'USD']);
    String selectedCurrency = availableCurrencies.contains('NGN') ? 'NGN' : availableCurrencies.first;

    final otpCtrl = TextEditingController();
    _payoutAmountCtrl.clear();
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Request Payout Withdrawal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payout Bank: ${_bankAccount?['bank_name'] ?? ''} (${_bankAccount?['account_number'] ?? ''})'),
              const Gap(12),
              if (availableCurrencies.length > 1) ...[
                DropdownButtonFormField<String>(
                  value: selectedCurrency,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Select Payout Currency',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: availableCurrencies.map((c) {
                    final bal = totalBalanceMap[c] ?? 0;
                    return DropdownMenuItem(
                      value: c,
                      child: Text('$c (${_getCurrencySymbol(c)}$bal available)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedCurrency = val);
                  },
                ),
                const Gap(12),
              ],
              TextField(
                controller: _payoutAmountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount ($selectedCurrency)',
                  hintText: 'e.g. 50000',
                  prefixText: _getCurrencySymbol(selectedCurrency),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const Gap(12),
              TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Enter 6-Digit OTP',
                  hintText: '123456',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Submit Payout')),
          ],
        ),
      ),
    );

    if (confirmed == true && _payoutAmountCtrl.text.trim().isNotEmpty && otpCtrl.text.trim().isNotEmpty) {
      loading();
      try {
        final dio = getIt<Dio>();
        final res = await dio.post('/admin/vendor/payout/request', data: {
          'amount': double.tryParse(_payoutAmountCtrl.text.trim()) ?? 0,
          'currency': selectedCurrency.toLowerCase(),
          'otp_code': otpCtrl.text.trim(),
        });
        dismissLoading();
        if (res.statusCode == 200 && res.data['success'] == true) {
          context.showSnackBar('Payout request submitted successfully!');
          _loadAllWalletData();
        } else {
          context.showSnackBar(res.data['message'] ?? 'Payout request failed');
        }
      } catch (e) {
        dismissLoading();
        context.showSnackBar('Error: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        title: const Text('Vendor Wallet & Payouts'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14.0),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: const Color(0xFFE48629),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE48629).withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white70 : Colors.black87,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.0,
                letterSpacing: -0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13.0,
              ),
              tabs: const [
                Tab(icon: Icon(LucideIcons.wallet, size: 16), text: 'Overview'),
                Tab(icon: Icon(LucideIcons.landmark, size: 16), text: 'Bank Account'),
                Tab(icon: Icon(LucideIcons.history, size: 16), text: 'Payouts'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllWalletData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(isDark),
                  _buildBankAccountTab(isDark),
                  _buildPayoutsTab(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    final wallet = _walletData?['wallet'] as Map<String, dynamic>?;
    final totalBalanceMap = (wallet?['total_balance'] as Map<String, dynamic>?) ?? {};
    final primaryCurrency = totalBalanceMap.containsKey('NGN') ? 'NGN' : (totalBalanceMap.keys.firstOrNull ?? 'NGN');
    final primaryBalance = totalBalanceMap[primaryCurrency] ?? 0;
    final otherCurrencies = totalBalanceMap.keys.where((c) => c != primaryCurrency).toList();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Balance Card
        Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF14281D), const Color(0xFF0F1E16)]
                  : [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Vendor Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Gap(8),
              Text(
                '${_getCurrencySymbol(primaryCurrency)}${primaryBalance.toString()} $primaryCurrency',
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
              ),
              if (otherCurrencies.isNotEmpty) ...[
                const Gap(8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: otherCurrencies.map((c) {
                    final amt = totalBalanceMap[c] ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '${_getCurrencySymbol(c)}$amt $c',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const Gap(16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showPayoutRequestDialog,
                      icon: const Icon(LucideIcons.arrowUpRight, size: 16),
                      label: const Text('Request Payout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade900,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Gap(20),
        const Text('Recent Wallet Ledger Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const Gap(10),
        if (_ledger.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(child: Text('No recent wallet transactions found.', style: TextStyle(color: Colors.grey))),
          )
        else
          ..._ledger.map((item) {
            final type = item['transaction_type'] ?? 'credit';
            final amount = item['amount'] ?? 0;
            final isCredit = type == 'credit';
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCredit ? Colors.green.shade50 : Colors.red.shade50,
                  child: Icon(
                    isCredit ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
                    color: isCredit ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),
                title: Text(item['description'] ?? 'Transaction', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(item['created_at']?.toString().split('T').first ?? ''),
                trailing: Text(
                  '${isCredit ? "+" : "-"}₦$amount',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
                    fontSize: 15,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBankAccountTab(bool isDark) {
    final hasBank = _bankAccount != null && _bankAccount!['account_number'] != null;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (hasBank) ...[
          Card(
            elevation: 1,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.checkCircle2, color: Colors.green, size: 20),
                      const Gap(8),
                      const Expanded(child: Text('Configured Business Payout Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const Divider(height: 20),
                  Text('Bank Name: ${_bankAccount?['bank_name'] ?? ''}', style: const TextStyle(fontSize: 14)),
                  const Gap(4),
                  Text('Account Number: ${_bankAccount?['account_number'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const Gap(4),
                  Text('Account Name: ${_bankAccount?['account_name'] ?? 'Verified Vendor'}', style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
          const Gap(20),
          const Text('Update Payout Bank Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Gap(8),
        ] else ...[
          const Text('Setup Business Payout Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Configure your Nigerian bank account to receive automated payout withdrawals.', style: TextStyle(color: Colors.grey)),
          const Gap(16),
        ],

        // Bank Selection Dropdown
        if (_isLoadingBanks)
          const CircularProgressIndicator()
        else
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _selectedBankCode,
            decoration: InputDecoration(
              labelText: 'Select Bank',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(LucideIcons.landmark, size: 20),
            ),
            items: _banks.map((b) {
              return DropdownMenuItem<String>(
                value: b['code']?.toString(),
                child: Text(b['name']?.toString() ?? '', overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedBankCode = val;
                _selectedBankName = _banks.firstWhere((element) => element['code']?.toString() == val, orElse: () => {})['name']?.toString();
                _isAccountResolved = false;
              });
            },
          ),
        const Gap(14),

        // Account Number Input
        TextField(
          controller: _accountNumberCtrl,
          keyboardType: TextInputType.number,
          maxLength: 10,
          decoration: InputDecoration(
            labelText: 'Account Number',
            hintText: '0123456789',
            prefixIcon: const Icon(LucideIcons.hash, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (_) {
            if (_isAccountResolved) setState(() => _isAccountResolved = false);
          },
        ),
        const Gap(10),

        ElevatedButton.icon(
          onPressed: _isResolvingAccount ? null : _resolveBankAccount,
          icon: _isResolvingAccount ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.search, size: 18),
          label: Text(_isResolvingAccount ? 'Resolving Account...' : 'Resolve Account Name'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),

        if (_isAccountResolved) ...[
          const Gap(14),
          TextField(
            controller: _resolvedAccountNameCtrl,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Verified Account Name',
              prefixIcon: const Icon(LucideIcons.userCheck, color: Colors.green, size: 20),
              filled: true,
              fillColor: Colors.green.withOpacity(0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const Gap(16),
          ElevatedButton.icon(
            onPressed: _showSaveBankDialog,
            icon: const Icon(LucideIcons.save, size: 18),
            label: const Text('Verify via OTP & Save Bank Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPayoutsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(child: Text('Payout Requests & Settlements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            const Gap(8),
            OutlinedButton.icon(
              onPressed: _showPayoutRequestDialog,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('New Payout'),
            ),
          ],
        ),
        const Gap(12),
        if (_payouts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36.0),
            child: Center(child: Text('No payout history found.', style: TextStyle(color: Colors.grey))),
          )
        else
          ..._payouts.map((payout) {
            final status = payout['status'] ?? 'pending';
            final amount = payout['amount'] ?? 0;
            final isSuccess = status == 'completed' || status == 'success';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSuccess ? Colors.green.shade50 : Colors.amber.shade50,
                  child: Icon(
                    isSuccess ? LucideIcons.check : LucideIcons.clock,
                    color: isSuccess ? Colors.green : Colors.amber.shade800,
                    size: 20,
                  ),
                ),
                title: Text('${_getCurrencySymbol(payout["currency"]?.toString())}$amount ${(payout["currency"] ?? "NGN").toString().toUpperCase()} Withdrawal', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Requested: ${payout['created_at']?.toString().split('T').first ?? ''}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSuccess ? Colors.green.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSuccess ? Colors.green.shade800 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}