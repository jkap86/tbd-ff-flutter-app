# Task 3: Frontend Regular Auction Draft UI

## Objective
Create Flutter UI for live auction drafts with single player nomination at a time.

## Dependencies
- **REQUIRES Task 1 & 2 to be completed** (needs backend endpoints and sockets)
- Existing draft infrastructure in `lib/screens/draft_room_screen.dart`

## Sub-tasks

### 3.1 Create Auction Models (lib/models/auction_model.dart)

```dart
class AuctionNomination {
  final int id;
  final int draftId;
  final int playerId;
  final int nominatingRosterId;
  final int? winningRosterId;
  final int? winningBid;
  final String status; // 'active', 'completed', 'passed'
  final DateTime? deadline;
  final DateTime createdAt;

  // Populated from join
  final String? playerName;
  final String? playerPosition;
  final String? playerTeam;

  AuctionNomination({...});

  factory AuctionNomination.fromJson(Map<String, dynamic> json) {...}
}

class AuctionBid {
  final int id;
  final int nominationId;
  final int rosterId;
  final int bidAmount;
  final bool isWinning;
  final DateTime createdAt;

  // Populated
  final String? teamName;

  AuctionBid({...});

  factory AuctionBid.fromJson(Map<String, dynamic> json) {...}
}

class RosterBudget {
  final int rosterId;
  final int startingBudget;
  final int spent;
  final int activeBids;
  final int reserved;
  final int available;

  RosterBudget({...});

  factory RosterBudget.fromJson(Map<String, dynamic> json) {...}
}
```

### 3.2 Create Auction Service (lib/services/auction_service.dart)

```dart
class AuctionService {
  Future<AuctionNomination> nominatePlayer({
    required String token,
    required int draftId,
    required int playerId,
    required int rosterId,
  }) async {
    // POST /api/drafts/:id/nominate
  }

  Future<void> placeBid({
    required String token,
    required int nominationId,
    required int rosterId,
    required int maxBid,
    required int draftId,
  }) async {
    // POST /api/drafts/:id/bid
  }

  Future<List<AuctionNomination>> getActiveNominations({
    required String token,
    required int draftId,
  }) async {
    // GET /api/drafts/:id/nominations
  }

  Future<List<AuctionBid>> getBidHistory({
    required String token,
    required int nominationId,
  }) async {
    // GET /api/drafts/:id/nominations/:nominationId/bids
  }

  Future<RosterBudget> getRosterBudget({
    required String token,
    required int rosterId,
  }) async {
    // GET /api/rosters/:id/budget
  }
}
```

### 3.3 Create Auction Provider (lib/providers/auction_provider.dart)

```dart
class AuctionProvider with ChangeNotifier {
  final AuctionService _auctionService = AuctionService();
  final SocketService _socketService = SocketService();

  AuctionNomination? _currentNomination;
  List<AuctionBid> _bidHistory = [];
  Map<int, RosterBudget> _rosterBudgets = {};
  int? _myRosterId;

  AuctionNomination? get currentNomination => _currentNomination;
  List<AuctionBid> get bidHistory => _bidHistory;
  RosterBudget? get myBudget => _myRosterId != null ? _rosterBudgets[_myRosterId!] : null;

  void setupSocketListeners(int draftId) {
    _socketService.onPlayerNominated = (data) {
      _currentNomination = AuctionNomination.fromJson(data);
      _bidHistory = [];
      notifyListeners();
    };

    _socketService.onBidPlaced = (data) {
      // Update bid history with new bid
      final bid = AuctionBid.fromJson(data);
      _bidHistory.add(bid);
      notifyListeners();
    };

    _socketService.onPlayerWon = (data) {
      // Clear current nomination, move to next
      _currentNomination = null;
      notifyListeners();
    };

    _socketService.onBudgetUpdated = (data) {
      final budget = RosterBudget.fromJson(data);
      _rosterBudgets[budget.rosterId] = budget;
      notifyListeners();
    };

    _socketService.joinAuction(draftId: draftId);
  }

  Future<void> nominatePlayer(String token, int draftId, int playerId, int rosterId) async {
    await _auctionService.nominatePlayer(
      token: token,
      draftId: draftId,
      playerId: playerId,
      rosterId: rosterId,
    );
  }

  Future<void> placeBid(String token, int nominationId, int rosterId, int maxBid, int draftId) async {
    await _auctionService.placeBid(
      token: token,
      nominationId: nominationId,
      rosterId: rosterId,
      maxBid: maxBid,
      draftId: draftId,
    );
  }
}
```

### 3.4 Create Auction Draft Screen (lib/screens/auction_draft_screen.dart)

**Layout:**
```
┌─────────────────────────────────────┐
│ Top Bar: Budget Display             │
│ My Budget: $150 | Spent: $50       │
│ Reserved: $10 | Available: $90     │
├─────────────────────────────────────┤
│                                     │
│      Current Player Nomination      │
│                                     │
│     [Player Card with Details]      │
│                                     │
│   Current Bid: $15                  │
│   Winning Team: Team Name           │
│   Time Remaining: 0:45              │
│                                     │
├─────────────────────────────────────┤
│       Bidding Controls              │
│                                     │
│  [ $16 ] [ $20 ] [ $25 ] [Custom]  │
│                                     │
│  Or enter max bid: [______]         │
│  (Proxy bid - you'll pay minimum)  │
│                                     │
│       [Place Bid Button]            │
│                                     │
├─────────────────────────────────────┤
│ Bottom Drawer (Tabs):               │
│ [Available Players] [My Roster]     │
│ [Bid History] [All Budgets]         │
└─────────────────────────────────────┘
```

**Key Features:**
1. **Budget Display** - Shows all budget components
   - If reserve_budget_per_slot enabled, show reserved amount
2. **Current Nomination** - Large player card with stats
3. **Live Timer** - Countdown to nomination expiry
4. **Quick Bid Buttons** - Common increments (+$1, +$5, +$10)
5. **Proxy Bid Input** - Enter max willing to pay
6. **Bid History** - Scrollable list of all bids on current player
7. **Available Players** - Nominate next player when it's your turn

### 3.5 Key Widgets to Create

#### BudgetDisplayWidget
```dart
class BudgetDisplayWidget extends StatelessWidget {
  final RosterBudget budget;
  final bool showReserved;

  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBudgetItem('Budget', budget.startingBudget),
            _buildBudgetItem('Spent', budget.spent),
            if (showReserved) _buildBudgetItem('Reserved', budget.reserved),
            _buildBudgetItem('Available', budget.available, isHighlight: true),
          ],
        ),
      ),
    );
  }
}
```

#### CurrentNominationWidget
```dart
class CurrentNominationWidget extends StatefulWidget {
  final AuctionNomination nomination;
  final List<AuctionBid> bidHistory;
  final Function(int maxBid) onPlaceBid;

  // Shows player card, current bid, timer, bidding controls
}
```

#### BidHistoryWidget
```dart
class BidHistoryWidget extends StatelessWidget {
  final List<AuctionBid> bids;

  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: bids.length,
      itemBuilder: (context, index) {
        final bid = bids[index];
        return ListTile(
          leading: Icon(bid.isWinning ? Icons.check_circle : Icons.circle_outlined),
          title: Text('${bid.teamName}: \$${bid.bidAmount}'),
          subtitle: Text(timeAgo(bid.createdAt)),
        );
      },
    );
  }
}
```

### 3.6 Nomination Flow

When it's user's turn to nominate:
1. Show "Your Turn to Nominate" banner
2. Available players drawer opens
3. User selects player
4. Player is nominated with min_bid ($1)
5. Other teams can bid

### 3.7 Bidding Flow

1. User sees current nomination
2. Enters max bid (proxy bid)
3. System automatically bids minimum needed
4. If outbid, user gets notification
5. Can increase max bid at any time

## Testing Checklist
- [ ] Budget display shows correct amounts
- [ ] Can nominate player when it's my turn
- [ ] Quick bid buttons calculate correct amounts
- [ ] Proxy bid works (pays minimum, not max)
- [ ] Timer counts down correctly
- [ ] Player awarded when timer expires
- [ ] Bid history updates in real-time
- [ ] Can't bid more than available budget
- [ ] Reserved budget shown if setting enabled

## Files to Create/Modify
- `lib/models/auction_model.dart` (new)
- `lib/services/auction_service.dart` (new)
- `lib/providers/auction_provider.dart` (new)
- `lib/screens/auction_draft_screen.dart` (new)
- `lib/services/socket_service.dart` (add auction socket methods)

## Estimated Complexity
**Medium** - Similar to draft screen but with bidding mechanics instead of picks.
