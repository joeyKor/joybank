import 'package:flutter/material.dart';

class FundScreen extends StatelessWidget {
  const FundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('펀드 상품'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildFundItem(context, '국내 주식형 펀드', '수익률: +12.5%', Colors.red),
          _buildFundItem(context, '해외 주식형 펀드', '수익률: +25.8%', Colors.blue),
          _buildFundItem(context, '채권형 펀드', '수익률: +3.1%', Colors.green),
          _buildFundItem(context, '혼합형 펀드', '수익률: +8.7%', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildFundItem(BuildContext context, String title, String performance, Color indicatorColor) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: indicatorColor, radius: 5),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(performance, style: TextStyle(color: indicatorColor, fontWeight: FontWeight.bold)),
        onTap: () {},
      ),
    );
  }
}