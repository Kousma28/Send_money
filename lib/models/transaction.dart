// lib/models/transaction.dart

enum TransactionType {
  sent,
  received,
}

class Transaction {
  final String id;
  final String name;
  final double amount;
  final String date;
  final TransactionType type;
  final String country;
  final String flag;
  final String? avatar;

  Transaction({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
    required this.type,
    required this.country,
    required this.flag,
    this.avatar,
  });
}