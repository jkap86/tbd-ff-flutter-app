import 'package:flutter/foundation.dart';
import '../models/waiver_claim.dart';
import '../models/transaction.dart';
import '../services/waiver_service.dart';

enum WaiverStatus {
  initial,
  loading,
  loaded,
  error,
}

class WaiverProvider with ChangeNotifier {
  final WaiverService _waiverService = WaiverService();

  WaiverStatus _status = WaiverStatus.initial;
  List<WaiverClaim> _myClaims = [];
  List<WaiverClaim> _leagueClaims = [];
  List<Transaction> _transactions = [];
  String? _errorMessage;

  // Getters
  WaiverStatus get status => _status;
  List<WaiverClaim> get myClaims => _myClaims;
  List<WaiverClaim> get leagueClaims => _leagueClaims;
  List<Transaction> get transactions => _transactions;
  String? get errorMessage => _errorMessage;

  int get pendingClaimsCount => _myClaims.where((c) => c.isPending).length;

  /// Load waiver claims for a specific roster
  Future<void> loadClaims({
    required String token,
    required int rosterId,
  }) async {
    _status = WaiverStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final claims = await _waiverService.getRosterClaims(
        token: token,
        rosterId: rosterId,
      );

      _myClaims = claims;
      _status = WaiverStatus.loaded;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading claims: ${e.toString()}';
      _status = WaiverStatus.error;
      notifyListeners();
    }
  }

  /// Load all waiver claims for a league
  Future<void> loadLeagueClaims({
    required String token,
    required int leagueId,
  }) async {
    try {
      final claims = await _waiverService.getLeagueClaims(
        token: token,
        leagueId: leagueId,
      );

      _leagueClaims = claims;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading league claims: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Submit a waiver claim
  Future<bool> submitClaim({
    required String token,
    required int leagueId,
    required int rosterId,
    required int playerId,
    int? dropPlayerId,
    required int bidAmount,
  }) async {
    _status = WaiverStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final claim = await _waiverService.submitClaim(
        token: token,
        leagueId: leagueId,
        rosterId: rosterId,
        playerId: playerId,
        dropPlayerId: dropPlayerId,
        bidAmount: bidAmount,
      );

      if (claim != null) {
        // Add the new claim to the list
        _myClaims.insert(0, claim);
        _status = WaiverStatus.loaded;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to submit waiver claim';
        _status = WaiverStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error submitting claim: ${e.toString()}';
      _status = WaiverStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Cancel a waiver claim
  Future<bool> cancelClaim({
    required String token,
    required int claimId,
  }) async {
    _status = WaiverStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _waiverService.cancelClaim(
        token: token,
        claimId: claimId,
      );

      if (success) {
        // Remove the claim from the list
        _myClaims.removeWhere((claim) => claim.id == claimId);
        _status = WaiverStatus.loaded;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to cancel claim';
        _status = WaiverStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error canceling claim: ${e.toString()}';
      _status = WaiverStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Pick up a free agent
  Future<bool> pickupFreeAgent({
    required String token,
    required int leagueId,
    required int rosterId,
    required int playerId,
    int? dropPlayerId,
  }) async {
    _status = WaiverStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final transaction = await _waiverService.pickupFreeAgent(
        token: token,
        leagueId: leagueId,
        rosterId: rosterId,
        playerId: playerId,
        dropPlayerId: dropPlayerId,
      );

      if (transaction != null) {
        // Add the transaction to the list
        _transactions.insert(0, transaction);
        _status = WaiverStatus.loaded;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to pickup free agent';
        _status = WaiverStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error picking up free agent: ${e.toString()}';
      _status = WaiverStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Load transaction history for a league
  Future<void> loadTransactions({
    required String token,
    required int leagueId,
  }) async {
    try {
      final transactions = await _waiverService.getTransactions(
        token: token,
        leagueId: leagueId,
      );

      _transactions = transactions;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading transactions: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear all data
  void clear() {
    _myClaims = [];
    _leagueClaims = [];
    _transactions = [];
    _errorMessage = null;
    _status = WaiverStatus.initial;
    notifyListeners();
  }
}
