import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'currency_input_formatter.dart'; // 통화 포맷터 임포트
import 'custom_notification.dart'; // 커스텀 알림 위젯 임포트

// 송금 단계 Enum 정의
enum SendMoneyStep { accountValidation, amountInput, memoInput }

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  // 기존 컨트롤러
  final TextEditingController _recipientAccountController =
      TextEditingController();
  final TextEditingController _recipientNameDisplayController =
      TextEditingController(); // 예금주 표시용

  // 새로운 컨트롤러 및 상태 변수
  final TextEditingController _toRecipientMemoController =
      TextEditingController();
  final TextEditingController _toMeMemoController = TextEditingController();

  SendMoneyStep _currentStep = SendMoneyStep.accountValidation; // 현재 송금 단계
  String _enteredAmount = ''; // 키패드로 입력된 금액
  String? _userId;
  String? _senderName; // 보내는 사람 이름
  String? _recipientName; // 받는 사람 이름 (유효성 검사 후 설정)
  double _currentBalance = 0.0;
  bool _isAccountValidated = false;
  String? _validatedRecipientUserId;
  String _selectedBank = '국민은행';

  final List<String> _banks = ['국민은행', '신한은행', '우리은행', '하나은행', '농협은행', '조이뱅크'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _recipientAccountController.dispose();
    _recipientNameDisplayController.dispose();
    _toRecipientMemoController.dispose();
    _toMeMemoController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    if (_userId != null) {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_userId)
              .get(); // 사용자 문서 전체 가져오기
      if (userDoc.exists) {
        setState(() {
          _senderName = userDoc.data()?['name'] ?? '나'; // 사용자 이름 가져오기
        });
      }

      final mainAccountDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_userId)
              .collection('accounts')
              .doc('main')
              .get();
      if (mainAccountDoc.exists) {
        setState(() {
          _currentBalance = (mainAccountDoc.data()?['balance'] ?? 0).toDouble();
        });
      }
    }
  }

  Future<void> _validateAccount() async {
    if (_selectedBank != '조이뱅크') {
      showCustomNotification(context: context, message: '유효하지 않은 계좌번호입니다.');
      setState(() {
        _isAccountValidated = false;
        _recipientNameDisplayController.clear();
        _validatedRecipientUserId = null;
        _recipientName = null;
      });
      return;
    }

    final cleanedInputAccountNumber = _recipientAccountController.text
        .trim()
        .replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedInputAccountNumber.isEmpty) {
      showCustomNotification(context: context, message: '계좌번호를 입력해주세요.');
      return;
    }

    try {
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      String? foundRecipientName;
      String? foundRecipientUserId;

      for (var userDoc in usersSnapshot.docs) {
        final accountsCollection = userDoc.reference.collection('accounts');
        final mainAccountDoc = await accountsCollection.doc('main').get();

        if (mainAccountDoc.exists) {
          final storedAccountNumber =
              mainAccountDoc.data()?['accountNumber'] as String?;
          if (storedAccountNumber != null) {
            final cleanedStoredAccountNumber = storedAccountNumber.replaceAll(
              RegExp(r'[^0-9]'),
              '',
            );
            if (cleanedStoredAccountNumber == cleanedInputAccountNumber) {
              foundRecipientName = userDoc.data()['name'] ?? '이름 없음';
              foundRecipientUserId = userDoc.id;
              break;
            }
          }
        }
      }

      if (foundRecipientName != null && foundRecipientUserId != null) {
        if (foundRecipientUserId == _userId) {
          showCustomNotification(
            context: context,
            message: '자신의 계좌로는 송금할 수 없습니다.',
          );
          setState(() {
            _isAccountValidated = false;
            _recipientNameDisplayController.clear();
            _validatedRecipientUserId = null;
            _recipientName = null;
          });
        } else {
          setState(() {
            _recipientNameDisplayController.text = foundRecipientName!;
            _isAccountValidated = true;
            _validatedRecipientUserId = foundRecipientUserId;
            _recipientName = foundRecipientName; // 받는 사람 이름 설정
          });
        }
      } else {
        setState(() {
          _isAccountValidated = false;
          _recipientNameDisplayController.clear();
          _validatedRecipientUserId = null;
          _recipientName = null;
        });
        showCustomNotification(context: context, message: '유효하지 않은 계좌번호입니다.');
      }
    } catch (e) {
      setState(() {
        _isAccountValidated = false;
        _recipientNameDisplayController.clear();
        _validatedRecipientUserId = null;
        _recipientName = null;
      });
      showCustomNotification(
        context: context,
        message: '계좌 확인 중 오류가 발생했습니다: $e',
      );
    }
  }

  void _goToNextStep() {
    setState(() {
      if (_currentStep == SendMoneyStep.accountValidation) {
        if (_isAccountValidated && _validatedRecipientUserId != null) {
          _currentStep = SendMoneyStep.amountInput;
        } else {
          showCustomNotification(
            context: context,
            message: '계좌 유효성 검사를 먼저 완료해주세요.',
          );
        }
      } else if (_currentStep == SendMoneyStep.amountInput) {
        final amount = double.tryParse(_enteredAmount.replaceAll(',', ''));
        if (amount == null || amount <= 0) {
          showCustomNotification(context: context, message: '유효한 금액을 입력해주세요.');
          return;
        }
        if (amount > _currentBalance) {
          showCustomNotification(context: context, message: '잔액이 부족합니다.');
          return;
        }
        // 메모 기본값 설정
        _toRecipientMemoController.text = _senderName ?? '';
        _toMeMemoController.text = _recipientName ?? '';
        _currentStep = SendMoneyStep.memoInput;
      }
    });
  }

  void _goToPreviousStep() {
    setState(() {
      if (_currentStep == SendMoneyStep.amountInput) {
        _currentStep = SendMoneyStep.accountValidation;
      } else if (_currentStep == SendMoneyStep.memoInput) {
        _currentStep = SendMoneyStep.amountInput;
      }
    });
  }

  void _onNumberTap(String number) {
    setState(() {
      if (_enteredAmount.length < 15) {
        // 최대 길이 제한
        _enteredAmount += number;
      }
    });
  }

  void _onBackspaceTap() {
    setState(() {
      if (_enteredAmount.isNotEmpty) {
        _enteredAmount = _enteredAmount.substring(0, _enteredAmount.length - 1);
      }
    });
  }

  void _onClearTap() {
    setState(() {
      _enteredAmount = '';
    });
  }

  void _sendMoney() async {
    final amount = double.tryParse(_enteredAmount.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      showCustomNotification(context: context, message: '유효한 금액을 입력해주세요.');
      return;
    }

    if (amount > _currentBalance) {
      showCustomNotification(context: context, message: '잔액이 부족합니다.');
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // 1. 내 계좌에서 금액 차감
      final myAccountRef = firestore
          .collection('users')
          .doc(_userId)
          .collection('accounts')
          .doc('main');
      batch.update(myAccountRef, {'balance': FieldValue.increment(-amount)});

      // 2. 거래 내역 추가 (내 계좌)
      batch.set(
        firestore
            .collection('users')
            .doc(_userId)
            .collection('transactions')
            .doc(),
        {
          'type': '송금',
          'amount': amount,
          'timestamp': Timestamp.now(),
          'description':
              _toMeMemoController.text.isNotEmpty
                  ? _toMeMemoController.text
                  : '${_recipientNameDisplayController.text}님께 송금',
          'is_deposit': false,
          'balance_after': _currentBalance - amount,
          'memo_to_recipient': _toRecipientMemoController.text,
          'memo_to_me': _toMeMemoController.text,
          'senderName': _senderName, // 보내는 사람 이름 추가
          'recipientName': _recipientName, // 받는 사람 이름 추가
        },
      );

      // 3. 받는 사람 계좌에 금액 추가
      final recipientAccountRef = firestore
          .collection('users')
          .doc(_validatedRecipientUserId)
          .collection('accounts')
          .doc('main');
      final recipientDoc = await recipientAccountRef.get();
      double currentRecipientBalance =
          (recipientDoc.data()?['balance'] ?? 0).toDouble();
      double newRecipientBalance = currentRecipientBalance + amount;
      batch.update(recipientAccountRef, {'balance': newRecipientBalance});

      // 4. 거래 내역 추가 (받는 사람 계좌)
      batch.set(
        firestore
            .collection('users')
            .doc(_validatedRecipientUserId)
            .collection('transactions')
            .doc(),
        {
          'type': '입금',
          'amount': amount,
          'timestamp': Timestamp.now(),
          'description':
              _toRecipientMemoController.text.isNotEmpty
                  ? _toRecipientMemoController.text
                  : '${_senderName ?? '누군가'}님으로부터 입금',
          'is_deposit': true,
          'balance_after': newRecipientBalance,
          'memo_from_sender': _toRecipientMemoController.text,
          'memo_to_me': _toMeMemoController.text,
          'senderName': _senderName, // 보내는 사람 이름 추가
          'recipientName': _recipientName, // 받는 사람 이름 추가
        },
      );

      // 5. 받는 사람에게 알림 추가
      batch.set(
        firestore
            .collection('users')
            .doc(_validatedRecipientUserId)
            .collection('notifications')
            .doc(),
        {
          'message':
              '${_senderName ?? '누군가'}님으로부터 ${NumberFormat('#,###').format(amount)}원 입금되었습니다.',
          'timestamp': Timestamp.now(),
          'read': false,
        },
      );

      await batch.commit();

      Navigator.pop(context);
    } catch (e) {
      showCustomNotification(context: context, message: '송금 중 오류가 발생했습니다: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('송금하기'),
        backgroundColor: Theme.of(context).primaryColor,
        leading:
            _currentStep != SendMoneyStep.accountValidation
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goToPreviousStep,
                )
                : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentStep != SendMoneyStep.memoInput) ...[
              _buildSectionTitle('내 계좌 정보'),
              _buildBalanceDisplay(),
              const SizedBox(height: 30),
            ],
            _buildCurrentStepWidget(), // 현재 단계에 맞는 위젯 렌더링
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case SendMoneyStep.accountValidation:
        return _buildAccountValidationStep();
      case SendMoneyStep.amountInput:
        return _buildAmountInputStep();
      case SendMoneyStep.memoInput:
        return _buildMemoInputStep();
      default:
        return Container();
    }
  }

  Widget _buildAccountValidationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('받는 사람 정보'),
        _buildBankSelection(),
        const SizedBox(height: 15),
        _buildAccountInput(),
        if (_isAccountValidated) ...[
          const SizedBox(height: 15),
          _buildTextField(
            controller: _recipientNameDisplayController,
            labelText: '예금주',
            hintText: '예금주 이름',
            icon: Icons.person,
            readOnly: true,
          ),
          const SizedBox(height: 15),
          _buildNextButton(onPressed: _goToNextStep),
        ],
      ],
    );
  }

  Widget _buildAmountInputStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildSectionTitle('송금 금액'),
        const SizedBox(height: 5),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            child: Text(
              '${NumberFormat('#,###').format(double.tryParse(_enteredAmount) ?? 0)}원',
              style: TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 30),
        _buildNumberPad(),
        const SizedBox(height: 40),
        _buildNextButton(onPressed: _goToNextStep),
      ],
    );
  }

  Widget _buildMemoInputStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('송금 요약'),
        const SizedBox(height: 15),
        _buildTransactionSummary(),
        const SizedBox(height: 30),
        _buildSectionTitle('송금 메모'),
        const SizedBox(height: 15),
        _buildTextField(
          controller: _toRecipientMemoController,
          labelText: '받는분에게 표시',
          hintText: '받는분에게 보낼 메시지를 입력하세요',
          icon: Icons.message,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          controller: _toMeMemoController,
          labelText: '나에게 표시',
          hintText: '나에게 보낼 메시지를 입력하세요',
          icon: Icons.note,
        ),
        const SizedBox(height: 40),
        _buildSendButton(),
      ],
    );
  }

  Widget _buildTransactionSummary() {
    final formattedAmount = NumberFormat(
      '#,###',
    ).format(double.tryParse(_enteredAmount) ?? 0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).primaryColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '받는 사람: ${_recipientName ?? '이름 없음'}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '송금 금액: $formattedAmount원',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildBalanceDisplay() {
    return Container(
      width: double.infinity, // 가로 전체 채우기
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).primaryColor),
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(_userId)
                .collection('accounts')
                .doc('main')
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final accountData =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final balance = accountData['balance'] ?? _currentBalance;
          final accountNumber = accountData['accountNumber'] ?? '계좌 정보 없음';

          // 다른 곳에서 잔액을 확인할 수 있도록 상태 업데이트
          _currentBalance = (balance as num).toDouble();

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center, // 가운데 정렬
            children: [
              Text(
                accountNumber,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 14, // 글자 크기 조정
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${NumberFormat('#,###').format(balance)}원',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 18, // 글자 크기 조정
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor.withOpacity(0.5),
          ),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildBankSelection() {
    return _buildTextField(
      controller: TextEditingController(text: _selectedBank), // 선택된 은행 표시
      labelText: '은행 선택',
      hintText: '은행을 선택해주세요',
      icon: Icons.account_balance,
      readOnly: true,
      onTap: _showBankSelectionDialog,
      suffixIcon: Icon(
        Icons.arrow_drop_down,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  void _showBankSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('은행 선택'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _banks.length,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  title: Text(_banks[index]),
                  onTap: () {
                    setState(() {
                      _selectedBank = _banks[index];
                      _isAccountValidated = false; // 은행 변경 시 계좌 유효성 초기화
                      _recipientAccountController.clear();
                      _recipientNameDisplayController.clear();
                      _validatedRecipientUserId = null;
                      _recipientName = null;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountInput() {
    return _buildTextField(
      controller: _recipientAccountController,
      labelText: '계좌번호',
      hintText: '계좌번호를 입력해주세요',
      icon: Icons.credit_card,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      suffixIcon: IconButton(
        icon: Icon(
          Icons.search,
          color: Theme.of(context).primaryColor,
        ), // 앱 테마 색상 사용
        onPressed: _validateAccount,
      ),
    );
  }

  Widget _buildNumberPad() {
    return Center(
      child: SizedBox(
        width: 300, // 키패드 전체 너비 고정
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.2, // 버튼 비율 조정
            crossAxisSpacing: 10, // 간격 조정
            mainAxisSpacing: 10, // 간격 조정
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            if (index < 9) {
              return _buildNumberButton('${index + 1}');
            } else if (index == 9) {
              return _buildClearButton(); // 지우기 버튼
            } else if (index == 10) {
              return _buildNumberButton('0');
            } else {
              return _buildBackspaceButton(); // 백스페이스 버튼
            }
          },
        ),
      ),
    );
  }

  Widget _buildNumberButton(String value) {
    return ElevatedButton(
      onPressed: () => _onNumberTap(value),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 2,
        padding: const EdgeInsets.all(20),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildClearButton() {
    return ElevatedButton(
      onPressed: _onClearTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[200],
        foregroundColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 2,
        padding: const EdgeInsets.all(20),
      ),
      child: const Text(
        '지우기',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return ElevatedButton(
      onPressed: _onBackspaceTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[200],
        foregroundColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 2,
        padding: const EdgeInsets.all(20),
      ),
      child: const Icon(Icons.backspace_outlined, size: 24),
    );
  }

  Widget _buildNextButton({required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 5,
        ),
        child: const Text(
          '다음',
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _sendMoney,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 5,
        ),
        child: const Text(
          '송금하기',
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
