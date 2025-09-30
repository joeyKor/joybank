import 'package:flutter/material.dart';
import 'package:joybank/firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:joybank/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isLoading = false;
  String _message = '';
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _selectedUser;
  Stream<QuerySnapshot>? _transactionsStream;
  int? _balance;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController(
    text: '5',
  );

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final selectedUid = _selectedUser?['uid'];
      final users = await FirebaseService.getAllUsersWithAccountInfo();
      setState(() {
        _users = users;
        if (selectedUid != null) {
          try {
            _selectedUser = _users.firstWhere(
              (user) => user['uid'] == selectedUid,
            );
          } catch (e) {
            _selectedUser = _users.isNotEmpty ? _users.first : null;
          }
        } else if (_users.isNotEmpty) {
          _selectedUser = _users.first;
        } else {
          _selectedUser = null;
        }
        _onUserSelected(_selectedUser);
      });
    } catch (e) {
      setState(() {
        _message = '사용자 정보를 불러오는 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onUserSelected(Map<String, dynamic>? user) {
    setState(() {
      _selectedUser = user;
      if (user != null) {
        _transactionsStream = FirebaseService.getTransactions(user['uid']);
        _balance = user['balance'];
      } else {
        _transactionsStream = null;
        _balance = null;
      }
    });
  }

  Future<void> _sendMoney() async {
    if (_selectedUser == null) {
      setState(() {
        _message = '사용자를 선택해주세요.';
      });
      return;
    }

    final amount = int.tryParse(_amountController.text);
    final description = _descriptionController.text;

    if (amount == null || amount <= 0) {
      setState(() {
        _message = '올바른 금액을 입력해주세요.';
      });
      return;
    }

    if (description.isEmpty) {
      setState(() {
        _message = '이체 내용을 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '송금 중...';
    });

    try {
      await FirebaseService.sendMoneyAsAdmin(
        _selectedUser!['uid'],
        amount,
        description,
      );
      setState(() {
        _message = '송금이 완료되었습니다.';
        _amountController.clear();
        _descriptionController.clear();
      });
      await _loadUsers();
    } catch (e) {
      setState(() {
        _message = '송금 중 오류 발생: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _payInterestToAllAccounts() async {
    final interestRate = double.tryParse(_interestRateController.text);
    if (interestRate == null || interestRate <= 0) {
      setState(() {
        _message = '올바른 이자율을 입력해주세요. (예: 5%는 5 입력)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '이자 지급 중...';
    });

    try {
      await FirebaseService.payInterestToAllUsers(
        interestRate / 100,
      ); // Convert percentage to decimal
      setState(() {
        _message = '모든 계좌에 이자 지급이 완료되었습니다.';
      });
      await _loadUsers(); // Refresh data after paying interest
    } catch (e) {
      setState(() {
        _message = '이자 지급 중 오류 발생: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('관리자 페이지'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: '로그아웃',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '계좌 관리', icon: Icon(Icons.person)),
              Tab(text: '은행 관리', icon: Icon(Icons.business)),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [_buildAccountManagementTab(), _buildBankManagementTab()],
        ),
      ),
    );
  }

  Widget _buildAccountManagementTab() {
    final isSelectedUserValid =
        _selectedUser != null &&
        _users.any((user) => user['uid'] == _selectedUser!['uid']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계좌 선택',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _isLoading && _users.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<Map<String, dynamic>>(
                value: isSelectedUserValid ? _selectedUser : null,
                onChanged: _onUserSelected,
                items:
                    _users.map((user) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: user,
                        child: Text(
                          '${user['name']}(${user['school']})${user['email']}',
                        ),
                      );
                    }).toList(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '사용자 선택',
                ),
                isExpanded: true,
              ),
          const SizedBox(height: 20),
          if (_selectedUser != null) ...[
            Text(
              '잔액: ${NumberFormat('#,###').format(_balance ?? 0)}원',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              '거래 내역',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 200,
              child: StreamBuilder<QuerySnapshot>(
                stream: _transactionsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('거래 내역이 없습니다.'));
                  }
                  final transactions = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final transaction =
                          transactions[index].data() as Map<String, dynamic>;
                      final amount = transaction['amount'] as int;
                      final description = transaction['description'] as String;
                      final timestamp =
                          (transaction['timestamp'] as Timestamp?);
                      final formattedDate =
                          timestamp != null
                              ? DateFormat(
                                'yyyy-MM-dd HH:mm',
                              ).format(timestamp.toDate())
                              : '시간 정보 없음';

                      return ListTile(
                        title: Text(description),
                        subtitle: Text(formattedDate),
                        trailing: Text(
                          '${NumberFormat('#,###').format(amount)}원',
                          style: TextStyle(
                            color: amount > 0 ? Colors.blue : Colors.red,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '송금하기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '금액',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '이체 내용',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendMoney,
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.0,
                        ),
                      )
                      : const Text('송금'),
            ),
          ],
          const SizedBox(height: 20),
          if (_message.isNotEmpty && ModalRoute.of(context)?.isCurrent == true)
            Center(
              child: Text(
                _message,
                style: TextStyle(
                  color: _message.contains('오류') ? Colors.red : Colors.black,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBankManagementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이자 지급',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _interestRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '연 이자율 (%)',
              hintText: '예: 5',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _payInterestToAllAccounts,
            icon:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.0,
                      ),
                    )
                    : const Icon(Icons.money),
            label: const Text('모든 계좌에 이자 지급'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 20),
          if (_message.isNotEmpty && ModalRoute.of(context)?.isCurrent == true)
            Center(
              child: Text(
                _message,
                style: TextStyle(
                  color: _message.contains('오류') ? Colors.red : Colors.black,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
