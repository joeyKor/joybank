import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pin_input_dialog.dart';
import 'main_screen.dart';
import 'custom_notification.dart';

class PinResetScreen extends StatefulWidget {
  const PinResetScreen({super.key});

  @override
  State<PinResetScreen> createState() => _PinResetScreenState();
}

class _PinResetScreenState extends State<PinResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ko', 'KR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueAccent,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _verifyAndResetPin() async {
    if (_formKey.currentState!.validate()) {
      final enteredEmail = _emailController.text.trim();
      final enteredName = _nameController.text.trim();
      final enteredBirthDate = _birthDateController.text.trim();

      try {
        // 1. Query user from Firestore using Email
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: enteredEmail)
            .get();

        if (usersSnapshot.docs.isEmpty) {
          if (mounted) {
            showCustomNotification(context: context, message: '일치하는 사용자 정보가 없습니다.');
          }
          return;
        }

        final userDoc = usersSnapshot.docs.first;
        final userData = userDoc.data();
        final userUid = userDoc.id;

        // 2. Validate Name and Birth Date
        if (userData['name'] == enteredName && userData['birthDate'] == enteredBirthDate) {
          final oldPin = userData['pin'];

          if (mounted) {
            // 3. Show dialog to input new PIN
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext dialogContext) {
                return PinInputDialog(
                  onPinSet: (newPin) async {
                    try {
                      // Sign in programmatically to update Firebase Auth password
                      UserCredential credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
                        email: enteredEmail,
                        password: oldPin,
                      );

                      // Update Firebase Auth password
                      await credential.user!.updatePassword(newPin);

                      // Update Firestore database document
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userUid)
                          .update({'pin': newPin});

                      // Update local SharedPreferences state
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('userId', userUid);
                      await prefs.setString('userPin', newPin);
                      await prefs.setString('email', enteredEmail);
                      await prefs.setBool('isLoggedIn', true);

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(); // Close PIN dialog
                      }
                      
                      if (mounted) {
                        showCustomNotification(context: context, message: '새로운 PIN이 설정되었습니다.');
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const MainScreen()),
                          (Route<dynamic> route) => false,
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      if (mounted) {
                        showCustomNotification(
                          context: context,
                          message: 'PIN 업데이트에 실패했습니다. 다시 시도해주세요.',
                        );
                      }
                    }
                  },
                  isSettingPin: true,
                );
              },
            );
          }
        } else {
          if (mounted) {
            showCustomNotification(context: context, message: '입력하신 정보가 일치하지 않습니다.');
          }
        }
      } catch (e) {
        if (mounted) {
          showCustomNotification(context: context, message: '정보 조회 중 오류가 발생했습니다.');
        }
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.blueAccent, size: 22),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PIN 재설정',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '이메일, 이름, 생년월일을 정확히 입력해주세요.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 36),

                _buildTextField(
                  controller: _emailController,
                  label: '이메일 주소',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '이메일을 입력해주세요.';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                      return '올바른 이메일 형식을 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                _buildTextField(
                  controller: _nameController,
                  label: '이름',
                  icon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '이름을 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                _buildTextField(
                  controller: _birthDateController,
                  label: '생년월일 (날짜 선택)',
                  icon: Icons.calendar_today_outlined,
                  readOnly: true,
                  onTap: () => _selectBirthDate(context),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '생년월일을 선택해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                GestureDetector(
                  onTap: _verifyAndResetPin,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '정보 확인 및 재설정',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
