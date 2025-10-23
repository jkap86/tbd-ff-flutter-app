import 'package:flutter/foundation.dart';
import '../models/league_invite_model.dart';
import '../models/user_search_model.dart';
import '../services/invite_service.dart';

class InviteProvider with ChangeNotifier {
  final InviteService _inviteService = InviteService();

  List<LeagueInvite> _userInvites = [];
  List<UserSearchResult> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<LeagueInvite> get userInvites => _userInvites;
  List<UserSearchResult> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Load user's invites
  Future<void> loadUserInvites(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _userInvites = await _inviteService.getUserInvites(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading invites';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Search users
  Future<void> searchUsers(String query) async {
    if (query.trim().length < 2) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _searchResults = await _inviteService.searchUsers(query);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error searching users';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send invite
  Future<bool> sendInvite({
    required String token,
    required int leagueId,
    required int invitedUserId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _inviteService.sendInvite(
        token: token,
        leagueId: leagueId,
        invitedUserId: invitedUserId,
      );

      _isLoading = false;
      if (!success) {
        _errorMessage = 'Failed to send invite';
      }
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Error sending invite';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Accept invite
  Future<bool> acceptInvite({
    required String token,
    required int inviteId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _inviteService.acceptInvite(
        token: token,
        inviteId: inviteId,
      );

      if (success) {
        // Remove invite from list
        _userInvites.removeWhere((invite) => invite.id == inviteId);
      } else {
        _errorMessage = 'Failed to accept invite';
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Error accepting invite';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Decline invite
  Future<bool> declineInvite({
    required String token,
    required int inviteId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _inviteService.declineInvite(
        token: token,
        inviteId: inviteId,
      );

      if (success) {
        // Remove invite from list
        _userInvites.removeWhere((invite) => invite.id == inviteId);
      } else {
        _errorMessage = 'Failed to decline invite';
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Error declining invite';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Clear search results
  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
