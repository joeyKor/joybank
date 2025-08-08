import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math'; // 추가

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 사용자 정보 저장
  static Future<void> saveUserData(String userId, Map<String, dynamic> userData) async {
    try {
      await _firestore.collection('users').doc(userId).set(userData);
    } catch (e) {
      print('Error saving user data: $e');
      rethrow;
    }
  }

  // 사용자 정보 가져오기
  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      rethrow;
    }
  }

  // 거래 내역 저장
  static Future<void> saveTransaction(String userId, Map<String, dynamic> transactionData) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .add(transactionData);
    } catch (e) {
      print('Error saving transaction: $e');
      rethrow;
    }
  }

  // 거래 내역 가져오기
  static Stream<QuerySnapshot> getTransactions(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // 계좌 정보 저장
  static Future<void> saveAccountInfo(String userId, Map<String, dynamic> accountData) async {
    try {
      // accountNumber 필드가 없으면 생성하지 않고, 기존 값이 있으면 그대로 유지
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc('main')
          .set(accountData, SetOptions(merge: true)); // 기존 필드를 덮어쓰지 않고 병합
    } catch (e) {
      print('Error saving account info: $e');
      rethrow;
    }
  }

  // 계좌 정보 가져오기
  static Future<Map<String, dynamic>?> getAccountInfo(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc('main')
          .get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting account info: $e');
      rethrow;
    }
  }

  // 송금 트랜잭션 수행
  static Future<void> performTransaction(
      String senderUserId,
      int senderCurrentBalance,
      String senderAccountNumber,
      String recipientUserId,
      int recipientCurrentBalance,
      String recipientAccountNumber,
      int amount) async {
    try {
      // Get sender's and recipient's names
      final senderUserData = await getUserData(senderUserId);
      final senderName = senderUserData?['name'] ?? '알 수 없음';

      final recipientUserData = await getUserData(recipientUserId);
      final recipientName = recipientUserData?['name'] ?? '알 수 없음';

      await _firestore.runTransaction((transaction) async {
        // Sender's account update
        DocumentReference senderAccountRef = _firestore
            .collection('users')
            .doc(senderUserId)
            .collection('accounts')
            .doc('main');
        transaction.update(senderAccountRef, {
          'balance': senderCurrentBalance - amount,
        });

        // Recipient's account update
        DocumentReference recipientAccountRef = _firestore
            .collection('users')
            .doc(recipientUserId)
            .collection('accounts')
            .doc('main');
        transaction.update(recipientAccountRef, {
          'balance': recipientCurrentBalance + amount,
        });

        // Record transaction for sender
        await saveTransaction(senderUserId, {
          'type': 'transfer',
          'amount': -amount,
          'description': '송금',
          'timestamp': FieldValue.serverTimestamp(),
          'balanceAfter': senderCurrentBalance - amount,
          'recipientAccountNumber': recipientAccountNumber,
          'recipientName': recipientName, // Save recipient's name
        });

        // Record transaction for recipient
        await saveTransaction(recipientUserId, {
          'type': 'deposit',
          'amount': amount,
          'description': '입금',
          'timestamp': FieldValue.serverTimestamp(),
          'balanceAfter': recipientCurrentBalance + amount,
          'senderAccountNumber': senderAccountNumber,
          'senderName': senderName, // Save sender's name
        });
      });
    } catch (e) {
      print('Error performing transaction: $e');
      rethrow;
    }
  }

  // 알림 저장
  static Future<void> saveNotification(String userId, Map<String, dynamic> notificationData) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add(notificationData);
    } catch (e) {
      print('Error saving notification: $e');
      rethrow;
    }
  }

  // 알림 가져오기
  static Stream<QuerySnapshot> getNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // 모든 알림 삭제
  static Future<void> clearAllNotifications(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      for (DocumentSnapshot doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error clearing notifications: $e');
      rethrow;
    }
  }

  // 거래 메모 업데이트
  static Future<void> updateTransactionMemo(String userId, String transactionId, String memo) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(transactionId)
          .update({'memo': memo});
    } catch (e) {
      print('Error updating transaction memo: $e');
      rethrow;
    }
  }

  // 계좌번호로 사용자 ID와 계좌 정보 가져오기
  static Future<Map<String, dynamic>?> getUserIdAndAccountByAccountNumber(String accountNumber) async {
    try {
      final querySnapshot = await _firestore
          .collectionGroup('accounts') // Search across all 'accounts' subcollections
          .where('accountNumber', isEqualTo: accountNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return {
          'userId': doc.reference.parent.parent!.id, // Get the userId from the parent document
          'accountData': doc.data() as Map<String, dynamic>,
        };
      }
      return null;
    } catch (e) {
      print('Error getting user by account number: $e');
      rethrow;
    }
  }

  // 금액 입금
  static Future<void> depositMoney(String userId, int amount) async {
    try {
      DocumentReference accountRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc('main');

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot accountSnapshot = await transaction.get(accountRef);

        if (!accountSnapshot.exists) {
          print('Account does not exist. Creating new account with balance: $amount');
          transaction.set(accountRef, {'balance': amount});
        } else {
          num currentBalance = (accountSnapshot.data() as Map<String, dynamic>)['balance'] as num? ?? 0;
          print('Current balance: $currentBalance. Adding $amount.');
          transaction.update(accountRef, {'balance': currentBalance + amount});
        }
      });
    } catch (e) {
      print('Error depositing money in Firebase: $e');
      rethrow;
    }
  }

  // 모든 사용자에게 이자 지급
  static Future<void> payInterestToAllUsers(double annualInterestRate) async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        print('Processing interest for user: $userId');

        // 1. 현재 계좌 정보 가져오기
        Map<String, dynamic>? accountInfo = await getAccountInfo(userId);
        if (accountInfo == null || !accountInfo.containsKey('balance')) {
          print('Account info not found or balance missing for user: $userId');
          continue; // 다음 사용자로 건너뛰기
        }
        int currentBalance = accountInfo['balance'] as int;

        // 2. 이자 계산 (월별 이자 계산 예시)
        // 교육용 앱이므로 단순화된 계산
        int interestAmount = (currentBalance * annualInterestRate / 12).round();

        if (interestAmount <= 0) {
          print('Calculated interest amount is zero or negative for user: $userId. Skipping.');
          continue; // 이자가 0 이하면 지급하지 않음
        }

        // 3. 계좌에 이자 입금
        int newBalance = currentBalance + interestAmount;
        String? existingAccountNumber = accountInfo['accountNumber'] as String?;
        await saveAccountInfo(userId, {
          'balance': newBalance,
          'accountNumber': existingAccountNumber, // 기존 계좌 번호 전달
        });

        // 4. 이자 지급 내역 기록
        await saveTransaction(userId, {
          'type': 'interest',
          'amount': interestAmount,
          'description': '이자 지급',
          'timestamp': FieldValue.serverTimestamp(),
          'balance_after': newBalance, // 필드 이름 변경
          'source': '이자',
        });

        print('Interest of $interestAmount paid to user $userId. New balance: $newBalance');
      }
      print('All interest payments completed.');
    } catch (e) {
      print('Error paying interest to all users: $e');
      rethrow;
    }
  }

  // 모든 사용자 정보와 계좌 정보 가져오기
  static Future<List<Map<String, dynamic>>> getAllUsersWithAccountInfo() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final List<Map<String, dynamic>> usersWithAccounts = [];

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();
        final accountInfo = await getAccountInfo(userId);

        if (accountInfo != null) {
          usersWithAccounts.add({
            'uid': userId,
            'name': userData['name'],
            'email': userData['email'],
            'school': userData['school'], // Add school
            'accountNumber': accountInfo['accountNumber'],
            'balance': accountInfo['balance'],
          });
        }
      }
      return usersWithAccounts;
    } catch (e) {
      print('Error getting all users with account info: $e');
      rethrow;
    }
  }

  // 관리자가 사용자에게 송금
  static Future<void> sendMoneyAsAdmin(String userId, int amount, String description) async {
    try {
      // 1. 사용자 계좌 정보 가져오기
      DocumentSnapshot accountDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc('main')
          .get();

      if (!accountDoc.exists) {
        throw Exception('User account not found');
      }

      // 2. 잔액 업데이트
      int currentBalance = (accountDoc.data() as Map<String, dynamic>)['balance'] ?? 0;
      int newBalance = currentBalance + amount;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc('main')
          .update({'balance': newBalance});

      // 3. 거래 내역 기록
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .add({
        'type': 'deposit',
        'amount': amount,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'balance_after': newBalance,
        'senderName': '관리자',
      });
    } catch (e) {
      print('Error sending money to user: $e');
      rethrow;
    }
  }
}