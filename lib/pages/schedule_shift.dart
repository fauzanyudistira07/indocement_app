import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indocement_apk/pages/bpjs_page.dart';
import 'package:indocement_apk/pages/hr_menu.dart';
import 'package:indocement_apk/pages/id_card.dart';
import 'package:indocement_apk/pages/layanan_menu.dart';
import 'package:indocement_apk/pages/skkmedic_page.dart';
import 'package:indocement_apk/service/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduleShiftPage extends StatefulWidget {
  const ScheduleShiftPage({super.key});

  @override
  State<ScheduleShiftPage> createState() => _ScheduleShiftPageState();
}

class _ScheduleShiftPageState extends State<ScheduleShiftPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _employees = [];
  final List<Map<String, dynamic>> _selectedPairs = [];
  DateTime? _selectedDate;
  final _keteranganController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingShifts = true;
  String? _userSection;
  int? _userIdEmployee;

  List<String> _shiftOptions = [];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fetchShiftOptions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _fetchShiftOptions() async {
    try {
      setState(() {
        _isLoadingShifts = true;
      });

      final response = await ApiService.get(
        'http://103.31.235.237:5555/api/JadwalShift',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      print('Fetch Shift Options Status: ${response.statusCode}');
      print('Fetch Shift Options Body: ${response.data}');

      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = response.data;
        final List<String> shiftNames = data
            .map((shift) => shift['NamaShift']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();

        if (shiftNames.isNotEmpty) {
          setState(() {
            _shiftOptions = shiftNames;
            _isLoadingShifts = false;
            print('Updated _shiftOptions: $_shiftOptions');
          });
          _loadEmployeeData();
        } else {
          print('No valid shift names found in API response');
          if (mounted) {
            _showErrorModal('Tidak ada data shift yang valid dari server.');
            setState(() {
              _isLoadingShifts = false;
            });
          }
        }
      } else {
        print('Failed to fetch shift options: ${response.statusCode}');
        if (mounted) {
          _showErrorModal('Gagal memuat data shift: ${response.statusCode}');
          setState(() {
            _isLoadingShifts = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching shift options: $e');
      if (mounted) {
        _showErrorModal('Terjadi kesalahan saat memuat data shift: $e');
        setState(() {
          _isLoadingShifts = false;
        });
      }
    }
  }

  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  void _showErrorModal(String message) {
    if (!mounted) return;
    String displayMessage = message;
    try {
      if (message.contains('Gagal mengajukan pengajuan:') &&
          message.contains('{')) {
        final jsonStart = message.indexOf('{');
        final jsonStr = message.substring(jsonStart);
        final errorJson = jsonDecode(jsonStr);
        final errors = errorJson['errors'] as Map<String, dynamic>?;
        if (errors != null) {
          final errorMessages = errors.values
              .expand((e) => e as List<dynamic>)
              .map((e) => e.toString())
              .join('; ');
          displayMessage = 'Gagal mengajukan pengajuan: $errorMessages';
        }
      }
    } catch (e) {
      print('Error parsing error response: $e');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 54,
                ),
                const SizedBox(height: 18),
                Text(
                  'Gagal',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Colors.red,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  displayMessage,
                  style: GoogleFonts.poppins(
                    fontSize: 16.5,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'OK',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessModal() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF1572E8),
                  size: 54,
                ),
                const SizedBox(height: 18),
                Text(
                  'Berhasil',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Color(0xFF1572E8),
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Pengajuan tukar shift berhasil dikirim.',
                  style: GoogleFonts.poppins(
                    fontSize: 16.5,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1572E8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LayananMenuPage(),
                        ),
                      );
                    },
                    child: Text(
                      'OK',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadEmployeeData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      if (_shiftOptions.isEmpty) {
        if (mounted) {
          _showErrorModal(
              'Data shift belum tersedia. Silakan coba lagi nanti.');
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? idEmployee = prefs.getInt('idEmployee');
      if (idEmployee == null) {
        if (mounted) {
          _showErrorModal('ID pengguna tidak ditemukan. Silakan login ulang.');
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
      _userIdEmployee = idEmployee;

      final userResponse = await ApiService.get(
        'http://103.31.235.237:5555/api/User',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      print('Fetch User Status: ${userResponse.statusCode}');
      print('Fetch User Body: ${userResponse.data}');

      if (userResponse.statusCode != 200) {
        if (mounted) {
          _showErrorModal('Gagal memuat data pengguna: ${userResponse.data}');
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final List<dynamic> userData = userResponse.data;
      final Set<int> activeKaryawanIds = userData
          .where(
              (user) => user['Status'] == 'Aktif' && user['Role'] == 'Karyawan')
          .map((user) => user['IdEmployee'] as int)
          .toSet();
      print('Active Karyawan IdEmployee: $activeKaryawanIds');

      final employeeResponse = await ApiService.get(
        'http://103.31.235.237:5555/api/Employees/$idEmployee',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      print('Fetch User Employee Status: ${employeeResponse.statusCode}');
      print('Fetch User Employee Body: ${employeeResponse.data}');

      if (employeeResponse.statusCode != 200) {
        if (mounted) {
          _showErrorModal(
              'Gagal memuat data pengguna: ${employeeResponse.data}');
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final employeeData = employeeResponse.data;
      _userSection = employeeData['IdSection']?.toString();
      print(
          'User ID: $idEmployee, IdSection: $_userSection, User Data: $employeeData');

      if (_userSection == null || _userSection!.isEmpty) {
        if (mounted) {
          _showErrorModal('IdSection pengguna tidak ditemukan dalam data.');
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final allEmployeesResponse = await ApiService.get(
        'http://103.31.235.237:5555/api/Employees',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      print('Fetch All Employees Status: ${allEmployeesResponse.statusCode}');
      print('Fetch All Employees Body: ${allEmployeesResponse.data}');

      if (allEmployeesResponse.statusCode == 200) {
        final List<dynamic> data = allEmployeesResponse.data;
        print('Raw Employee Data: $data');
        final Map<int, Map<String, dynamic>> uniqueEmployees = {};
        for (var e in data) {
          final idEsl = e['IdEsl'] ?? e['idEsl'] ?? e['IDESL'];
          final int id = e['Id'];
          if (e['IdSection']?.toString() == _userSection &&
              (idEsl == 4 || idEsl == 5 || idEsl == 6) &&
              activeKaryawanIds.contains(id)) {
            if (!uniqueEmployees.containsKey(id)) {
              uniqueEmployees[id] = {
                'IdEmployee': id,
                'EmployeeName': e['EmployeeName'] ?? 'Unknown',
                'IdSection': e['IdSection']?.toString() ?? '',
                'IdEsl': idEsl,
              };
              print(
                  'Included Employee: Id=$id, Name=${e['EmployeeName']}, Section=${e['IdSection']}, IdEsl=$idEsl');
            } else {
              print('Skipped Duplicate Employee: Id=$id');
            }
          } else {
            print(
                'Excluded Employee: Id=$id, Section=${e['IdSection']}, IdEsl=$idEsl, IsActiveKaryawan=${activeKaryawanIds.contains(id)}');
          }
        }
        if (mounted) {
          setState(() {
            _employees = uniqueEmployees.values.toList();
            print(
                'Filtered Employees (IdSection=$_userSection, IdEsl=4,5,6, Active Karyawan): $_employees');
            if (_employees.any((e) => e['IdEmployee'] == idEmployee)) {
              _selectedPairs.add({
                'IdEmployee': idEmployee,
                'EmployeeName': 'Anda',
                'DariShift': null,
                'KeShift': null,
              });
              print(
                  'Added current user to selectedPairs: IdEmployee=$idEmployee');
            } else {
              print(
                  'Warning: Current user (IdEmployee=$idEmployee) not found in filtered employees');
            }
            _isLoading = false;
          });

          final idSet = _employees.map((e) => e['IdEmployee']).toSet();
          if (idSet.length != _employees.length) {
            print('Warning: Duplicate IdEmployee found in _employees');
          }
        }
      } else {
        if (mounted) {
          _showErrorModal(
              'Gagal memuat data karyawan: ${allEmployeesResponse.data}');
        }
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading employee data: $e');
      if (mounted) {
        _showErrorModal('Terjadi kesalahan: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      return;
    }
    if (_shiftOptions.isEmpty) {
      if (mounted) {
        _showErrorModal('Data shift belum tersedia. Silakan coba lagi nanti.');
      }
      return;
    }
    if (_selectedPairs.length > 4 || _selectedPairs.length % 2 != 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Jumlah karyawan harus genap (2 atau 4) untuk tukar shift',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
      return;
    }
    if (_selectedDate == null || _selectedDate!.isBefore(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pilih tanggal shift yang valid (anda harus mengajukan minimal satu hari sebelum tanggal tukar shift).',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
      return;
    }
    for (var pair in _selectedPairs) {
      print('Validating pair: $pair');
      if (pair['IdEmployee'] == null ||
          pair['DariShift'] == null ||
          pair['KeShift'] == null ||
          pair['DariShift'] == pair['KeShift']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Data karyawan atau shift tidak valid. Pastikan semua shift berbeda dan diisi. Pair: ${pair['EmployeeName']}',
                style: GoogleFonts.poppins(),
              ),
            ),
          );
        }
        return;
      }
    }

    try {
      _showLoading(context);
      final requestBody = _selectedPairs
          .map((pair) => {
                'IdEmployee': pair['IdEmployee'],
                'TglPengajuan': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                'TglShift': DateFormat('yyyy-MM-dd').format(_selectedDate!),
                'DariShift': pair['DariShift'],
                'KeShift': pair['KeShift'],
                'Keterangan': _keteranganController.text,
                'Status': 'Diajukan',
              })
          .toList();

      print('Selected Pairs before submission: $_selectedPairs');
      print('Submitting request: $requestBody');

      const maxRetries = 3;
      var attempt = 0;

      while (attempt < maxRetries) {
        try {
          for (var pair in requestBody) {
            final response = await ApiService.post(
              'http://103.31.235.237:5555/api/TukarSchedule',
              data: pair,
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            );
            print(
                'API Response for pair ${pair['IdEmployee']}: ${response.statusCode} - ${response.data}');
            if (response.statusCode != 200 && response.statusCode != 201) {
              throw Exception(
                  'Failed for employee ${pair['IdEmployee']}: ${response.data}');
            }
          }
          break;
        } catch (e) {
          attempt++;
          if (attempt >= maxRetries) {
            throw Exception(
                'Gagal mengajukan pengajuan setelah $maxRetries percobaan: $e');
          }
          print('Retry $attempt/$maxRetries due to error: $e');
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      Navigator.of(context).pop(); // Close loading dialog

      if (mounted) {
        _showSuccessModal();
      }
    } catch (e) {
      print('Error submitting form: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showErrorModal('Terjadi kesalahan: $e');
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double screenHeight = constraints.maxHeight;
        final double paddingValue = screenWidth * 0.04;
        final double baseFontSize = screenWidth * 0.04;

        final availableEmployees = _employees
            .where((e) =>
                e['IdEmployee'] != null &&
                !_selectedPairs
                    .any((pair) => pair['IdEmployee'] == e['IdEmployee']))
            .toList();

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LayananMenuPage(),
                  ),
                );
              },
            ),
            title: Text(
              'Tukar Schedule Shift',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: baseFontSize * 1.25,
                color: Colors.white,
              ),
            ),
            backgroundColor: const Color(0xFF1572E8),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Stack(
            children: [
              _isLoading || _isLoadingShifts
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: EdgeInsets.all(paddingValue),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: EdgeInsets.only(bottom: paddingValue),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Form untuk mengajukan tukar schedule shift. Pilih karyawan dari seksi yang sama (maksimal 2 pasangan).',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: baseFontSize * 0.9,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: paddingValue * 0.5),
                          Expanded(
                            child: Form(
                              key: _formKey,
                              child: ListView(
                                padding: EdgeInsets.zero,
                                children: [
                                  Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                    child: Padding(
                                      padding: EdgeInsets.all(paddingValue),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Pilih Karyawan (Maks. 2 Pasangan)',
                                            style: GoogleFonts.poppins(
                                              fontSize: baseFontSize * 0.9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: Colors.grey),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            child: availableEmployees.isEmpty
                                                ? Text(
                                                    'Tidak ada karyawan yang tersedia. Pastikan ada karyawan aktif di seksi $_userSection dengan Id Esl= 4 - 6.',
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.red,
                                                      fontSize: 14,
                                                    ),
                                                  )
                                                : DropdownButton<int>(
                                                    isExpanded: true,
                                                    hint: Text(
                                                      'Pilih karyawan',
                                                      style:
                                                          GoogleFonts.poppins(),
                                                    ),
                                                    value: null,
                                                    items: availableEmployees
                                                        .map((employee) {
                                                      return DropdownMenuItem<
                                                          int>(
                                                        value: employee[
                                                                'IdEmployee']
                                                            as int,
                                                        child: Text(
                                                          employee[
                                                              'EmployeeName'],
                                                          style: GoogleFonts
                                                              .poppins(),
                                                        ),
                                                      );
                                                    }).toList(),
                                                    onChanged: (int? value) {
                                                      if (value != null) {
                                                        if (_selectedPairs
                                                                .length <
                                                            4) {
                                                          final employee =
                                                              _employees
                                                                  .firstWhere(
                                                            (e) =>
                                                                e['IdEmployee'] ==
                                                                value,
                                                            orElse: () => {
                                                              'IdEmployee':
                                                                  value,
                                                              'EmployeeName':
                                                                  'Unknown',
                                                              'IdSection':
                                                                  _userSection ??
                                                                      '',
                                                            },
                                                          );
                                                          setState(() {
                                                            _selectedPairs.add({
                                                              'IdEmployee':
                                                                  value,
                                                              'EmployeeName':
                                                                  employee[
                                                                      'EmployeeName'],
                                                              'DariShift': null,
                                                              'KeShift': null,
                                                            });
                                                          });
                                                        } else {
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                'Maksimal 2 pasangan (4 karyawan)',
                                                                style: GoogleFonts
                                                                    .poppins(),
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    },
                                                    underline: const SizedBox(),
                                                  ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...List.generate(
                                            (_selectedPairs.length / 2).ceil(),
                                            (index) {
                                              final pairIndex = index * 2;
                                              final employee1 = pairIndex <
                                                      _selectedPairs.length
                                                  ? _selectedPairs[pairIndex]
                                                  : null;
                                              final employee2 = pairIndex + 1 <
                                                      _selectedPairs.length
                                                  ? _selectedPairs[
                                                      pairIndex + 1]
                                                  : null;
                                              return Card(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Pasangan ${index + 1}',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize:
                                                              baseFontSize *
                                                                  0.9,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      if (employee1 !=
                                                          null) ...[
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                employee1[
                                                                    'EmployeeName'],
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(
                                                                Icons.delete,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                              onPressed: employee1[
                                                                          'IdEmployee'] ==
                                                                      _userIdEmployee
                                                                  ? null
                                                                  : () {
                                                                      setState(
                                                                          () {
                                                                        _selectedPairs
                                                                            .removeAt(pairIndex);
                                                                        if (employee2 !=
                                                                            null) {
                                                                          _selectedPairs
                                                                              .removeAt(pairIndex);
                                                                        }
                                                                      });
                                                                    },
                                                            ),
                                                          ],
                                                        ),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child:
                                                                  DropdownButtonFormField<
                                                                      String>(
                                                                isExpanded:
                                                                    true,
                                                                hint: Text(
                                                                  _shiftOptions
                                                                          .isEmpty
                                                                      ? 'Memuat shift...'
                                                                      : 'Dari Shift',
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                    color: _shiftOptions
                                                                            .isEmpty
                                                                        ? Colors
                                                                            .grey
                                                                        : null,
                                                                  ),
                                                                ),
                                                                value: employee1[
                                                                    'DariShift'],
                                                                items: _shiftOptions
                                                                        .isEmpty
                                                                    ? []
                                                                    : _shiftOptions
                                                                        .map(
                                                                            (shift) {
                                                                        return DropdownMenuItem<
                                                                            String>(
                                                                          value:
                                                                              shift,
                                                                          child:
                                                                              Text(
                                                                            shift,
                                                                            style:
                                                                                GoogleFonts.poppins(),
                                                                          ),
                                                                        );
                                                                      }).toList(),
                                                                onChanged:
                                                                    _shiftOptions
                                                                            .isEmpty
                                                                        ? null
                                                                        : (value) {
                                                                            setState(() {
                                                                              employee1['DariShift'] = value;
                                                                              if (employee2 != null && value != null) {
                                                                                employee2['KeShift'] = value;
                                                                                if (employee2['DariShift'] == value) {
                                                                                  employee2['DariShift'] = employee1['KeShift'];
                                                                                }
                                                                              }
                                                                            });
                                                                          },
                                                                decoration:
                                                                    InputDecoration(
                                                                  border:
                                                                      OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(8),
                                                                  ),
                                                                  contentPadding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          8),
                                                                ),
                                                                disabledHint:
                                                                    Text(
                                                                  'Tidak ada shift tersedia',
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                          color:
                                                                              Colors.grey),
                                                                ),
                                                                validator:
                                                                    (value) {
                                                                  if (value ==
                                                                          null ||
                                                                      value
                                                                          .isEmpty) {
                                                                    return 'Pilih Dari Shift';
                                                                  }
                                                                  return null;
                                                                },
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 8),
                                                            Expanded(
                                                              child:
                                                                  DropdownButtonFormField<
                                                                      String>(
                                                                isExpanded:
                                                                    true,
                                                                hint: Text(
                                                                  _shiftOptions
                                                                          .isEmpty
                                                                      ? 'Memuat shift...'
                                                                      : 'Ke Shift',
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                    color: _shiftOptions
                                                                            .isEmpty
                                                                        ? Colors
                                                                            .grey
                                                                        : null,
                                                                  ),
                                                                ),
                                                                value: employee1[
                                                                    'KeShift'],
                                                                items: _shiftOptions
                                                                        .isEmpty
                                                                    ? []
                                                                    : _shiftOptions
                                                                        .map(
                                                                            (shift) {
                                                                        return DropdownMenuItem<
                                                                            String>(
                                                                          value:
                                                                              shift,
                                                                          child:
                                                                              Text(
                                                                            shift,
                                                                            style:
                                                                                GoogleFonts.poppins(),
                                                                          ),
                                                                        );
                                                                      }).toList(),
                                                                onChanged:
                                                                    _shiftOptions
                                                                            .isEmpty
                                                                        ? null
                                                                        : (value) {
                                                                            setState(() {
                                                                              employee1['KeShift'] = value;
                                                                              if (employee2 != null && value != null) {
                                                                                employee2['DariShift'] = value;
                                                                                if (employee2['KeShift'] == value) {
                                                                                  employee2['KeShift'] = employee1['DariShift'];
                                                                                }
                                                                              }
                                                                            });
                                                                          },
                                                                decoration:
                                                                    InputDecoration(
                                                                  border:
                                                                      OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(8),
                                                                  ),
                                                                  contentPadding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          8),
                                                                ),
                                                                disabledHint:
                                                                    Text(
                                                                  'Tidak ada shift tersedia',
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                          color:
                                                                              Colors.grey),
                                                                ),
                                                                validator:
                                                                    (value) {
                                                                  if (value ==
                                                                          null ||
                                                                      value
                                                                          .isEmpty) {
                                                                    return 'Pilih Ke Shift';
                                                                  }
                                                                  return null;
                                                                },
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                      if (employee2 !=
                                                          null) ...[
                                                        const SizedBox(
                                                            height: 8),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                employee2[
                                                                    'EmployeeName'],
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(
                                                                Icons.delete,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                              onPressed: employee2[
                                                                          'IdEmployee'] ==
                                                                      _userIdEmployee
                                                                  ? null
                                                                  : () {
                                                                      setState(
                                                                          () {
                                                                        _selectedPairs.removeAt(
                                                                            pairIndex +
                                                                                1);
                                                                      });
                                                                    },
                                                            ),
                                                          ],
                                                        ),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child:
                                                                  DropdownButtonFormField<
                                                                      String>(
                                                                isExpanded:
                                                                    true,
                                                                hint: Text(
                                                                  _shiftOptions
                                                                          .isEmpty
                                                                      ? 'Memuat shift...'
                                                                      : 'Dari Shift',
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                    color: _shiftOptions
                                                                            .isEmpty
                                                                        ? Colors
                                                                            .grey
                                                                        : null,
                                                                  ),
                                                                ),
                                                                value: employee2[
                                                                    'DariShift'],
                                                                items: _shiftOptions
                                                                        .isEmpty
                                                                    ? []
                                                                    : _shiftOptions
                                                                        .map(
                                                                            (shift) {
                                                                        return DropdownMenuItem<
                                                                            String>(
                                                                          value:
                                                                              shift,
                                                                          child:
                                                                              Text(
                                                                            shift,
                                                                            style:
                                                                                GoogleFonts.poppins(),
                                                                          ),
                                                                        );
                                                                      }).toList(),
                                                                onChanged:
                                                                    _shiftOptions
                                                                            .isEmpty
                                                                        ? null
                                                                        : (value) {
                                                                            setState(() {
                                                                              employee2['DariShift'] = value;
                                                                              if (value != null) {
                                                                                employee1?['KeShift'] = value;
                                                                                if (employee1?['DariShift'] == value) {
                                                                                  employee1?['DariShift'] = employee2['KeShift'];
                                                                                }
                                                                              }
                                                                            });
                                                                          },
                                                                decoration:
                                                                    InputDecoration(
                                                                  border:
                                                                      OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(8),
                                                                  ),
                                                                  contentPadding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          8),
                                                                ),
                                                                disabledHint:
                                                                    Text(
                                                                  'Tidak ada shift tersedia',
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                          color:
                                                                              Colors.grey),
                                                                ),
                                                                validator:
                                                                    (value) {
                                                                  if (value ==
                                                                          null ||
                                                                      value
                                                                          .isEmpty) {
                                                                    return 'Pilih Dari Shift';
                                                                  }
                                                                  return null;
                                                                },
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 8),
                                                            Expanded(
                                                              child:
                                                                  DropdownButtonFormField<
                                                                      String>(
                                                                isExpanded:
                                                                    true,
                                                                hint: Text(
                                                                  _shiftOptions
                                                                          .isEmpty
                                                                      ? 'Memuat shift...'
                                                                      : 'Ke Shift',
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                    color: _shiftOptions
                                                                            .isEmpty
                                                                        ? Colors
                                                                            .grey
                                                                        : null,
                                                                  ),
                                                                ),
                                                                value: employee2[
                                                                    'KeShift'],
                                                                items: _shiftOptions
                                                                        .isEmpty
                                                                    ? []
                                                                    : _shiftOptions
                                                                        .map(
                                                                            (shift) {
                                                                        return DropdownMenuItem<
                                                                            String>(
                                                                          value:
                                                                              shift,
                                                                          child:
                                                                              Text(
                                                                            shift,
                                                                            style:
                                                                                GoogleFonts.poppins(),
                                                                          ),
                                                                        );
                                                                      }).toList(),
                                                                onChanged:
                                                                    _shiftOptions
                                                                            .isEmpty
                                                                        ? null
                                                                        : (value) {
                                                                            setState(() {
                                                                              employee2['KeShift'] = value;
                                                                              if (value != null) {
                                                                                employee1?['DariShift'] = value;
                                                                                if (employee1?['KeShift'] == value) {
                                                                                  employee1?['KeShift'] = employee2['DariShift'];
                                                                                }
                                                                              }
                                                                            });
                                                                          },
                                                                decoration:
                                                                    InputDecoration(
                                                                  border:
                                                                      OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(8),
                                                                  ),
                                                                  contentPadding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          8),
                                                                ),
                                                                disabledHint:
                                                                    Text(
                                                                  'Tidak ada shift tersedia',
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                          color:
                                                                              Colors.grey),
                                                                ),
                                                                validator:
                                                                    (value) {
                                                                  if (value ==
                                                                          null ||
                                                                      value
                                                                          .isEmpty) {
                                                                    return 'Pilih Ke Shift';
                                                                  }
                                                                  return null;
                                                                },
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Tanggal Shift',
                                            style: GoogleFonts.poppins(
                                              fontSize: baseFontSize * 0.9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          InkWell(
                                            onTap: () => _selectDate(context),
                                            child: InputDecorator(
                                              decoration: InputDecoration(
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8),
                                              ),
                                              child: Text(
                                                _selectedDate == null
                                                    ? 'Pilih tanggal'
                                                    : DateFormat('dd/MM/yy')
                                                        .format(_selectedDate!),
                                                style: GoogleFonts.poppins(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Keterangan',
                                            style: GoogleFonts.poppins(
                                              fontSize: baseFontSize * 0.9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _keteranganController,
                                            maxLines: 3,
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Masukkan alasan tukar shift',
                                              hintStyle: GoogleFonts.poppins(),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                            ),
                                            style: GoogleFonts.poppins(),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Masukkan keterangan';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: (_isLoading ||
                                                      _isLoadingShifts)
                                                  ? null
                                                  : _submitForm,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF1572E8),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12),
                                              ),
                                              child: _isLoading ||
                                                      _isLoadingShifts
                                                  ? const CircularProgressIndicator(
                                                      color: Colors.white,
                                                    )
                                                  : Text(
                                                      'Kirim Pengajuan',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize:
                                                            baseFontSize * 0.9,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              Positioned(
                bottom: 20,
                right: 20,
                child: FloatingActionButton.extended(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        final ScrollController scrollController =
                            ScrollController();
                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          contentPadding: const EdgeInsets.all(16.0),
                          content: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.95,
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Scrollbar(
                              controller: scrollController,
                              thumbVisibility: false,
                              thickness: 3,
                              radius: const Radius.circular(10),
                              child: SingleChildScrollView(
                                controller: scrollController,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Frequently Asked Questions (FAQ)',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1572E8),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildFAQItem(
                                      icon: Icons.schedule,
                                      question: 'Apa itu menu Schedule Shift?',
                                      answer:
                                          'Menu Schedule Shift berfungsi untuk melihat jadwal kerja atau shift Anda setiap harinya. Fitur ini sudah aktif dan dapat digunakan.',
                                    ),
                                    _buildFAQItem(
                                      icon: Icons.swap_horiz,
                                      question:
                                          'Bagaimana cara mengajukan Tukar Schedule?',
                                      answer:
                                          'Pada halaman Tukar Schedule, disediakan form yang harus Anda isi. Anda perlu memilih karyawan lain yang ingin diajak bertukar shift, lalu tentukan tanggal penukaran shift dan cantumkan keterangan alasan penukaran dengan jelas.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          actions: [
                            Center(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  'Tutup',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.help_outline, color: Colors.white),
                  label: Text(
                    'FAQ',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: Colors.blue,
                ),
              ),
              SlideTransition(
                position: _slideAnimation,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                      border: Border.all(
                        color: Colors.black.withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(-4, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Menu',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const Divider(color: Colors.grey),
                        _buildMenuItem(
                          icon: Icons.health_and_safety,
                          title: 'BPJS',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BPJSPage(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: paddingValue * 0.5),
                        _buildMenuItem(
                          icon: Icons.badge,
                          title: 'ID & Slip Salary',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const IdCardUploadPage(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: paddingValue * 0.5),
                        _buildMenuItem(
                          icon: Icons.description,
                          title: 'SK Kerja & Medical',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SKKMedicPage(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: paddingValue * 0.5),
                        _buildMenuItem(
                          icon: Icons.headset_mic,
                          title: 'HR Care',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HRCareMenuPage(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: paddingValue * 0.5),
                        _buildMenuItem(
                          icon: Icons.support_agent,
                          title: 'Layanan Karyawan',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LayananMenuPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFAQItem({
    required IconData icon,
    required String question,
    required String answer,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1572E8)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  answer,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
