import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'transaction_detail_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String? _userId;
  Stream<DocumentSnapshot>? _accountStream;
  Stream<QuerySnapshot>? _transactionsStream;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndStreams();
  }

  void _loadUserIdAndStreams() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId');
      if (_userId != null) {
        _accountStream =
            FirebaseFirestore.instance
                .collection('users')
                .doc(_userId)
                .collection('accounts')
                .doc('main')
                .snapshots();
        _transactionsStream =
            FirebaseFirestore.instance
                .collection('users')
                .doc(_userId)
                .collection('transactions')
                .orderBy('timestamp', descending: true)
                .snapshots();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 220.0,
            floating: true,
            pinned: true,
            snap: true,
            backgroundColor: Theme.of(context).primaryColor,
            title: const Text('거래내역'),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.grey[100],
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60.0),
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: _accountStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Center(
                            child: Text('No account data found.'),
                          );
                        }
                        final accountData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        final balance = accountData['balance'] ?? 0;
                        final accountNumber =
                            accountData['accountNumber'] ?? 'N/A';

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '입출금 계좌',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              accountNumber,
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.8),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${NumberFormat('#,###').format(balance)}원',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          _userId == null
              ? const SliverFillRemaining(
                  child: Center(
                    child: Text('사용자 ID를 불러오는 중...'),
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: _transactionsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return SliverFillRemaining(
                        child: Center(child: Text('거래 내역을 불러오는 중 오류 발생: ${snapshot.error}')),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return SliverFillRemaining(
                        child: FutureBuilder<DocumentSnapshot>(
                          future:
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(_userId)
                                  .collection('accounts')
                                  .doc('main')
                                  .get(),
                          builder: (context, accountSnapshot) {
                            if (accountSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (!accountSnapshot.hasData ||
                                !accountSnapshot.data!.exists) {
                              return const Center(
                                child: Text('계좌 정보를 찾을 수 없습니다.'),
                              );
                            }
                            final accountData =
                                accountSnapshot.data!.data()
                                    as Map<String, dynamic>;
                            final createdAt =
                                (accountData['createdAt'] as Timestamp?)
                                    ?.toDate();
                            final balance = accountData['balance'] ?? 0;

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  '거래 내역이 없습니다.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '계좌 개설일: ${createdAt != null ? DateFormat('yyyy.MM.dd').format(createdAt) : 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${NumberFormat('#,###').format(balance)}원',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    } else {
                      final transactions = snapshot.data!.docs;
                      return SliverList(
                        delegate: SliverChildBuilderDelegate((
                          BuildContext context,
                          int index,
                        ) {
                          final transaction =
                              transactions[index].data() as Map<String, dynamic>;
                          final amount = transaction['amount'] as int;
                          final isDeposit = transaction['type'] == '입금';

                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => TransactionDetailScreen(
                                            transaction: transaction,
                                            transactionId: transactions[index].id,
                                          ), // Pass transactionId
                                    ),
                                  );
                                },
                                title: Row(
                                  children: [
                                    Text(
                                      DateFormat('MM.dd').format(
                                        (transaction['timestamp'] as Timestamp?)
                                                ?.toDate() ??
                                            DateTime.now(),
                                      ),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            transaction['description'] ?? '내용 없음',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 15,
                                            ),
                                          ),
                                          if (transaction['memo'] != null &&
                                              transaction['memo']
                                                  .isNotEmpty) // Display memo
                                            Text(
                                              transaction['memo'],
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${NumberFormat('#,###').format(amount.abs())}원',
                                      style: TextStyle(
                                        color:
                                            isDeposit ? Colors.blue : Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      '${NumberFormat('#,###').format((transaction['balance_after'] as num?)?.toDouble() ?? 0)}원',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(
                                height: 1,
                                thickness: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                            ],
                          );
                        }, childCount: transactions.length),
                      );
                    }
                  },
                ),
        ],
      ),
    );
  }
}
