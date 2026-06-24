import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:home_care_admin/core/api_client.dart';
import 'package:home_care_admin/core/token_storage.dart';

class IndividualProfileScreen extends StatefulWidget {
  const IndividualProfileScreen({super.key});

  @override
  State<IndividualProfileScreen> createState() =>
      _IndividualProfileScreenState();
}

class _IndividualProfileScreenState extends State<IndividualProfileScreen> {
  int _step = 0;
  bool _isLoading = false;

  // Step 0: Phone verification
  String _phoneNumber = '';
  bool _otpSent = false;
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // Step 1 fields
  final _nameController = TextEditingController();
  String _gender = 'MALE';
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();

  // Step 2 fields
  final Set<String> _selectedServices = {};
  List<Map<String, dynamic>> _availableServices = [];
  bool _servicesLoading = false;
  final _qualificationController = TextEditingController();
  int _experience = 0;
  String _shift = 'DAY';
  final _hourlyRateController = TextEditingController();
  final _dailyRateController = TextEditingController();
  bool _emergencyCapable = false;
  final _serviceAreaController = TextEditingController();

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
        _availableServices = list.map((e) => e as Map<String, dynamic>).toList();
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
    _nameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _qualificationController.dispose();
    _hourlyRateController.dispose();
    _dailyRateController.dispose();
    _serviceAreaController.dispose();
    super.dispose();
  }

  bool _validateStep1() {
    if (_nameController.text.trim().isEmpty) {
      Get.snackbar('Required', 'Please enter your full name',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (_cityController.text.trim().isEmpty) {
      Get.snackbar('Required', 'Please enter your city',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_selectedServices.isEmpty) {
      Get.snackbar('Required', 'Please select at least one service',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (_qualificationController.text.trim().isEmpty) {
      Get.snackbar('Required', 'Please enter your qualification',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (_hourlyRateController.text.trim().isEmpty) {
      Get.snackbar('Required', 'Please enter your hourly rate',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (_serviceAreaController.text.trim().isEmpty) {
      Get.snackbar('Required', 'Please enter your service area',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final userId = await TokenStorage.getUserId() ?? '';

      final profileUpdate = <String, dynamic>{};
      final name = _nameController.text.trim();
      if (name.isNotEmpty) profileUpdate['name'] = name;
      final email = _emailController.text.trim();
      if (email.isNotEmpty) profileUpdate['email'] = email;
      profileUpdate['gender'] = _gender;
      if (profileUpdate.isNotEmpty && userId.isNotEmpty) {
        try {
          await ApiClient.post('/user/$userId/update', profileUpdate);
        } catch (_) {}
      }

      final result = await ApiClient.post('/nurses', {
        'user_id': userId,
        'phone_number': _phoneNumber,
        'qualification': _qualificationController.text.trim(),
        'category': _selectedServices.isNotEmpty
            ? _selectedServices.first
            : 'GENERAL',
        'categories': _selectedServices.toList(),
        'id_proof_type': 'AADHAAR',
        'id_proof_number': '0000',
        'years_of_experience': _experience,
        'service_area': _serviceAreaController.text.trim(),
        'shift_availability': _shift,
        'emergency_capable': _emergencyCapable,
        'hourly_rate':
            double.tryParse(_hourlyRateController.text.trim()) ?? 0.0,
        'daily_rate':
            double.tryParse(_dailyRateController.text.trim()) ?? 0.0,
      });

      final dataMap = result['data'] as Map<String, dynamic>? ?? result;
      final nurseId = dataMap['nurse_id'] ??
          dataMap['id'] ??
          result['nurse_id'] ??
          result['id'] ??
          '';
      await TokenStorage.saveNurseId(nurseId.toString());
      await TokenStorage.saveApprovalStatus('PENDING');

      Get.toNamed('/doc-upload', arguments: {'nurseId': nurseId.toString()});
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
        title: const Text('Provider Registration'),
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
    final totalSteps = 4;
    final labels = [
      'Phone Verification',
      'Basic Details',
      'Professional Details',
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
                              ? const Color(0xFF2563EB)
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
              backgroundColor: const Color(0xFF2563EB),
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
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF2563EB), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                  style: TextStyle(color: Color(0xFF2563EB))),
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
        const Text('Basic Details',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        const Text('Tell us about yourself',
            style: TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 24),
        _label('Full Name *'),
        TextField(
          controller: _nameController,
          decoration: _inputDec('Enter your full name', Icons.person_outline),
        ),
        const SizedBox(height: 16),
        _label('Gender'),
        Wrap(
          spacing: 10,
          children: ['MALE', 'FEMALE', 'OTHER'].map((g) {
            return ChoiceChip(
              label: Text(g),
              selected: _gender == g,
              selectedColor: const Color(0xFF2563EB),
              labelStyle: TextStyle(
                  color: _gender == g ? Colors.white : const Color(0xFF374151),
                  fontWeight: FontWeight.w500),
              onSelected: (_) => setState(() => _gender = g),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _label('Date of Birth'),
        TextField(
          controller: _dobController,
          readOnly: true,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime(1990),
              firstDate: DateTime(1950),
              lastDate:
                  DateTime.now().subtract(const Duration(days: 365 * 18)),
            );
            if (date != null) {
              _dobController.text =
                  '${date.day}/${date.month}/${date.year}';
            }
          },
          decoration:
              _inputDec('Select date of birth', Icons.calendar_today),
        ),
        const SizedBox(height: 16),
        _label('Email (optional)'),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration:
              _inputDec('Enter your email', Icons.email_outlined),
        ),
        const SizedBox(height: 16),
        _label('City *'),
        TextField(
          controller: _cityController,
          decoration:
              _inputDec('Enter your city', Icons.location_city_outlined),
        ),
        const SizedBox(height: 16),
        _label('Pincode'),
        TextField(
          controller: _pincodeController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration:
              _inputDec('6-digit pincode', Icons.pin_drop_outlined),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Professional Details',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        const Text('Your expertise and availability',
            style: TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 24),
        _label('Services You Offer *'),
        if (_servicesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF2563EB))),
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
              final id = svc['id']?.toString() ?? svc['_id']?.toString() ?? name;
              final selected = _selectedServices.contains(id);
              return FilterChip(
                label: Text(name),
                selected: selected,
                selectedColor: const Color(0xFF2563EB),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                    color: selected
                        ? Colors.white
                        : const Color(0xFF374151),
                    fontWeight: FontWeight.w500,
                    fontSize: 12),
                onSelected: (v) => setState(() {
                  if (v) {
                    _selectedServices.add(id);
                  } else {
                    _selectedServices.remove(id);
                  }
                }),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
        _label('Qualification *'),
        TextField(
          controller: _qualificationController,
          decoration:
              _inputDec('e.g., B.Sc Nursing, GNM', Icons.school_outlined),
        ),
        const SizedBox(height: 16),
        _label('Years of Experience'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.work_history_outlined,
                  color: Color(0xFF94A3B8), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _experience.toDouble(),
                  min: 0,
                  max: 40,
                  divisions: 40,
                  label: '$_experience years',
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (v) =>
                      setState(() => _experience = v.round()),
                ),
              ),
              Text(
                '$_experience yr',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _label('Shift Availability'),
        Wrap(
          spacing: 10,
          children: ['DAY', 'NIGHT', 'BOTH'].map((s) {
            return ChoiceChip(
              label: Text(s),
              selected: _shift == s,
              selectedColor: const Color(0xFF2563EB),
              labelStyle: TextStyle(
                  color:
                      _shift == s ? Colors.white : const Color(0xFF374151),
                  fontWeight: FontWeight.w500),
              onSelected: (_) => setState(() => _shift = s),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Hourly Rate (₹) *'),
                  TextField(
                    controller: _hourlyRateController,
                    keyboardType: TextInputType.number,
                    decoration:
                        _inputDec('e.g., 300', Icons.currency_rupee),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Daily Rate (₹)'),
                  TextField(
                    controller: _dailyRateController,
                    keyboardType: TextInputType.number,
                    decoration:
                        _inputDec('e.g., 2000', Icons.currency_rupee),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _label('Service Area *'),
        TextField(
          controller: _serviceAreaController,
          decoration: _inputDec(
              'e.g., Koramangala, Bangalore', Icons.map_outlined),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: SwitchListTile(
            title: const Text('Emergency Capable',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text(
              'Available for emergency home visits',
              style:
                  TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            value: _emergencyCapable,
            activeThumbColor: const Color(0xFF2563EB),
            onChanged: (v) => setState(() => _emergencyCapable = v),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final selectedServiceNames = _availableServices
        .where((s) {
          final id =
              s['id']?.toString() ?? s['_id']?.toString() ?? s['name']?.toString() ?? '';
          return _selectedServices.contains(id);
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
        const Text('Confirm your registration details',
            style: TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 24),
        _reviewCard('Basic Information', [
          _reviewRow('Phone', _phoneNumber),
          _reviewRow('Full Name', _nameController.text),
          _reviewRow('Gender', _gender),
          _reviewRow('Date of Birth',
              _dobController.text.isEmpty ? 'Not set' : _dobController.text),
          _reviewRow('Email',
              _emailController.text.isEmpty ? 'Not set' : _emailController.text),
          _reviewRow('City', _cityController.text),
          _reviewRow('Pincode',
              _pincodeController.text.isEmpty ? 'Not set' : _pincodeController.text),
        ]),
        const SizedBox(height: 16),
        _reviewCard('Professional Details', [
          _reviewRow('Services',
              selectedServiceNames.isEmpty ? 'None' : selectedServiceNames),
          _reviewRow('Qualification', _qualificationController.text),
          _reviewRow('Experience', '$_experience years'),
          _reviewRow('Shift', _shift),
          _reviewRow('Hourly Rate', '₹${_hourlyRateController.text}/hr'),
          _reviewRow('Daily Rate',
              _dailyRateController.text.isEmpty
                  ? 'Not set'
                  : '₹${_dailyRateController.text}/day'),
          _reviewRow('Service Area', _serviceAreaController.text),
          _reviewRow(
              'Emergency Capable', _emergencyCapable ? 'Yes' : 'No'),
        ]),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'After registration, you\'ll be asked to upload verification documents. Your account will be reviewed by our team.',
                  style:
                      TextStyle(fontSize: 13, color: Color(0xFF1D4ED8)),
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
            backgroundColor: const Color(0xFF2563EB),
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
                          : 'Register as Provider',
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
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF2563EB), width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }
}
