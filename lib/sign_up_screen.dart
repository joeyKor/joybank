import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _schoolController = TextEditingController();
  final _pinController = TextEditingController();

  String _generateAccountNumber() {
    final random = Random();
    String part1 = (random.nextInt(900) + 100).toString();
    String part2 = (random.nextInt(9000) + 1000).toString();
    String part3 = (random.nextInt(9000) + 1000).toString();
    String part4 = (random.nextInt(90) + 10).toString();
    return '$part1-$part2-$part3-$part4';
  }

  void _signUp() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text;
      final password = _pinController.text; // PIN을 비밀번호로 사용

      try {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final accountNumber = _generateAccountNumber();
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'email': email,
          'name': _nameController.text,
          'birthDate': _birthDateController.text,
          'school': _schoolController.text,
          'pin': password,
        });

        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).collection('accounts').doc('main').set({
          'accountNumber': accountNumber,
          'balance': 0, // Initial balance set to 0
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 성공!')),
        );
        Navigator.pop(context);
      } on FirebaseAuthException catch (e) {
        String message;
        if (e.code == 'weak-password') {
          message = '비밀번호가 너무 약합니다.';
        } else if (e.code == 'email-already-in-use') {
          message = '이미 사용 중인 이메일입니다.';
        } else {
          message = '회원가입 실패: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } catch (e) {
        print('회원가입 중 알 수 없는 오류 발생 (타입: ${e.runtimeType}, 메시지: $e)'); // 더 상세한 디버깅 print 추가
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 중 오류 발생: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _birthDateController,
                decoration: const InputDecoration(labelText: 'Birth Date (YYYY-MM-DD)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your birth date';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _schoolController,
                decoration: const InputDecoration(labelText: 'School'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your school';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(labelText: 'PIN (6 digits)'),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                validator: (value) {
                  if (value == null || value.isEmpty || value.length != 6) {
                    return 'Please enter a 6-digit PIN';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signUp,
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}