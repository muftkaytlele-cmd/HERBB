import 'package:http/http.dart' as http;
import 'dart:convert';
import 'backend_auth_service.dart';

class ComplaintService {
  static String get apiBaseUrl => BackendAuthService.apiBaseUrl;

  /// Submit a complaint to the backend
  Future<Map<String, dynamic>> submitComplaint({
    required String userId,
    required String userName,
    required String userEmail,
    required String complaintType,
    required String subject,
    required String description,
  }) async {
    try {
      final token = await BackendAuthService.getValidToken();
      print('DEBUG ComplaintService: Submitting complaint...');
      
      final payload = {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'complaintType': complaintType,
        'subject': subject,
        'description': description,
        'status': 'pending',
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('DEBUG ComplaintService: Payload: $payload');

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/v1/complaints'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 30));

      print('DEBUG ComplaintService: Response status: ${response.statusCode}');
      print('DEBUG ComplaintService: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': responseData['message'] ?? 'Complaint submitted successfully',
          'complaintId': responseData['complaintId'],
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to submit complaint: ${response.statusCode}',
          'error': response.body,
        };
      }
    } catch (e) {
      print('DEBUG ComplaintService: Error: $e');
      return {
        'success': false,
        'message': 'Error submitting complaint: $e',
        'error': e.toString(),
      };
    }
  }

  /// Get all complaints for a user (optional - for future use)
  Future<Map<String, dynamic>> getUserComplaints(String userId) async {
    try {
      final token = await BackendAuthService.getValidToken();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/v1/complaints/user/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'complaints': responseData['complaints'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch complaints',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching complaints: $e',
      };
    }
  }
}
