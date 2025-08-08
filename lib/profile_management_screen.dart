import 'package:flutter/material.dart';

class ProfileManagementScreen extends StatelessWidget {
  const ProfileManagementScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 관리'),
      ),
      body: const Center(
        child: Text('프로필 관리 화면'),
      ),
    );
  }
}
