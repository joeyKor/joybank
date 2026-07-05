import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyCardScreen extends StatefulWidget {
  const MyCardScreen({super.key});

  @override
  State<MyCardScreen> createState() => _MyCardScreenState();
}

class _MyCardScreenState extends State<MyCardScreen> {
  bool _isCardLocked = false;
  double _dailyLimit = 100.0; // 만원 단위
  bool _hasTransitPass = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('내 카드 관리', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // 1. 카드 플레이트 이미지 (Lock 상태에 따라 비주얼 변화)
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: child,
                );
              },
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isCardLocked
                            ? [Colors.grey.shade700, Colors.grey.shade900]
                            : [const Color(0xFFEC4899), const Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (_isCardLocked ? Colors.grey : const Color(0xFF8B5CF6)).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'JOY HYBRID CHECK',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            Icon(
                              _isCardLocked ? Icons.lock_rounded : Icons.contactless_rounded,
                              color: Colors.white.withOpacity(0.8),
                              size: 24,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // IC 칩 데코
                        Container(
                          width: 40,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const Spacer(),
                        // 카드 번호
                        const Text(
                          '4518  84••  ••••  1234',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('VAL THRU  08/31', style: TextStyle(color: Colors.white70, fontSize: 10)),
                            Text('JOY CUSTOMER', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Lock 오버레이
                  if (_isCardLocked)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.lock_outline_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  '일시 잠김 상태',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // 2. 카드 상세 제어 영역
          const Text('보안 및 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  secondary: Icon(Icons.lock_rounded, color: _isCardLocked ? Colors.red : Colors.grey),
                  title: const Text('카드 일시 잠금', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('카드를 잃어버리셨거나 사용을 중단할 때 켜두세요.'),
                  value: _isCardLocked,
                  activeColor: Colors.red,
                  onChanged: (val) {
                    setState(() {
                      _isCardLocked = val;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(val ? '카드가 안전하게 일시 잠금 처리되었습니다.' : '카드가 다시 활성화되었습니다.'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  secondary: Icon(Icons.directions_bus_rounded, color: _hasTransitPass ? Colors.blue : Colors.grey),
                  title: const Text('후불 교통카드 기능', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('지하철, 버스 등 교통카드 단말기 접촉 활성화'),
                  value: _hasTransitPass,
                  activeColor: Colors.blue,
                  onChanged: _isCardLocked
                      ? null
                      : (val) {
                          setState(() {
                            _hasTransitPass = val;
                          });
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. 한도 제어 슬라이더
          const Text('이용 한도 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('하루 결제 한도', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text(
                      '${NumberFormat('#,###').format(_dailyLimit.toInt() * 10000)}원',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _isCardLocked ? Colors.grey : const Color(0xFF8B5CF6)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Slider(
                  value: _dailyLimit,
                  min: 10.0,
                  max: 200.0,
                  divisions: 19,
                  activeColor: const Color(0xFF8B5CF6),
                  inactiveColor: const Color(0xFF8B5CF6).withOpacity(0.2),
                  onChanged: _isCardLocked
                      ? null
                      : (val) {
                          setState(() {
                            _dailyLimit = val;
                          });
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. 주요 카드 혜택
          const Text('내 카드 주요 혜택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Column(
            children: [
              _buildBenefitItem(Icons.local_mall_rounded, Colors.purple, '국내외 가맹점 1.5% 적립', '조건 한도 없이 전월실적과 관계없이 포인트 적립'),
              const SizedBox(height: 12),
              _buildBenefitItem(Icons.directions_subway_rounded, Colors.blue, '대중교통 10% 청구할인', '시외버스, 고속버스, 지하철 탑승 요금 할인'),
              const SizedBox(height: 12),
              _buildBenefitItem(Icons.local_cafe_rounded, Colors.orange, '스타벅스/투썸 20% 캐시백', '사이렌 오더 및 오프라인 매장 결제 시 즉시 할인'),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildBenefitItem(IconData icon, Color color, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
