import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:home_care_admin/core/api_client.dart';
import 'package:home_care_admin/core/token_storage.dart';

class OrgProfileScreen extends StatefulWidget {
  const OrgProfileScreen({super.key});

  @override
  State<OrgProfileScreen> createState() => _OrgProfileScreenState();
}

class _OrgProfileScreenState extends State<OrgProfileScreen> {
  int _step = 0;
  bool _isLoading = false;

  // Step 0: Phone verification
  String _phoneNumber = '';
  bool _otpSent = false;
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // Step 1 fields
  final _orgNameController = TextEditingController();
  final _regNumberController = TextEditingController();
  String _businessType = 'AGENCY';
  final _gstController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();

  // Step 2 fields
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final Set<String> _selectedCategories = {};
  List<Map<String, dynamic>> _availableServices = [];
  bool _servicesLoading = false;
  final _operatingHoursController = TextEditingController();
  final _staffCountController = TextEditingController();

  final List<String> _businessTypes = [
    'AGENCY',
    'CENTER',
    'COMPANY',
    'CLINIC',
    'OTHER'
  ];

  @override
  void initState() {
    super.initState();
    _prefillPhone();
    _loadServices();
  }

  Future<void> _prefillPhone() async {
    final saved = await TokenStorage.getPhone();
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _phoneNumber = saved;
        _step = 1;
      });
    }
  }

  Future<void> _loadServices() async {
    setState(() => _servicesLoading = true);
    try {
      final result = await ApiClient.get('/services');
      final list = result['data'] as List? ?? result['services'] as List? ?? [];
      setState(() {
        _availableServices =
            list.map((e) => e as Map<String, dynamic>).toList();
      });
    } catch (_) {
    } finally {
      setState(() => _servicesLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    if (_phoneNumber.isEmpty) {
      Get.snackbar('Required', 'Please enter your phone number',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ApiClient.post('/auth/send-otp', {'phone_number': _phoneNumber});
      setState(() => _otpSent = true);
      Get.snackbar('OTP Sent', 'Enter the 6-digit code sent to $_phoneNumber',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade900);
    } catch (e) {
      Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) {
      Get.snackbar('Required', 'Please enter the 6-digit OTP',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await ApiClient.post('/auth/verify-otp',
          {'phone_number': _phoneNumber, 'otp': otp});
      final data = result['data'] as Map<String, dynamic>? ?? result;
      final token = data['token'] ?? result['token'] ?? '';
      final userId = data['user_id'] ?? result['user_id'] ?? '';
      if (token.isNotEmpty) await TokenStorage.saveToken(token);
      if (userId.isNotEmpty) await TokenStorage.saveUserId(userId);
      await TokenStorage.savePhone(_phoneNumber);
      setState(() => _step = 1);
    } catch (e) {
      Get.snackbar('Invalid OTP', e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (final c in _otpControllers) { c.dispose(); }
    for (final f in _otpFocusNodes) { f.dispose(); }
    _orgNameController.dispose();
    _regNumberController.dispose();
    _gstController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _operatingHoursController.dispose();
    _staffCountController.dispose();
    super.dispose();
  }

  bool _validateStep1() {
    if (_orgNameController.text.trim().isEmpty) {
      Get.snackbar('Required', 'Please enter organization name',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (_regNumberController.text.trim().isEmpty) {
      Get.snackbar('Required', 'Please enter registration number',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_addressController.text.trim().isEmpty) {
      Get.snackbar('Required', 'Please enter address',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (_cityController.text.trim().isEmpty) {
      Get.snackbar('Required', 'Please enter city',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (_selectedCategories.isEmpty) {
      Get.snackbar('Required', 'Please select at least one service category',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final userId = await TokenStorage.getUserId() ?? '';
      final phone = _phoneNumber.isNotEmpty
          ? _phoneNumber
          : await TokenStorage.getPhone() ?? '';

      if (userId.isEmpty || phone.isEmpty) {
        Get.snackbar('Error', 'Session expired. Please log in again.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade100,
            colorText: Colors.red.shade900);
        setState(() => _isLoading = false);
        return;
      }

      final selectedNames = _availableServices
          .where((s) {
            final id = s['id']?.toString() ??
                s['_id']?.toString() ??
                s['name']?.toString() ??
                '';
            return _selectedCategories.contains(id);
          })
          .map((s) => s['name']?.toString() ?? '')
          .join(', ');

      final result = await ApiClient.post('/hospitals', {
        'user_id': userId,
        'phone_number': phone,
        'name': _orgNameController.text.trim(),
        'registration_number': _regNumberController.text.trim(),
        'type': _businessType,
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pin_code': _pincodeController.text.trim(),
        'specialties': selectedNames,
        'service_ids': _selectedCategories.toList(),
        'operating_hours': _operatingHoursController.text.trim(),
      });

      final dataMap = result['data'] as Map<String, dynamic>? ?? result;
      final hospitalId = dataMap['hospital_id'] ??
          dataMap['id'] ??
          result['hospital_id'] ??
          result['id'] ??
          '';

      await TokenStorage.saveNurseId(hospitalId.toString());
      await TokenStorage.saveApprovalStatus('PENDING');
      Get.toNamed('/doc-upload', arguments: {'nurseId': hospitalId.toString()});
    } catch (e) {
      Get.snackbar(
        'Registration Failed',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Organization Registration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step--);
            } else {
              Get.back();
            }
          },
        ),
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStep(),
            ),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    const totalSteps = 4;
    const labels = [
      'Phone Verification',
      'Organization Details',
      'Address & Services',
      'Review & Submit',
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(totalSteps, (i) {
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < totalSteps - 1) const SizedBox(width: 4),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            'Step ${_step + 1}: ${labels[_step]}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    if (_step == 0) return _buildStep0();
    if (_step == 1) return _buildStep1();
    if (_step == 2) return _buildStep2();
    return _buildStep3();
  }

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Phone Verification',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        const Text('Verify your mobile number to continue',
            style: TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 32),
        IntlPhoneField(
          decoration: _inputDec('Enter phone number', Icons.phone_outlined),
          initialCountryCode: 'IN',
          onChanged: (phone) {
            _phoneNumber = phone.completeNumber;
          },
          disableLengthCheck: false,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading || _otpSent ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(_otpSent ? 'OTP Sent' : 'Send OTP',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        if (_otpSent) ...[
          const SizedBox(height: 28),
          const Text('Enter OTP',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return SizedBox(
                width: 44,
                child: TextField(
                  controller: _otpControllers[i],
                  focusNode: _otpFocusNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF7C3AED), width: 2),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) {
                      _otpFocusNodes[i + 1].requestFocus();
                    } else if (v.isEmpty && i > 0) {
                      _otpFocusNodes[i - 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Verify OTP',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      for (final c in _otpControllers) { c.clear(); }
                      setState(() => _otpSent = false);
                    },
              child: const Text('Resend OTP',
                  style: TextStyle(color: Color(0xFF7C3AED))),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Organization Details',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        const Text('Tell us about your organization',
            style: TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 24),
        _label('Organization Name *'),
        TextField(
            controller: _orgNameController,
            decoration:
                _inputDec('Enter organization name', Icons.business)),
        const SizedBox(height: 16),
        _label('Registration Number *'),
        TextField(
            controller: _regNumberController,
            decoration:
                _inputDec('Enter reg. number', Icons.badge_outlined)),
        const SizedBox(height: 16),
        _label('Business Type'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _businessTypes.map((t) {
            return ChoiceChip(
              label: Text(t),
              selected: _businessType == t,
              selectedColor: const Color(0xFF7C3AED),
              labelStyle: TextStyle(
                  color: _businessType == t
                      ? Colors.white
                      : const Color(0xFF374151),
                  fontWeight: FontWeight.w500),
              onSelected: (_) => setState(() => _businessType = t),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _label('GST Number (optional)'),
        TextField(
            controller: _gstController,
            decoration:
                _inputDec('Enter GST number', Icons.receipt_long_outlined)),
        const SizedBox(height: 16),
        _label('Official Email'),
        TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration:
                _inputDec('Enter email', Icons.email_outlined)),
        const SizedBox(height: 16),
        _label('Website (optional)'),
        TextField(
            controller: _websiteController,
            keyboardType: TextInputType.url,
            decoration:
                _inputDec('https://www.example.com', Icons.language)),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Address & Services',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        const Text('Your location and service offerings',
            style: TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 24),
        _label('Address *'),
        TextField(
            controller: _addressController,
            maxLines: 2,
            decoration: _inputDec(
                'Enter full address', Icons.location_on_outlined)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('City *'),
                  TextField(
                      controller: _cityController,
                      decoration:
                          _inputDec('City', Icons.location_city)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('State'),
                  TextField(
                      controller: _stateController,
                      decoration: _inputDec('State', Icons.map_outlined)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _label('Pincode'),
        TextField(
            controller: _pincodeController,
            keyboardType: TextInputType.number,
            decoration:
                _inputDec('6-digit pincode', Icons.pin_drop_outlined)),
        const SizedBox(height: 16),
        _label('Service Categories *'),
        if (_servicesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF7C3AED))),
          )
        else if (_availableServices.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No services found. Please contact the admin.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableServices.map((svc) {
              final name = svc['name']?.toString() ?? '';
              final id = svc['id']?.toString() ??
                  svc['_id']?.toString() ??
                  name;
              final selected = _selectedCategories.contains(id);
              return FilterChip(
                label: Text(name),
                selected: selected,
                selectedColor: const Color(0xFF7C3AED),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                    color: selected
                        ? Colors.white
                        : const Color(0xFF374151),
                    fontWeight: FontWeight.w500,
                    fontSize: 12),
                onSelected: (v) => setState(() {
                  if (v) {
                    _selectedCategories.add(id);
                  } else {
                    _selectedCategories.remove(id);
                  }
                }),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
        _label('Operating Hours'),
        TextField(
            controller: _operatingHoursController,
            decoration: _inputDec(
                'e.g., 8AM - 8PM, Mon-Sat', Icons.schedule_outlined)),
        const SizedBox(height: 16),
        _label('Staff Count'),
        TextField(
            controller: _staffCountController,
            keyboardType: TextInputType.number,
            decoration: _inputDec(
                'Number of staff members', Icons.group_outlined)),
      ],
    );
  }

  Widget _buildStep3() {
    final selectedNames = _availableServices
        .where((s) {
          final id = s['id']?.toString() ??
              s['_id']?.toString() ??
              s['name']?.toString() ??
              '';
          return _selectedCategories.contains(id);
        })
        .map((s) => s['name']?.toString() ?? '')
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review & Submit',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        const Text('Confirm organization registration',
            style: TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 24),
        _reviewCard('Organization Information', [
          _reviewRow('Phone', _phoneNumber),
          _reviewRow('Name', _orgNameController.text),
          _reviewRow('Registration No.', _regNumberController.text),
          _reviewRow('Business Type', _businessType),
          _reviewRow('GST',
              _gstController.text.isEmpty ? 'Not provided' : _gstController.text),
          _reviewRow('Email',
              _emailController.text.isEmpty ? 'Not provided' : _emailController.text),
          _reviewRow('Website',
              _websiteController.text.isEmpty ? 'Not provided' : _websiteController.text),
        ]),
        const SizedBox(height: 16),
        _reviewCard('Address & Services', [
          _reviewRow('Address', _addressController.text),
          _reviewRow('City', _cityController.text),
          _reviewRow('State',
              _stateController.text.isEmpty ? 'Not set' : _stateController.text),
          _reviewRow('Pincode',
              _pincodeController.text.isEmpty ? 'Not set' : _pincodeController.text),
          _reviewRow(
              'Services', selectedNames.isEmpty ? 'None selected' : selectedNames),
          _reviewRow('Operating Hours',
              _operatingHoursController.text.isEmpty
                  ? 'Not set'
                  : _operatingHoursController.text),
          _reviewRow('Staff Count',
              _staffCountController.text.isEmpty ? 'Not set' : _staffCountController.text),
        ]),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDD6FE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF7C3AED), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'After registration, upload your organization\'s documents for verification. Approval typically takes 1-3 business days.',
                  style:
                      TextStyle(fontSize: 13, color: Color(0xFF6D28D9)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewCard(String title, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF1E293B))),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ...rows,
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF64748B))),
          ),
          Expanded(
            flex: 3,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading
              ? null
              : () {
                  if (_step == 0) {
                    // handled by inline buttons
                  } else if (_step == 1) {
                    if (_validateStep1()) setState(() => _step = 2);
                  } else if (_step == 2) {
                    if (_validateStep2()) setState(() => _step = 3);
                  } else {
                    _submit();
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  _step == 0
                      ? 'Verify Phone First'
                      : _step < 3
                          ? 'Continue'
                          : 'Register Organization',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151))),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF7C3AED), width: 2)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }
}
