import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'custom_notification.dart'; // 커스텀 알림 위젯 임포트

// 송금 단계 Enum 정의
enum SendMoneyStep { accountValidation, amountInput, memoInput }

/// 조이뱅크 계좌번호 포맷터 (세자리-네자리-네자리-두자리, 총 13자리)
/// 숫자를 쓸 때 3자리 입력 시 '-' 자동 추가, 이후 4자리, 4자리마다 '-' 자동 추가.
/// 13자리 초과 입력 차단.
class JoyBankAccountNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;

    final isDeleting = newText.length < oldText.length;
    String rawDigits = newText.replaceAll(RegExp(r'[^0-9]'), '');

    // 삭제 중이고 이전 텍스트가 '-'로 끝났는데 새 텍스트에서 '-'만 지워진 경우, 앞자리 숫자까지 함께 삭제
    if (isDeleting &&
        oldText.endsWith('-') &&
        newText == oldText.substring(0, oldText.length - 1)) {
      if (rawDigits.isNotEmpty) {
        rawDigits = rawDigits.substring(0, rawDigits.length - 1);
      }
    }

    // 13자리 초과 입력 차단
    if (rawDigits.length > 13) {
      rawDigits = rawDigits.substring(0, 13);
    }

    String formatted = '';
    if (rawDigits.length <= 3) {
      formatted = rawDigits;
      if (rawDigits.length == 3 && !isDeleting) {
        formatted = '$rawDigits-';
      }
    } else if (rawDigits.length <= 7) {
      final p1 = rawDigits.substring(0, 3);
      final p2 = rawDigits.substring(3);
      formatted = '$p1-$p2';
      if (rawDigits.length == 7 && !isDeleting) {
        formatted = '$formatted-';
      }
    } else if (rawDigits.length <= 11) {
      final p1 = rawDigits.substring(0, 3);
      final p2 = rawDigits.substring(3, 7);
      final p3 = rawDigits.substring(7);
      formatted = '$p1-$p2-$p3';
      if (rawDigits.length == 11 && !isDeleting) {
        formatted = '$formatted-';
      }
    } else {
      final p1 = rawDigits.substring(0, 3);
      final p2 = rawDigits.substring(3, 7);
      final p3 = rawDigits.substring(7, 11);
      final p4 = rawDigits.substring(11);
      formatted = '$p1-$p2-$p3-$p4';
    }

    // 커서 위치 계산
    int newOffset = formatted.length;
    if (newValue.selection.baseOffset >= 0) {
      int targetDigitCount = 0;
      final rawOffset = newValue.selection.baseOffset.clamp(0, newText.length);
      for (int i = 0; i < rawOffset; i++) {
        if (RegExp(r'[0-9]').hasMatch(newText[i])) {
          targetDigitCount++;
        }
      }

      if (isDeleting &&
          oldText.endsWith('-') &&
          newText == oldText.substring(0, oldText.length - 1)) {
        targetDigitCount = (targetDigitCount - 1).clamp(0, rawDigits.length);
      } else {
        targetDigitCount = targetDigitCount.clamp(0, rawDigits.length);
      }

      int countedDigits = 0;
      int targetOffset = 0;
      while (targetOffset < formatted.length && countedDigits < targetDigitCount) {
        if (RegExp(r'[0-9]').hasMatch(formatted[targetOffset])) {
          countedDigits++;
        }
        targetOffset++;
      }
      if (!isDeleting &&
          targetOffset < formatted.length &&
          formatted[targetOffset] == '-') {
        targetOffset++;
      }
      newOffset = targetOffset.clamp(0, formatted.length);
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

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
  String _selectedBank = '조이뱅크';
  String _selectedBottomTab = '최근송금'; // '최근송금', '내계좌', '자주쓰는'
  String _myAccountNumber = '110-123-456789';
  String _myAccountName = '조이 입출금 통장';
  bool _isSearchingSaved = false;
  final TextEditingController _searchSavedController = TextEditingController();

  final List<String> _banks = [
    '조이뱅크',
    'NH농협',
    '카카오뱅크',
    'KB국민은행',
    '신한은행',
    '우리은행',
    '하나은행',
    '토스뱅크',
    'IBK기업은행',
    'SC제일은행',
  ];

  final Map<String, Map<String, dynamic>> _bankDetails = {
    '조이뱅크': {'color': const Color(0xFF1E88E5), 'initials': 'JB', 'textColor': Colors.white},
    'NH농협': {'color': const Color(0xFF0066B3), 'initials': 'NH', 'textColor': Colors.white},
    '농협은행': {'color': const Color(0xFF0066B3), 'initials': 'NH', 'textColor': Colors.white},
    '카카오뱅크': {'color': const Color(0xFFFFEB00), 'initials': 'B', 'textColor': const Color(0xFF191F28)},
    '카카오': {'color': const Color(0xFFFFEB00), 'initials': 'B', 'textColor': const Color(0xFF191F28)},
    'KB국민은행': {'color': const Color(0xFFFFC107), 'initials': 'KB', 'textColor': Colors.white},
    '국민은행': {'color': const Color(0xFFFFC107), 'initials': 'KB', 'textColor': Colors.white},
    '신한은행': {'color': const Color(0xFF1565C0), 'initials': 'SH', 'textColor': Colors.white},
    '우리은행': {'color': const Color(0xFF0D47A1), 'initials': 'WR', 'textColor': Colors.white},
    '하나은행': {'color': const Color(0xFF00695C), 'initials': 'HN', 'textColor': Colors.white},
    '토스뱅크': {'color': const Color(0xFF0064FF), 'initials': 'T', 'textColor': Colors.white},
    'IBK기업은행': {'color': const Color(0xFF00468C), 'initials': 'IBK', 'textColor': Colors.white},
    'SC제일은행': {'color': const Color(0xFF00A389), 'initials': 'SC', 'textColor': Colors.white},
  };

  // 최근 및 즐겨찾기 계좌 리스트 데이터 구조 정의
  List<Map<String, dynamic>> _savedAccounts = [];

  String _formatAccountNumber(String input) {
    final rawDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawDigits.isEmpty) return '';
    final cleanDigits =
        rawDigits.length > 13 ? rawDigits.substring(0, 13) : rawDigits;

    if (cleanDigits.length <= 3) {
      return cleanDigits;
    } else if (cleanDigits.length <= 7) {
      return '${cleanDigits.substring(0, 3)}-${cleanDigits.substring(3)}';
    } else if (cleanDigits.length <= 11) {
      return '${cleanDigits.substring(0, 3)}-${cleanDigits.substring(3, 7)}-${cleanDigits.substring(7)}';
    } else {
      return '${cleanDigits.substring(0, 3)}-${cleanDigits.substring(3, 7)}-${cleanDigits.substring(7, 11)}-${cleanDigits.substring(11)}';
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

  // 최근 및 자주 쓰는 계좌 목록 전용 팝업 바텀 시트
  void _showSavedAccountsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final favoriteAccounts = _savedAccounts.where((acc) => acc['isFavorite'] == true).toList();
            final recentAccounts = _savedAccounts.where((acc) => acc['isFavorite'] != true).toList();

            void updateState(VoidCallback fn) {
              fn();
              setState(() {});
              setSheetState(() {});
            }

            Widget buildSheetListTile(Map<String, dynamic> account, int originalIndex) {
              final bankName = account['bank'] as String;
              final details = _bankDetails[bankName] ?? {'color': Colors.grey, 'initials': 'BK'};
              final isFav = account['isFavorite'] as bool? ?? false;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedBank = bankName;
                      _enteredAccountNumber = _formatAccountNumber(account['accountNumber'] as String);
                      _recipientAccountController.text = _enteredAccountNumber;
                    });
                    Navigator.pop(context); // 목록 바텀시트 닫기
                    _handleAccountConfirm(); // 유효성 검사 실행
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: details['color'] as Color,
                          radius: 18,
                          child: Text(
                            details['initials'] as String,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account['name'] as String,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$bankName ${_formatAccountNumber(account['accountNumber'] as String)}',
                                style: const TextStyle(fontSize: 13, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isFav ? Icons.star : Icons.star_border,
                            color: isFav ? Colors.amber : Colors.black26,
                            size: 24,
                          ),
                          onPressed: () async {
                            await _toggleFavorite(originalIndex);
                            updateState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '송금 계좌 선택',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // 현재 목록 팝업 닫기
                          _showAccountInputBottomSheet(); // 수동 입력 키패드 팝업 띄우기
                        },
                        icon: const Icon(Icons.keyboard, size: 18),
                        label: const Text('직접 입력', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (favoriteAccounts.isNotEmpty) ...[
                            const Text(
                              '자주 쓰는 계좌 ⭐',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: favoriteAccounts.length,
                              itemBuilder: (context, index) {
                                final account = favoriteAccounts[index];
                                final origIndex = _savedAccounts.indexOf(account);
                                return buildSheetListTile(account, origIndex);
                              },
                            ),
                            const SizedBox(height: 25),
                          ],
                          const Text(
                            '최근 송금 계좌',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          if (recentAccounts.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Center(
                                child: Text(
                                  '최근 송금한 내역이 없습니다.',
                                  style: TextStyle(color: Colors.black38, fontSize: 14),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: recentAccounts.length > 8 ? 8 : recentAccounts.length,
                              itemBuilder: (context, index) {
                                final account = recentAccounts[index];
                                final origIndex = _savedAccounts.indexOf(account);
                                return buildSheetListTile(account, origIndex);
                              },
                            ),
                        ],
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
                      color: const Color(0xFFF2F4F6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE5E8EB),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _enteredAccountNumber.isNotEmpty ? formattedText : '입금할 계좌번호 입력',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _enteredAccountNumber.isNotEmpty ? const Color(0xFF191F28) : const Color(0xFF8B95A1),
                            ),
                          ),
                        ),
                        if (_enteredAccountNumber.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Color(0xFF8B95A1), size: 20),
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
                      final clean = _enteredAccountNumber.replaceAll(RegExp(r'[^0-9]'), '');
                      if (clean.length < 13) {
                        updateState(() {
                          final newClean = clean + digit;
                          _enteredAccountNumber = _formatAccountNumber(newClean);
                          _recipientAccountController.text = _enteredAccountNumber;
                          _isAccountValidated = false;
                          _recipientName = null;
                        });
                      }
                    },
                    onBackspaceTap: () {
                      final clean = _enteredAccountNumber.replaceAll(RegExp(r'[^0-9]'), '');
                      if (clean.isNotEmpty) {
                        updateState(() {
                          final newClean = clean.substring(0, clean.length - 1);
                          _enteredAccountNumber = _formatAccountNumber(newClean);
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
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isButtonEnabled
                          ? () async {
                              await _handleAccountConfirm();
                              if (context.mounted) Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isButtonEnabled
                            ? const Color(0xFFFFEB00)
                            : const Color(0xFFF2F4F6),
                        foregroundColor: isButtonEnabled
                            ? const Color(0xFF191F28)
                            : const Color(0xFFB0B8C1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 16,
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
    _initData();
  }

  Future<void> _initData() async {
    await _loadUserData();
    await _loadSavedAccounts();
  }

  @override
  void dispose() {
    _recipientAccountController.dispose();
    _recipientNameDisplayController.dispose();
    _toRecipientMemoController.dispose();
    _toMeMemoController.dispose();
    _searchSavedController.dispose();
    super.dispose();
  }

  // SharedPreferences에서 계좌 목록 불러오기
  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _userId != null ? 'saved_accounts_list_$_userId' : 'saved_accounts_list';
    final jsonStr = prefs.getString(key) ?? '[]';
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      List<Map<String, dynamic>> list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      // 김미영, 조인택 등 이전 테스트용 실제 계좌정보 자동 정리
      list.removeWhere((acc) => acc['name'] == '김미영' || acc['name'] == '조인택');
      setState(() {
        _savedAccounts = list;
      });
      await prefs.setString(key, jsonEncode(list));
    } catch (e) {
      debugPrint('Error loading saved accounts: $e');
    }
  }

  // SharedPreferences에 계좌 목록 저장하기
  Future<void> _saveSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _userId != null ? 'saved_accounts_list_$_userId' : 'saved_accounts_list';
    final jsonStr = jsonEncode(_savedAccounts);
    await prefs.setString(key, jsonStr);
  }

  // 송금 완료 후 최근 송금 내역 추가/업데이트
  Future<void> _addOrUpdateRecentAccount({
    required String name,
    required String bank,
    required String accountNumber,
  }) async {
    final cleanAccount = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final dateStr = DateFormat('yyyy.MM.dd HH:mm:ss').format(DateTime.now());
    
    // 이미 존재하는 계좌인지 확인
    int index = _savedAccounts.indexWhere((acc) => 
      acc['bank'] == bank && 
      (acc['accountNumber'] as String).replaceAll(RegExp(r'[^0-9]'), '') == cleanAccount
    );

    if (index != -1) {
      // 기존에 있으면 최신 정보를 맨 앞으로 가져옴 (즐겨찾기 상태 보존)
      final existing = _savedAccounts.removeAt(index);
      existing['lastTransferred'] = DateTime.now().toIso8601String();
      existing['date'] = dateStr;
      existing['name'] = name; // 이름 업데이트
      _savedAccounts.insert(0, existing);
    } else {
      // 새로운 계좌 추가
      _savedAccounts.insert(0, {
        'name': name,
        'bank': bank,
        'accountNumber': accountNumber,
        'isFavorite': false,
        'date': dateStr,
        'lastTransferred': DateTime.now().toIso8601String(),
      });
    }

    // 최대 20개까지만 저장 및 관리
    if (_savedAccounts.length > 20) {
      _savedAccounts = _savedAccounts.sublist(0, 20);
    }

    await _saveSavedAccounts();
    setState(() {});
  }

  // 즐겨찾기 상태 토글
  Future<void> _toggleFavorite(int index) async {
    setState(() {
      _savedAccounts[index]['isFavorite'] = !(_savedAccounts[index]['isFavorite'] as bool);
    });
    await _saveSavedAccounts();
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
          _myAccountNumber = mainAccountDoc.data()?['accountNumber']?.toString() ?? '110-123-456789';
          _myAccountName = mainAccountDoc.data()?['accountName']?.toString() ?? '조이 입출금 통장';
        });
      }
    }
  }

  Future<void> _validateAccount() async {
    final cleanedInputAccountNumber = _recipientAccountController.text
        .trim()
        .replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedInputAccountNumber.isEmpty) {
      showCustomNotification(context: context, message: '계좌번호를 입력해주세요.');
      return;
    }

    if (_selectedBank != '조이뱅크') {
      setState(() {
        _isAccountValidated = false;
        _recipientNameDisplayController.clear();
        _validatedRecipientUserId = null;
        _recipientName = null;
      });
      showCustomNotification(context: context, message: '계좌정보를 찾을 수 없습니다.');
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
        showCustomNotification(context: context, message: '계좌정보를 찾을 수 없습니다.');
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
        if (_isAccountValidated && _validatedRecipientUserId != null && _validatedRecipientUserId != 'external_bank_user') {
          _currentStep = SendMoneyStep.amountInput;
        } else {
          showCustomNotification(
            context: context,
            message: '계좌정보를 찾을 수 없습니다.',
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
        // 메모 기본값: 사용자가 직접 입력하도록 빈칸으로 초기화
        _toRecipientMemoController.clear();
        _toMeMemoController.clear();
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

  Future<void> _quickDeposit(double amount) async {
    try {
      if (_userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('accounts')
            .doc('main')
            .update({'balance': FieldValue.increment(amount)});

        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('transactions')
            .add({
          'type': '입금',
          'amount': amount,
          'timestamp': Timestamp.now(),
          'description': '계좌 채우기',
          'is_deposit': true,
          'balance_after': _currentBalance + amount,
        });

        setState(() {
          _currentBalance += amount;
        });

        if (mounted) {
          showCustomNotification(
            context: context,
            message: '${NumberFormat('#,###').format(amount)}원이 채워졌습니다.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showCustomNotification(context: context, message: '채우기 실패: $e');
      }
    }
  }

  void _showQuickDepositDialog() {
    final depositAmounts = [10000, 50000, 100000, 500000];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '내 계좌 채우기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF191F28)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '현재 잔액: ${NumberFormat('#,###').format(_currentBalance)}원',
                style: const TextStyle(fontSize: 14, color: Color(0xFF8B95A1)),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: depositAmounts.map((amt) {
                  return InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      await _quickDeposit(amt.toDouble());
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E8EB)),
                      ),
                      child: Text(
                        '+${NumberFormat('#,###').format(amt)}원',
                        style: const TextStyle(
                          color: Color(0xFF009B86),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
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

    if (_validatedRecipientUserId == null || _validatedRecipientUserId == 'external_bank_user') {
      showCustomNotification(context: context, message: '계좌정보를 찾을 수 없습니다. 거래가 취소되었습니다.');
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

      final toMeMemo = _toMeMemoController.text.trim();
      final toRecipientMemo = _toRecipientMemoController.text.trim();
      final recipientDisplayName = _recipientNameDisplayController.text.isNotEmpty
          ? _recipientNameDisplayController.text
          : (_recipientName ?? '받는분');

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
              toMeMemo.isNotEmpty
                  ? toMeMemo
                  : '$recipientDisplayName님께 송금',
          'is_deposit': false,
          'balance_after': _currentBalance - amount,
          'memo_to_recipient': toRecipientMemo,
          'memo_to_me': toMeMemo,
          'senderName': _senderName,
          'recipientName': _recipientName,
        },
      );

      // 3. 받는 사람 계좌에 금액 추가 (타행 가상계좌가 아닐 경우만)
      if (_validatedRecipientUserId != null && _validatedRecipientUserId != 'external_bank_user') {
        final recipientAccountRef = firestore
            .collection('users')
            .doc(_validatedRecipientUserId)
            .collection('accounts')
            .doc('main');
        final recipientDoc = await recipientAccountRef.get();
        if (recipientDoc.exists) {
          double currentRecipientBalance =
              (recipientDoc.data()?['balance'] ?? 0).toDouble();
          double newRecipientBalance = currentRecipientBalance + amount;
          batch.update(recipientAccountRef, {'balance': newRecipientBalance});
        }

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
                toRecipientMemo.isNotEmpty
                    ? toRecipientMemo
                    : '${_senderName ?? '누군가'}님으로부터 입금',
            'is_deposit': true,
            'memo_from_sender': toRecipientMemo,
            'memo_to_me': '', // 상대방의 자체 메모는 기본적으로 비어있음
            'senderName': _senderName,
            'recipientName': _recipientName,
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
      }

      await batch.commit();

      // 로컬 SharedPreferences에 최근 송금 내역 저장
      if (_recipientName != null) {
        await _addOrUpdateRecentAccount(
          name: _recipientName!,
          bank: _selectedBank,
          accountNumber: _recipientAccountController.text,
        );
      }

      Navigator.pop(context);
    } catch (e) {
      showCustomNotification(context: context, message: '송금 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _selectAccountAndProceed(Map<String, dynamic> account) async {
    setState(() {
      _selectedBank = account['bank'] as String? ?? '조이뱅크';
      _enteredAccountNumber = _formatAccountNumber(account['accountNumber'] as String? ?? '');
      _recipientAccountController.text = _enteredAccountNumber;
      _isAccountValidated = false;
      _recipientName = null;
      _validatedRecipientUserId = null;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _validateAccount();
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }
      if (_isAccountValidated && _validatedRecipientUserId != null) {
        setState(() {
          _currentStep = SendMoneyStep.amountInput;
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showClearRecentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('최근 송금 내역 삭제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('최근 송금 내역을 모두 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _savedAccounts.clear();
              });
              await _saveSavedAccounts();
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == SendMoneyStep.accountValidation) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF191F28)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            '송금',
            style: TextStyle(
              color: Color(0xFF191F28),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.mic_none_outlined, color: Color(0xFF191F28)),
              onPressed: () {
                showCustomNotification(context: context, message: '음성인식 송금 기능입니다.');
              },
            ),
            IconButton(
              icon: const Icon(Icons.crop_free_rounded, color: Color(0xFF191F28)),
              onPressed: () {
                showCustomNotification(context: context, message: 'QR 코드 스캔 기능입니다.');
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopSourceAccountHeader(),
              const SizedBox(height: 10),
              _buildCenterInputSection(),
              const SizedBox(height: 16),
              Expanded(
                child: _buildBottomAccountPanel(),
              ),
            ],
          ),
        ),
      );
    }

    // Step 2 (금액 입력) or Step 3 (메모 입력)
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF191F28)),
          onPressed: _goToPreviousStep,
        ),
        title: const Text(
          '송금하기',
          style: TextStyle(
            color: Color(0xFF191F28),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCurrentStepWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSourceAccountHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E88E5),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'JB',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _myAccountName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF191F28),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '조이뱅크 $_myAccountNumber',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${NumberFormat('#,###').format(_currentBalance)}원',
                style: const TextStyle(
                  color: Color(0xFF009B86),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Center(
            child: Icon(
              Icons.keyboard_double_arrow_down_rounded,
              size: 20,
              color: Color(0xFF009B86),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterInputSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '누구에게 보낼까요?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191F28),
            ),
          ),
          const SizedBox(height: 20),
          // 은행 선택
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: _showBankSelectionBottomSheet,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedBank,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF191F28),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ),
          TextField(
            controller: _recipientAccountController,
            keyboardType: TextInputType.number,
            inputFormatters: [JoyBankAccountNumberFormatter()],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF191F28),
            ),
            onChanged: (val) {
              setState(() {
                _enteredAccountNumber = val;
                _isAccountValidated = false;
                _recipientName = null;
              });
            },
            onSubmitted: (_) => _handleAccountConfirm(),
            decoration: InputDecoration(
              hintText: '계좌번호 입력',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 15,
                fontWeight: FontWeight.normal,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF009B86), width: 1.5),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_recipientAccountController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Color(0xFF94A3B8), size: 18),
                      onPressed: () {
                        setState(() {
                          _enteredAccountNumber = '';
                          _recipientAccountController.clear();
                          _isAccountValidated = false;
                          _recipientName = null;
                        });
                      },
                    ),
                  TextButton(
                    onPressed: _handleAccountConfirm,
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        color: Color(0xFF009B86),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFFFB300)),
              SizedBox(width: 2),
              Text(
                '빠른송금',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAccountPanel() {
    final favoriteAccounts = _savedAccounts.where((acc) => acc['isFavorite'] == true).toList();
    
    // 검색 필터 적용
    List<Map<String, dynamic>> displayAccounts;
    if (_selectedBottomTab == '자주쓰는') {
      displayAccounts = favoriteAccounts;
    } else {
      displayAccounts = _savedAccounts;
    }

    if (_isSearchingSaved && _searchSavedController.text.isNotEmpty) {
      final query = _searchSavedController.text.trim().toLowerCase();
      displayAccounts = displayAccounts.where((acc) {
        final name = (acc['name'] as String? ?? '').toLowerCase();
        final bank = (acc['bank'] as String? ?? '').toLowerCase();
        final num = (acc['accountNumber'] as String? ?? '');
        return name.contains(query) || bank.contains(query) || num.contains(query);
      }).toList();
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          // 상단 그랩 핸들 바
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 3개 탭 (최근송금 / 내계좌 / 자주쓰는)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomTabItem('최근송금'),
                _buildBottomTabItem('내계좌'),
                _buildBottomTabItem('자주쓰는'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 검색 및 삭제 아이콘 행
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.search_rounded,
                    size: 22,
                    color: _isSearchingSaved ? const Color(0xFF009B86) : const Color(0xFF64748B),
                  ),
                  onPressed: () {
                    setState(() {
                      _isSearchingSaved = !_isSearchingSaved;
                      if (!_isSearchingSaved) {
                        _searchSavedController.clear();
                      }
                    });
                  },
                ),
                const Spacer(),
                if (_selectedBottomTab == '최근송금')
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 22,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: _showClearRecentDialog,
                  ),
              ],
            ),
          ),
          if (_isSearchingSaved)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchSavedController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '이름, 은행 또는 계좌번호 검색',
                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          // 탭별 내용 영역
          Expanded(
            child: _buildBottomTabContent(displayAccounts),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTabItem(String tabName) {
    final isSelected = _selectedBottomTab == tabName;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedBottomTab = tabName;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          tabName,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomTabContent(List<Map<String, dynamic>> accounts) {
    if (_selectedBottomTab == '내계좌') {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1E88E5),
                  radius: 18,
                  child: const Text(
                    'JB',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _myAccountName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF191F28)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '조이뱅크 $_myAccountNumber',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${NumberFormat('#,###').format(_currentBalance)}원',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF009B86)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (accounts.isEmpty) {
      return Center(
        child: Text(
          _selectedBottomTab == '자주쓰는'
              ? '자주 쓰는 계좌가 없습니다.\n목록에서 별표(★)를 눌러 등록해보세요.'
              : '최근 송금 내역이 없습니다.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        final origIndex = _savedAccounts.indexOf(account);
        final bankName = account['bank'] as String? ?? '은행';
        final details = _bankDetails[bankName] ?? {'color': Colors.grey, 'initials': 'BK', 'textColor': Colors.white};
        final isFav = account['isFavorite'] as bool? ?? false;
        final dateStr = account['date'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: InkWell(
            onTap: () => _selectAccountAndProceed(account),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: details['color'] as Color,
                    radius: 18,
                    child: Text(
                      details['initials'] as String,
                      style: TextStyle(
                        color: details['textColor'] as Color? ?? Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account['name'] as String? ?? '',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF191F28),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$bankName ${_formatAccountNumber(account['accountNumber'] as String? ?? '')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (dateStr.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isFav ? Colors.amber : const Color(0xFFCBD5E1),
                      size: 24,
                    ),
                    onPressed: origIndex != -1 ? () => _toggleFavorite(origIndex) : null,
                  ),
                  InkWell(
                    onTap: () => _selectAccountAndProceed(account),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        color: const Color(0xFFF8FAFC),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case SendMoneyStep.amountInput:
        return _buildAmountInputStep();
      case SendMoneyStep.memoInput:
        return _buildMemoInputStep();
      default:
        return Container();
    }
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
            color: Color(0xFF191F28),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$_selectedBank ${_formatAccountNumber(_recipientAccountController.text)}',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF8B95A1),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            child: Text(
              _enteredAmount.isEmpty
                  ? '보낼 금액 입력'
                  : '${NumberFormat('#,###').format(double.tryParse(_enteredAmount) ?? 0)}원',
              style: TextStyle(
                fontSize: _enteredAmount.isEmpty ? 22 : 32,
                fontWeight: FontWeight.w800,
                color: _enteredAmount.isEmpty ? const Color(0xFFB0B8C1) : const Color(0xFF191F28),
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 28),
        _buildCustomKeypad(
          onDigitTap: _onAmountDigitTap,
          onBackspaceTap: _onAmountBackspaceTap,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isButtonEnabled ? _goToNextStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isButtonEnabled
                  ? const Color(0xFFFFEB00)
                  : const Color(0xFFF2F4F6),
              foregroundColor: isButtonEnabled
                  ? const Color(0xFF191F28)
                  : const Color(0xFFB0B8C1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              '다음',
              style: TextStyle(
                fontSize: 16,
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
        const SizedBox(height: 12),
        _buildTransactionSummary(),
        const SizedBox(height: 28),
        _buildSectionTitle('송금 메모'),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _toRecipientMemoController,
          labelText: '받는분에게 표시',
          hintText: '받는분에게 보낼 메시지를 입력하세요',
          icon: Icons.message_outlined,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _toMeMemoController,
          labelText: '나에게 표시',
          hintText: '나에게 보낼 메시지를 입력하세요',
          icon: Icons.edit_note_rounded,
        ),
        const SizedBox(height: 36),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '받는 분',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8B95A1),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${_recipientName ?? '이름 없음'} ($_selectedBank)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191F28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE5E8EB)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '송금 금액',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8B95A1),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$formattedAmount원',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0064FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF191F28),
        ),
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
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF191F28),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Color(0xFF8B95A1), fontSize: 14),
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFFB0B8C1), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF8B95A1), size: 20),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E8EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF191F28),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE5E8EB),
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      height: 52,
      child: ElevatedButton(
        onPressed: _sendMoney,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFEB00),
          foregroundColor: const Color(0xFF191F28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: const Text(
          '송금하기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
