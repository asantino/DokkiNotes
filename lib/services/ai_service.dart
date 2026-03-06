import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:dokki/config/api_keys.dart'; //

class AIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  final String _apiKey = ApiKeys.openAI; //

  Future<String> sendMessage({
    required String userMessage,
    required List<Map<String, String>> conversationHistory,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              "model": "gpt-4o-mini",
              "messages": [
                {
                  "role": "system",
                  "content":
                      "You are a thoughtful assistant. User dictates via voice. Ask clarifying questions. ALWAYS end with a question. Keep responses concise (2-3 sentences)."
                },
                ...conversationHistory,
                {"role": "user", "content": userMessage}
              ],
              "max_tokens": 1000,
              "temperature": 0.7
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        debugPrint('API Error Status: ${response.statusCode}');
        return "AI service error";
      }
    } on SocketException {
      return "No internet connection";
    } on TimeoutException {
      return "Request timed out";
    } on http.ClientException {
      return "AI service error";
    } catch (e) {
      debugPrint('AI Error: $e');
      return "An unexpected error occurred";
    }
  }
}

final aiService = AIService();
