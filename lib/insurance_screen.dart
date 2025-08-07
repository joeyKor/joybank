import 'package:flutter/material.dart';

class InsuranceScreen extends StatelessWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('보험 상품'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildInsuranceCard(
            context,
            title: '실손 의료비 보험',
            subtitle: '병원비 걱정, 이젠 그만!',
            icon: Icons.local_hospital,
            color: Colors.blue,
          ),
          _buildInsuranceCard(
            context,
            title: '자동차 보험',
            subtitle: '안전 운전을 위한 필수 선택',
            icon: Icons.directions_car,
            color: Colors.green,
          ),
          _buildInsuranceCard(
            context,
            title: '여행자 보험',
            subtitle: '전 세계 어디서든 든든하게',
            icon: Icons.flight,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildInsuranceCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color}) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color,
              child: Icon(icon, size: 30, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}