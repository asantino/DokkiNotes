import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/railway_config.dart';
import 'auth_service.dart';

class RailwayService {
  static final RailwayService instance = RailwayService._();
  RailwayService._();

  // Проверить баланс
  Future<int> checkBalance() async {
    debugPrint('🔍 === CHECK BALANCE START ===');
    debugPrint('🔍 User ID: ${AuthService.instance.currentUserId}');
    debugPrint('🔍 Railway URL: ${RailwayConfig.baseUrl}');

    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      debugPrint('🔍 Check balance: User not logged in (returning 0)');
      return 0;
    }

    try {
      final response = await http.post(
        Uri.parse('${RailwayConfig.baseUrl}/api/dokkinotes/check-balance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final int balance = data['balance'] as int;
        debugPrint('🔍 Balance result: $balance');
        return balance;
      }

      debugPrint('🔍 Balance result: 0 (Status code: ${response.statusCode})');
      return 0;
    } catch (e) {
      debugPrint('❌ Check balance error: $e');
      return 0;
    }
  }

  // Списать токены
  Future<bool> deductTokens(int amount,
      {Map<String, dynamic>? metadata}) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) throw Exception('Not authorized');

    try {
      final response = await http.post(
        Uri.parse('${RailwayConfig.baseUrl}/api/dokkinotes/deduct-tokens'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'amount': amount,
          'metadata': metadata ?? {},
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 402) {
        throw Exception('Insufficient tokens');
      } else {
        throw Exception('Deduction error');
      }
    } catch (e) {
      debugPrint('Deduct tokens error: $e');
      rethrow;
    }
  }

  // Добавить токены
  Future<void> addTokens(int amount, String purchaseId) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) throw Exception('Not authorized');

    try {
      final response = await http.post(
        Uri.parse('${RailwayConfig.baseUrl}/api/dokkinotes/add-tokens'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'amount': amount,
          'purchase_id': purchaseId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Token credit error');
      }
    } catch (e) {
      debugPrint('Add tokens error: $e');
      rethrow;
    }
  }

  // Получить транзакции
  Future<List<Map<String, dynamic>>> getTransactions() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return [];

    try {
      final response = await http.post(
        Uri.parse('${RailwayConfig.baseUrl}/api/dokkinotes/transactions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['transactions']);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Get transactions error: $e');
      return [];
    }
  }
}
