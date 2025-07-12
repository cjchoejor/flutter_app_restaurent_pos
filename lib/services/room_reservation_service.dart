import 'dart:convert';
import 'package:http/http.dart' as http;

class RoomReservationService {
  static const String baseUrl = 'http://119.2.105.142:3800';

  /// Check room reservation for the given room number
  /// Returns reservation data if room is registered, throws exception if not
  static Future<Map<String, dynamic>> checkRoomReservation(int roomNo) async {
    try {
      final url = Uri.parse(
          '$baseUrl/api/check_room_registration_for_legphel_pos/$roomNo');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'room_no': data['room_no'],
          'reservation_ref_no': data['reservation_ref_no'],
        };
      } else if (response.statusCode == 404) {
        final errorData = json.decode(response.body);
        throw RoomReservationException(
            errorData['message'] ?? 'The Room No. is not Registered');
      } else {
        throw RoomReservationException(
            'Failed to check room reservation. Status: ${response.statusCode}');
      }
    } catch (e) {
      if (e is RoomReservationException) {
        rethrow;
      }
      throw RoomReservationException(
          'Network error: Unable to check room reservation');
    }
  }
}

/// Custom exception for room reservation errors
class RoomReservationException implements Exception {
  final String message;

  RoomReservationException(this.message);

  @override
  String toString() => message;
}
