import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/draft_derby_model.dart';

class DraftDerbyService {
  /// Create a new derby for a draft
  ///
  /// Creates a derby record for the specified draft.
  /// Returns the created DraftDerby object on success, null on failure.
  Future<DraftDerby?> createDerby({
    required String token,
    required int draftId,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/drafts/$draftId/derby/create');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[DerbyService] Create derby response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return DraftDerby.fromJson(data['data']);
      } else {
        final errorData = json.decode(response.body);
        debugPrint('[DerbyService] Create derby error: ${errorData['message']}');
        return null;
      }
    } catch (e) {
      debugPrint('[DerbyService] Create derby exception: $e');
      return null;
    }
  }

  /// Start the derby (randomizes derby order)
  ///
  /// Starts the derby and randomizes the selection order.
  /// Returns the updated DraftDerby object on success, null on failure.
  Future<DraftDerby?> startDerby({
    required String token,
    required int draftId,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/drafts/$draftId/derby/start');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[DerbyService] Start derby response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DraftDerby.fromJson(data['data']);
      } else {
        final errorData = json.decode(response.body);
        debugPrint('[DerbyService] Start derby error: ${errorData['message']}');
        return null;
      }
    } catch (e) {
      debugPrint('[DerbyService] Start derby exception: $e');
      return null;
    }
  }

  /// Get current derby status and details
  ///
  /// Retrieves the current state of the derby including selections and available positions.
  /// Returns DraftDerbyWithDetails on success, null if derby not found or on error.
  Future<DraftDerbyWithDetails?> getDerbyStatus({
    required String token,
    required int draftId,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/drafts/$draftId/derby');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[DerbyService] Get derby status response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DraftDerbyWithDetails.fromJson(data['data']);
      } else if (response.statusCode == 404) {
        debugPrint('[DerbyService] Derby not found');
        return null;
      } else {
        final errorData = json.decode(response.body);
        debugPrint('[DerbyService] Get derby status error: ${errorData['message']}');
        return null;
      }
    } catch (e) {
      debugPrint('[DerbyService] Get derby status exception: $e');
      return null;
    }
  }

  /// Get derby details (alias for getDerbyStatus for backward compatibility)
  ///
  /// Retrieves the current state of the derby including selections and available positions.
  /// Returns DraftDerbyWithDetails on success, null if derby not found or on error.
  Future<DraftDerbyWithDetails?> getDerby({
    required String token,
    required int draftId,
  }) async {
    return getDerbyStatus(token: token, draftId: draftId);
  }

  /// Get available draft positions
  ///
  /// Returns a list of draft positions that are still available for selection.
  /// Returns empty list if derby not found or on error.
  Future<List<int>> getAvailablePositions({
    required String token,
    required int draftId,
  }) async {
    try {
      final derbyDetails = await getDerbyStatus(token: token, draftId: draftId);

      if (derbyDetails != null) {
        return derbyDetails.availablePositions;
      }

      return [];
    } catch (e) {
      debugPrint('[DerbyService] Get available positions exception: $e');
      return [];
    }
  }

  /// Select a draft position
  ///
  /// Allows a roster to select their preferred draft position.
  /// Returns a map containing the selection and updated derby on success.
  /// Throws an exception on failure with error message.
  Future<Map<String, dynamic>?> selectPosition({
    required String token,
    required int draftId,
    required int rosterId,
    required int position,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/drafts/$draftId/derby/select');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'roster_id': rosterId,
          'draft_position': position,
        }),
      );

      debugPrint('[DerbyService] Select position response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'selection': DraftDerbySelection.fromJson(data['data']['selection']),
          'derby': DraftDerbyWithDetails.fromJson(data['data']['derby']),
        };
      } else {
        final errorData = json.decode(response.body);
        debugPrint('[DerbyService] Select position error: ${errorData['message']}');
        throw Exception(errorData['message'] ?? 'Failed to select position');
      }
    } catch (e) {
      debugPrint('[DerbyService] Select position exception: $e');
      rethrow;
    }
  }

  /// Make a derby selection (alias for selectPosition for backward compatibility)
  ///
  /// Allows a roster to select their preferred draft position.
  /// Returns a map containing the selection and updated derby on success.
  /// Throws an exception on failure with error message.
  Future<Map<String, dynamic>?> makeSelection({
    required String token,
    required int draftId,
    required int rosterId,
    required int draftPosition,
  }) async {
    return selectPosition(
      token: token,
      draftId: draftId,
      rosterId: rosterId,
      position: draftPosition,
    );
  }

  /// Get current turn information
  ///
  /// Returns the roster ID of whose turn it currently is.
  /// Returns null if no one's turn (derby complete, not started, or error).
  Future<int?> getCurrentTurn({
    required String token,
    required int draftId,
  }) async {
    try {
      final derbyDetails = await getDerbyStatus(token: token, draftId: draftId);

      if (derbyDetails != null && derbyDetails.derby.isInProgress) {
        return derbyDetails.derby.currentTurnRosterId;
      }

      return null;
    } catch (e) {
      debugPrint('[DerbyService] Get current turn exception: $e');
      return null;
    }
  }

  /// Skip current turn (for timeout or commissioner action)
  ///
  /// Skips the current roster's turn in the derby selection.
  /// Returns updated DraftDerbyWithDetails on success, null on failure.
  Future<DraftDerbyWithDetails?> skipTurn({
    required String token,
    required int draftId,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/drafts/$draftId/derby/skip');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[DerbyService] Skip turn response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DraftDerbyWithDetails.fromJson(data['data']['derby'] ?? data['data']);
      } else {
        final errorData = json.decode(response.body);
        debugPrint('[DerbyService] Skip turn error: ${errorData['message']}');
        return null;
      }
    } catch (e) {
      debugPrint('[DerbyService] Skip turn exception: $e');
      return null;
    }
  }
}
