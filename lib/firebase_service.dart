import 'package:cloud_firestore/cloud_firestore.dart';

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
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc('main')
          .set(accountData);
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
}