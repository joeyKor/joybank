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
                child: Center(child: CircularProgressIndicator()),
              )
              : StreamBuilder<QuerySnapshot>(
                stream: _transactionsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final transactions = snapshot.data!.docs;

                  if (transactions.isEmpty) {
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
                              child: Text('No account data found.'),
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
                              Text(
                                '계좌 개설일: ${createdAt != null ? DateFormat('yyyy.MM.dd').format(createdAt) : 'N/A'}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '잔액: ${NumberFormat('#,###').format(balance)}원',
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
                    return SliverList(
                      delegate: SliverChildBuilderDelegate((
                        BuildContext context,
                        int index,
                      ) {
                        final transaction =
                            transactions[index].data() as Map<String, dynamic>;
                        final amount = transaction['amount'] as int;
                        // Determine if it's a deposit for the current user
                        final isDeposit = transaction['type'] == 'deposit';

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
                                          isDeposit
                                              ? '${transaction['senderName'] ?? '알 수 없음'}님으로부터'
                                              : '${transaction['recipientName'] ?? '알 수 없음'}님께',
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
                                    '잔액: ${NumberFormat('#,###').format(transaction['balanceAfter'] ?? 0)}원',
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
