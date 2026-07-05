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
  String _enteredAccountNumber = ''; // 커스텀 키패드로 입력한 계좌번호
  String? _userId;
  String? _senderName; // 보내는 사람 이름
  String? _recipientName; // 받는 사람 이름 (유효성 검사 후 설정)
  double _currentBalance = 0.0;
  bool _isAccountValidated = false;
  String? _validatedRecipientUserId;
  String _selectedBank = '국민은행';

  final List<String> _banks = ['국민은행', '신한은행', '우리은행', '하나은행', '농협은행', '조이뱅크'];

  final Map<String, Map<String, dynamic>> _bankDetails = {
    '조이뱅크': {'color': const Color(0xFF1E88E5), 'initials': 'JB'},
    '국민은행': {'color': const Color(0xFFFFC107), 'initials': 'KB'},
    '신한은행': {'color': const Color(0xFF1565C0), 'initials': 'SH'},
    '우리은행': {'color': const Color(0xFF0D47A1), 'initials': 'WR'},
    '하나은행': {'color': const Color(0xFF00695C), 'initials': 'HN'},
    '농협은행': {'color': const Color(0xFF2E7D32), 'initials': 'NH'},
  };

  String _formatAccountNumber(String digits) {
    if (digits.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 7 || i == 11) {
        buffer.write('-');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  void _onAccountDigitTap(String digit) {
    debugPrint('=== _onAccountDigitTap: $digit ===');
    if (_enteredAccountNumber.length < 15) {
      setState(() {
        _enteredAccountNumber += digit;
        _recipientAccountController.text = _enteredAccountNumber;
        _isAccountValidated = false;
        _recipientName = null;
      });
    }
  }

  void _onAccountBackspaceTap() {
    if (_enteredAccountNumber.isNotEmpty) {
      setState(() {
        _enteredAccountNumber =
            _enteredAccountNumber.substring(0, _enteredAccountNumber.length - 1);
        _recipientAccountController.text = _enteredAccountNumber;
        _isAccountValidated = false;
        _recipientName = null;
      });
    }
  }

  void _onAmountDigitTap(String digit) {
    debugPrint('=== _onAmountDigitTap: $digit ===');
    if (_enteredAmount.length < 12) {
      setState(() {
        _enteredAmount += digit;
      });
    }
  }

  void _onAmountBackspaceTap() {
    if (_enteredAmount.isNotEmpty) {
      setState(() {
        _enteredAmount = _enteredAmount.substring(0, _enteredAmount.length - 1);
      });
    }
  }

  Future<void> _handleAccountConfirm() async {
    if (_enteredAccountNumber.isEmpty) {
      showCustomNotification(context: context, message: '계좌번호를 입력해주세요.');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await _validateAccount();
      Navigator.pop(context); // Close loading dialog
      if (_isAccountValidated && _validatedRecipientUserId != null) {
        setState(() {
          _currentStep = SendMoneyStep.amountInput;
        });
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
    }
  }

  Future<void> _handleAccountConfirmFromSheet(BuildContext sheetContext) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await _validateAccount();
      Navigator.pop(context); // Close loading dialog
      if (_isAccountValidated && _validatedRecipientUserId != null) {
        Navigator.pop(sheetContext); // Close bottom sheet
        setState(() {
          _currentStep = SendMoneyStep.amountInput;
        });
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
    }
  }

  void _showAccountInputBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final isButtonEnabled = _enteredAccountNumber.isNotEmpty;
            final formattedText = _formatAccountNumber(_enteredAccountNumber);
            final bankDetails = _bankDetails[_selectedBank] ?? {'color': Colors.grey, 'initials': 'BK'};

            void updateState(VoidCallback fn) {
              fn();
              setState(() {});
              setSheetState(() {});
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      _showBankSelectionBottomSheetSheet(updateState);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            backgroundColor: bankDetails['color'] as Color,
                            radius: 14,
                            child: Text(
                              bankDetails['initials'] as String,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedBank,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '입금은행',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50] ?? const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _enteredAccountNumber.isNotEmpty ? formattedText : '입금할 계좌번호 입력',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: _enteredAccountNumber.isNotEmpty ? Colors.black87 : Colors.black38,
                            ),
                          ),
                        ),
                        if (_enteredAccountNumber.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.black26, size: 20),
                            onPressed: () {
                              updateState(() {
                                _enteredAccountNumber = '';
                                _recipientAccountController.clear();
                                _isAccountValidated = false;
                                _recipientName = null;
                              });
                            },
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildCustomKeypad(
                    onDigitTap: (digit) {
                      debugPrint('=== sheet onDigitTap: $digit ===');
                      if (_enteredAccountNumber.length < 15) {
                        updateState(() {
                          _enteredAccountNumber += digit;
                          _recipientAccountController.text = _enteredAccountNumber;
                          _isAccountValidated = false;
                          _recipientName = null;
                        });
                      }
                    },
                    onBackspaceTap: () {
                      if (_enteredAccountNumber.isNotEmpty) {
                        updateState(() {
                          _enteredAccountNumber =
                              _enteredAccountNumber.substring(0, _enteredAccountNumber.length - 1);
                          _recipientAccountController.text = _enteredAccountNumber;
                          _isAccountValidated = false;
                          _recipientName = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: isButtonEnabled
                          ? () async {
                              await _handleAccountConfirmFromSheet(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isButtonEnabled
                            ? Theme.of(context).primaryColor
                            : Colors.grey[300],
                        foregroundColor: isButtonEnabled ? Colors.white : Colors.black38,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBankSelectionBottomSheetSheet(Function(VoidCallback) updateState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '은행 선택',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _banks.length,
                  itemBuilder: (BuildContext context, int index) {
                    final bankName = _banks[index];
                    final details = _bankDetails[bankName] ?? {'color': Colors.grey, 'initials': 'BK'};
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: details['color'] as Color,
                        child: Text(
                          details['initials'] as String,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        bankName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      trailing: _selectedBank == bankName
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () {
                        updateState(() {
                          _selectedBank = bankName;
                          _isAccountValidated = false;
                          _enteredAccountNumber = '';
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
            ],
          ),
        );
      },
    );
  }

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
      body: SafeArea(
        child: SingleChildScrollView(
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
    final hasInput = _enteredAccountNumber.isNotEmpty;
    final formattedText = _formatAccountNumber(_enteredAccountNumber);
    final bankDetails = _bankDetails[_selectedBank] ?? {'color': Colors.grey, 'initials': 'BK'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('받는 사람 정보'),
        const SizedBox(height: 10),
        InkWell(
          onTap: _showAccountInputBottomSheet,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[50] ?? const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                if (hasInput) ...[
                  CircleAvatar(
                    backgroundColor: bankDetails['color'] as Color,
                    radius: 16,
                    child: Text(
                      bankDetails['initials'] as String,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedBank,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.credit_card, color: Colors.black38),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '입금할 계좌번호 입력',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black26),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInputStep() {
    final isButtonEnabled = _enteredAmount.isNotEmpty && (double.tryParse(_enteredAmount) ?? 0) > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        Text(
          '${_recipientName ?? '이름 없음'}님에게',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$_selectedBank ${_formatAccountNumber(_recipientAccountController.text)}',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 20),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            child: Text(
              _enteredAmount.isEmpty
                  ? '보낼 금액'
                  : '${NumberFormat('#,###').format(double.tryParse(_enteredAmount) ?? 0)}원',
              style: TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.bold,
                color: _enteredAmount.isEmpty ? Colors.grey[400] : Theme.of(context).primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 30),
        _buildCustomKeypad(
          onDigitTap: _onAmountDigitTap,
          onBackspaceTap: _onAmountBackspaceTap,
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: isButtonEnabled ? _goToNextStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isButtonEnabled
                  ? Theme.of(context).primaryColor
                  : Colors.grey[300],
              foregroundColor: isButtonEnabled ? Colors.white : Colors.black38,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              '다음',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
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
    final details = _bankDetails[_selectedBank] ?? {'color': Colors.grey, 'initials': 'BK'};
    return InkWell(
      onTap: _showBankSelectionBottomSheet,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: details['color'] as Color,
              radius: 20,
              child: Text(
                details['initials'] as String,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _selectedBank,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black54),
                    ],
                  ),
                  const Text(
                    '입금은행',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBankSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '은행 선택',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _banks.length,
                  itemBuilder: (BuildContext context, int index) {
                    final bankName = _banks[index];
                    final details = _bankDetails[bankName] ?? {'color': Colors.grey, 'initials': 'BK'};
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: details['color'] as Color,
                        child: Text(
                          details['initials'] as String,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        bankName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      trailing: _selectedBank == bankName
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedBank = bankName;
                          _isAccountValidated = false; // 은행 변경 시 계좌 유효성 초기화
                          _enteredAccountNumber = '';
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountInputDisplay() {
    final hasInput = _enteredAccountNumber.isNotEmpty;
    final formattedText = _formatAccountNumber(_enteredAccountNumber);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50] ?? const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              hasInput ? formattedText : '입금할 계좌번호 입력',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: hasInput ? Colors.black87 : Colors.black38,
              ),
            ),
          ),
          if (hasInput)
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.black26, size: 20),
              onPressed: () {
                setState(() {
                  _enteredAccountNumber = '';
                  _recipientAccountController.clear();
                  _isAccountValidated = false;
                  _recipientName = null;
                });
              },
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  Widget _buildCustomKeypad({
    required Function(String) onDigitTap,
    required VoidCallback onBackspaceTap,
  }) {
    return Column(
      children: [
        for (int row = 0; row < 4; row++) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int col = 0; col < 3; col++) ...[
                Expanded(
                  child: _buildKeypadButton(
                    row: row,
                    col: col,
                    onDigitTap: onDigitTap,
                    onBackspaceTap: onBackspaceTap,
                  ),
                ),
              ],
            ],
          ),
          if (row < 3) const SizedBox(height: 15),
        ],
      ],
    );
  }

  Widget _buildKeypadButton({
    required int row,
    required int col,
    required Function(String) onDigitTap,
    required VoidCallback onBackspaceTap,
  }) {
    if (row < 3) {
      final val = row * 3 + col + 1;
      return _buildKeyText('$val', () => onDigitTap('$val'));
    } else {
      if (col == 0) {
        return const SizedBox.shrink(); // Empty space bottom left
      } else if (col == 1) {
        return _buildKeyText('0', () => onDigitTap('0'));
      } else {
        return _buildKeyIcon(Icons.backspace_outlined, onBackspaceTap);
      }
    }
  }

  Widget _buildKeyText(String text, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 24,
            color: Colors.black87,
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
