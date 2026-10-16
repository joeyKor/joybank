import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'transaction_detail_screen.dart';
import 'send_money_screen.dart';
import 'settings_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String? _userId;
  String _userName = '조인택';
  Stream<DocumentSnapshot>? _accountStream;
  Stream<QuerySnapshot>? _transactionsStream;

  // Search & Filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _periodFilter = '3개월'; // 1개월, 3개월, 6개월, 전체
  String _typeFilter = '전체'; // 전체, 입금, 출금
  String _sortOrder = '최신순'; // 최신순, 과거순

  @override
  void initState() {
    super.initState();
    _loadUserDataAndStreams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadUserDataAndStreams() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) return;

    setState(() {
      _userId = userId;
      _accountStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('accounts')
          .doc('main')
          .snapshots();

      _transactionsStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .snapshots();
    });

    // Fetch user name
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists && mounted) {
        final name = userDoc.data()?['name'];
        if (name != null && name.toString().trim().isNotEmpty) {
          setState(() {
            _userName = name.toString().trim();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user name: $e');
    }
  }

  DateTime _parseTimestamp(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    if (ts is String) return DateTime.tryParse(ts) ?? DateTime.now();
    return DateTime.now();
  }

  bool _isDeposit(Map<String, dynamic> data) {
    if (data['is_deposit'] == true) return true;
    final type = data['type']?.toString().toLowerCase() ?? '';
    if (type == '입금' || type == 'deposit' || type == 'interest') return true;
    final amt = data['amount'] as num?;
    if (amt != null &&
        amt > 0 &&
        type != '송금' &&
        type != 'transfer' &&
        type != '출금') {
      return true;
    }
    return false;
  }

  String _getDisplayTitle(Map<String, dynamic> data, bool isDeposit) {
    if (isDeposit) {
      final sender = data['senderName']?.toString().trim();
      return (sender != null && sender.isNotEmpty) ? sender : '알 수 없음';
    } else {
      final recipient = data['recipientName']?.toString().trim();
      return (recipient != null && recipient.isNotEmpty) ? recipient : '알 수 없음';
    }
  }

  void _showFilterModal() {
    String tempPeriod = _periodFilter;
    String tempType = _typeFilter;
    String tempSort = _sortOrder;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildChoiceChip(String label, String currentVal, Function(String) onSelect) {
              final isSelected = currentVal == label;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setModalState(() => onSelect(label)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF191F28) : const Color(0xFFF2F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF4E5968),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E8EB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '조회 조건 설정',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF191F28),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '조회 기간',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B95A1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        buildChoiceChip('1개월', tempPeriod, (val) => tempPeriod = val),
                        const SizedBox(width: 8),
                        buildChoiceChip('3개월', tempPeriod, (val) => tempPeriod = val),
                        const SizedBox(width: 8),
                        buildChoiceChip('6개월', tempPeriod, (val) => tempPeriod = val),
                        const SizedBox(width: 8),
                        buildChoiceChip('전체', tempPeriod, (val) => tempPeriod = val),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '거래 구분',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B95A1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        buildChoiceChip('전체', tempType, (val) => tempType = val),
                        const SizedBox(width: 8),
                        buildChoiceChip('입금', tempType, (val) => tempType = val),
                        const SizedBox(width: 8),
                        buildChoiceChip('출금', tempType, (val) => tempType = val),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '정렬 순서',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B95A1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        buildChoiceChip('최신순', tempSort, (val) => tempSort = val),
                        const SizedBox(width: 8),
                        buildChoiceChip('과거순', tempSort, (val) => tempSort = val),
                      ],
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _periodFilter = tempPeriod;
                            _typeFilter = tempType;
                            _sortOrder = tempSort;
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEB00),
                          foregroundColor: const Color(0xFF191F28),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '적용하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF191F28)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '$_userName의 통장',
          style: const TextStyle(
            color: Color(0xFF191F28),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF191F28)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _accountStream,
        builder: (context, accountSnapshot) {
          final accountData =
              accountSnapshot.hasData && accountSnapshot.data!.exists
                  ? accountSnapshot.data!.data() as Map<String, dynamic>
                  : <String, dynamic>{};
          final balance = (accountData['balance'] as num?)?.toInt() ?? 0;
          final accountNumber =
              accountData['accountNumber']?.toString() ?? '3333-02-3944286';

          return StreamBuilder<QuerySnapshot>(
            stream: _transactionsStream,
            builder: (context, txSnapshot) {
              List<QueryDocumentSnapshot> docs =
                  txSnapshot.hasData ? txSnapshot.data!.docs : [];

              // Filter transactions based on period, type, and search query
              final now = DateTime.now();
              int? periodDays;
              if (_periodFilter == '1개월') periodDays = 30;
              if (_periodFilter == '3개월') periodDays = 90;
              if (_periodFilter == '6개월') periodDays = 180;

              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isDeposit = _isDeposit(data);

                // Type filter
                if (_typeFilter == '입금' && !isDeposit) return false;
                if (_typeFilter == '출금' && isDeposit) return false;

                // Period filter
                final ts = _parseTimestamp(data['timestamp']);
                if (periodDays != null) {
                  final diff = now.difference(ts).inDays;
                  if (diff > periodDays) return false;
                }

                // Search query filter
                if (_searchQuery.isNotEmpty) {
                  final title = _getDisplayTitle(data, isDeposit).toLowerCase();
                  final desc = (data['description'] ?? '').toString().toLowerCase();
                  final memo = (data['memo_to_me'] ?? data['memo'] ?? '').toString().toLowerCase();
                  final q = _searchQuery.toLowerCase();
                  if (!title.contains(q) && !desc.contains(q) && !memo.contains(q)) {
                    return false;
                  }
                }

                return true;
              }).toList();

              // Sort
              if (_sortOrder == '과거순') {
                filteredDocs.sort((a, b) {
                  final da = _parseTimestamp((a.data() as Map<String, dynamic>)['timestamp']);
                  final db = _parseTimestamp((b.data() as Map<String, dynamic>)['timestamp']);
                  return da.compareTo(db);
                });
              } else {
                filteredDocs.sort((a, b) {
                  final da = _parseTimestamp((a.data() as Map<String, dynamic>)['timestamp']);
                  final db = _parseTimestamp((b.data() as Map<String, dynamic>)['timestamp']);
                  return db.compareTo(da);
                });
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        const SizedBox(height: 12),
                        // 1. Account number with copy icon
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: accountNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$accountNumber 계좌번호가 복사되었습니다.'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                accountNumber,
                                style: const TextStyle(
                                  color: Color(0xFF8B95A1),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFFC4CBD4),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: Color(0xFF8B95A1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // 2. Large Balance Text
                        Text(
                          '${NumberFormat('#,###').format(balance)}원',
                          style: const TextStyle(
                            color: Color(0xFF191F28),
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // 3. Search & Filter Bar
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search,
                                color: Color(0xFF191F28),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (val) {
                                    setState(() {
                                      _searchQuery = val.trim();
                                    });
                                  },
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF191F28),
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: '',
                                  ),
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child: Icon(
                                      Icons.cancel,
                                      size: 16,
                                      color: Color(0xFF8B95A1),
                                    ),
                                  ),
                                ),
                              InkWell(
                                onTap: _showFilterModal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$_periodFilter · $_typeFilter · $_sortOrder',
                                      style: const TextStyle(
                                        color: Color(0xFF6B7684),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: Color(0xFF6B7684),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 4. Transaction List Grouped by Date
                        if (filteredDocs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Center(
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? '검색 결과가 없습니다.'
                                    : '해당 기간의 거래 내역이 없습니다.',
                                style: const TextStyle(
                                  color: Color(0xFF8B95A1),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          )
                        else
                          ...filteredDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final isDeposit = _isDeposit(data);
                            final rawAmt = (data['amount'] as num?) ?? 0;
                            final absAmount = rawAmt.abs();
                            final balanceAfter = (data['balance_after'] ??
                                data['balanceAfter']) as num?;
                            final title = _getDisplayTitle(data, isDeposit);
                            final ts = _parseTimestamp(data['timestamp']);
                            final dateStr = DateFormat('MM.dd').format(ts);
                            final timeStr = DateFormat('HH:mm').format(ts);

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TransactionDetailScreen(
                                      transaction: data,
                                      transactionId: doc.id,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(top: 20, bottom: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1. 개별 거래마다 상단에 날짜 표기 (08.20 등)
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF191F28),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // 2. 거래 상세 내역 Row
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Left: Title & Time
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF191F28),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                timeStr,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF8B95A1),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Right: Amount & Balance after
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              isDeposit
                                                  ? '${NumberFormat('#,###').format(absAmount)}원'
                                                  : '-${NumberFormat('#,###').format(absAmount)}원',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isDeposit
                                                    ? const Color(0xFF0064FF)
                                                    : const Color(0xFF191F28),
                                              ),
                                            ),
                                            if (balanceAfter != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                '${NumberFormat('#,###').format(balanceAfter)}원',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF8B95A1),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // 5. Fixed Bottom Action Bar ("이체하기")
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SendMoneyScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFEB00),
                            foregroundColor: const Color(0xFF191F28),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '이체하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
