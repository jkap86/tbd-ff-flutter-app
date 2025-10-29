import 'package:flutter/foundation.dart';
import '../models/trade_model.dart';
import '../services/trade_service.dart';

class TradeProvider with ChangeNotifier {
  final TradeService _tradeService = TradeService();

  List<Trade> _activeTrades = [];
  List<Trade> _completedTrades = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Trade> get activeTrades => _activeTrades;
  List<Trade> get completedTrades => _completedTrades;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get pending trades (sent or received)
  List<Trade> getPendingTrades(int myRosterId) {
    return _activeTrades
        .where((trade) =>
            trade.isPending &&
            (trade.proposerRosterId == myRosterId ||
                trade.receiverRosterId == myRosterId))
        .toList();
  }

  // Get trades I proposed
  List<Trade> getMyProposedTrades(int myRosterId) {
    return _activeTrades
        .where((trade) =>
            trade.isPending && trade.proposerRosterId == myRosterId)
        .toList();
  }

  // Get trades sent to me
  List<Trade> getTradesForMe(int myRosterId) {
    return _activeTrades
        .where((trade) =>
            trade.isPending && trade.receiverRosterId == myRosterId)
        .toList();
  }

  // Load all trades for a league
  Future<void> loadLeagueTrades(int leagueId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final allTrades = await _tradeService.getLeagueTrades(leagueId);

      _activeTrades =
          allTrades.where((trade) => trade.isPending).toList();
      _completedTrades =
          allTrades.where((trade) => !trade.isPending).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Propose a new trade
  Future<bool> proposeTrade({
    required String token,
    required int leagueId,
    required int proposerRosterId,
    required int receiverRosterId,
    required List<int> playersGiving,
    required List<int> playersReceiving,
    String? message,
    bool notifyLeagueChat = true,
    bool showProposalDetails = false,
  }) async {
    try {
      final trade = await _tradeService.proposeTrade(
        token: token,
        leagueId: leagueId,
        proposerRosterId: proposerRosterId,
        receiverRosterId: receiverRosterId,
        playersGiving: playersGiving,
        playersReceiving: playersReceiving,
        message: message,
        notifyLeagueChat: notifyLeagueChat,
        showProposalDetails: showProposalDetails,
      );

      if (trade != null) {
        _activeTrades.insert(0, trade);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Accept a trade
  Future<bool> acceptTrade({
    required String token,
    required int tradeId,
    required int rosterId,
  }) async {
    try {
      final updatedTrade = await _tradeService.acceptTrade(
        token: token,
        tradeId: tradeId,
        rosterId: rosterId,
      );

      if (updatedTrade != null) {
        _updateTradeInList(updatedTrade);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Reject a trade
  Future<bool> rejectTrade({
    required String token,
    required int tradeId,
    required int rosterId,
    String? reason,
  }) async {
    try {
      final updatedTrade = await _tradeService.rejectTrade(
        token: token,
        tradeId: tradeId,
        rosterId: rosterId,
        reason: reason,
      );

      if (updatedTrade != null) {
        _updateTradeInList(updatedTrade);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Cancel a trade
  Future<bool> cancelTrade({
    required String token,
    required int tradeId,
    required int rosterId,
  }) async {
    try {
      final updatedTrade = await _tradeService.cancelTrade(
        token: token,
        tradeId: tradeId,
        rosterId: rosterId,
      );

      if (updatedTrade != null) {
        _updateTradeInList(updatedTrade);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Handle socket event: trade proposed
  void onTradeProposed(Map<String, dynamic> data) {
    final trade = Trade.fromJson(data['trade']);
    _activeTrades.insert(0, trade);
    notifyListeners();
  }

  // Handle socket event: trade processed
  void onTradeProcessed(Map<String, dynamic> data) {
    final trade = Trade.fromJson(data['trade']);
    _updateTradeInList(trade);
  }

  // Handle socket event: trade rejected
  void onTradeRejected(Map<String, dynamic> data) {
    final trade = Trade.fromJson(data['trade']);
    _updateTradeInList(trade);
  }

  // Handle socket event: trade cancelled
  void onTradeCancelled(Map<String, dynamic> data) {
    final trade = Trade.fromJson(data['trade']);
    _updateTradeInList(trade);
  }

  // Update a trade in the list
  void _updateTradeInList(Trade updatedTrade) {
    final activeIndex =
        _activeTrades.indexWhere((t) => t.id == updatedTrade.id);
    if (activeIndex != -1) {
      _activeTrades.removeAt(activeIndex);
      if (updatedTrade.isPending) {
        _activeTrades.insert(0, updatedTrade);
      } else {
        _completedTrades.insert(0, updatedTrade);
      }
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
