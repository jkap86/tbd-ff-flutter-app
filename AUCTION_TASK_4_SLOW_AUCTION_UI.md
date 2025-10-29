# Task 4: Frontend Slow Auction Draft UI

## Objective
Create Flutter UI for slow (asynchronous) auction drafts with multiple simultaneous player nominations.

## Dependencies
- **REQUIRES Task 1 & 2 to be completed** (needs backend endpoints and sockets)
- **Can work in parallel with Task 3** (shares models/services but different UI)
- Use same models/services from Task 3

## Sub-tasks

### 4.1 Reuse Models and Services from Task 3
- `lib/models/auction_model.dart` (already created in Task 3)
- `lib/services/auction_service.dart` (already created in Task 3)
- May need to extend `AuctionProvider` for multi-nomination handling

### 4.2 Extend Auction Provider for Multiple Nominations

```dart
class AuctionProvider with ChangeNotifier {
  // ... existing code from Task 3 ...

  List<AuctionNomination> _activeNominations = [];
  Map<int, List<AuctionBid>> _nominationBids = {}; // nominationId -> bids

  List<AuctionNomination> get activeNominations => _activeNominations;

  List<AuctionBid> getBidsForNomination(int nominationId) {
    return _nominationBids[nominationId] ?? [];
  }

  int? get myWinningNominationsCount {
    if (_myRosterId == null) return null;
    return _activeNominations.where((n) => n.winningRosterId == _myRosterId).length;
  }

  void setupSlowAuctionListeners(int draftId) {
    _socketService.onActiveNominations = (data) {
      _activeNominations = (data as List)
          .map((n) => AuctionNomination.fromJson(n))
          .toList();
      notifyListeners();
    };

    _socketService.onPlayerNominated = (data) {
      final nomination = AuctionNomination.fromJson(data);
      _activeNominations.add(nomination);
      _nominationBids[nomination.id] = [];
      notifyListeners();
    };

    _socketService.onBidPlaced = (data) {
      final bid = AuctionBid.fromJson(data);
      final nominationId = bid.nominationId;

      // Update bid list for this nomination
      if (!_nominationBids.containsKey(nominationId)) {
        _nominationBids[nominationId] = [];
      }
      _nominationBids[nominationId]!.add(bid);

      // Update nomination's winning bid
      final nominationIndex = _activeNominations.indexWhere((n) => n.id == nominationId);
      if (nominationIndex != -1) {
        // Create updated nomination with new winning bid
        _activeNominations[nominationIndex] = _activeNominations[nominationIndex].copyWith(
          winningBid: bid.bidAmount,
          winningRosterId: bid.rosterId,
        );
      }

      notifyListeners();
    };

    _socketService.onPlayerWon = (data) {
      // Remove from active nominations
      _activeNominations.removeWhere((n) => n.id == data['nominationId']);
      _nominationBids.remove(data['nominationId']);
      notifyListeners();
    };

    _socketService.onNominationExpired = (data) {
      // Remove nomination that expired with no bids
      _activeNominations.removeWhere((n) => n.id == data['nominationId']);
      _nominationBids.remove(data['nominationId']);
      notifyListeners();
    };

    _socketService.joinAuction(draftId: draftId);
  }
}
```

### 4.3 Create Slow Auction Draft Screen (lib/screens/slow_auction_draft_screen.dart)

**Layout:**
```
┌─────────────────────────────────────┐
│ Top Bar: Budget & Stats             │
│ Budget: $150 | Winning: 3/20 slots │
├─────────────────────────────────────┤
│                                     │
│  Active Nominations Grid (2 cols)   │
│                                     │
│ ┌──────────┐  ┌──────────┐         │
│ │ Player 1 │  │ Player 2 │         │
│ │ $25      │  │ $15      │         │
│ │ 14h left │  │ 6h left  │         │
│ │ [+] Bid  │  │ [YOU]    │         │
│ └──────────┘  └──────────┘         │
│ ┌──────────┐  ┌──────────┐         │
│ │ Player 3 │  │ Player 4 │         │
│ │ $10      │  │ No bids  │         │
│ │ 2h left  │  │ 23h left │         │
│ │ [+] Bid  │  │ [+] Bid  │         │
│ └──────────┘  └──────────┘         │
│                                     │
│        [Nominate Player]            │
│    (if under max nominations)       │
│                                     │
├─────────────────────────────────────┤
│ Bottom Drawer (Tabs):               │
│ [Available] [My Roster] [Activity]  │
└─────────────────────────────────────┘
```

**Key Differences from Regular Auction:**
1. **Grid View** - Shows 20-30 players at once (2 columns scrollable)
2. **Longer Timers** - Hours instead of seconds (12h, 24h)
3. **Can Always Nominate** - If under max simultaneous limit
4. **Compact Cards** - Less detail, click to expand
5. **Winning Indicator** - Clear visual for "YOU" on cards you're winning

### 4.4 Key Widgets to Create

#### NominationGridWidget
```dart
class NominationGridWidget extends StatelessWidget {
  final List<AuctionNomination> nominations;
  final int? myRosterId;
  final Function(AuctionNomination) onTapNomination;
  final Function(AuctionNomination) onPlaceBid;

  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: nominations.length,
      itemBuilder: (context, index) {
        return NominationCard(
          nomination: nominations[index],
          isMyBid: nominations[index].winningRosterId == myRosterId,
          onTap: () => onTapNomination(nominations[index]),
          onBid: () => onPlaceBid(nominations[index]),
        );
      },
    );
  }
}
```

#### NominationCard (Compact)
```dart
class NominationCard extends StatelessWidget {
  final AuctionNomination nomination;
  final bool isMyBid;
  final VoidCallback onTap;
  final VoidCallback onBid;

  Widget build(BuildContext context) {
    return Card(
      elevation: isMyBid ? 4 : 1,
      color: isMyBid ? Colors.green.shade50 : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Player name
              Text(
                nomination.playerName ?? 'Unknown',
                style: TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              // Position & Team
              Text(
                '${nomination.playerPosition} - ${nomination.playerTeam}',
                style: TextStyle(fontSize: 12),
              ),
              Spacer(),
              // Current bid
              if (nomination.winningBid != null)
                Text(
                  '\$${nomination.winningBid}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isMyBid ? Colors.green : Colors.black,
                  ),
                )
              else
                Text('No bids', style: TextStyle(fontSize: 14, color: Colors.grey)),
              // Winning indicator
              if (isMyBid)
                Container(
                  margin: EdgeInsets.only(top: 4),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('YOU', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              SizedBox(height: 8),
              // Timer
              _buildTimer(nomination.deadline),
              SizedBox(height: 8),
              // Bid button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onBid,
                  icon: Icon(Icons.add, size: 16),
                  label: Text('Bid', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimer(DateTime? deadline) {
    if (deadline == null) return SizedBox.shrink();

    return StreamBuilder(
      stream: Stream.periodic(Duration(seconds: 1)),
      builder: (context, snapshot) {
        final remaining = deadline.difference(DateTime.now());
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes % 60;

        return Row(
          children: [
            Icon(Icons.timer, size: 14, color: Colors.orange),
            SizedBox(width: 4),
            Text(
              '${hours}h ${minutes}m',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        );
      },
    );
  }
}
```

#### NominationDetailDialog
Shows when user taps on a nomination card:
```dart
class NominationDetailDialog extends StatelessWidget {
  final AuctionNomination nomination;
  final List<AuctionBid> bidHistory;
  final Function(int maxBid) onPlaceBid;
  final int? myRosterId;

  // Full player stats, bid history, proxy bid entry
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(maxHeight: 600, maxWidth: 400),
        child: Column(
          children: [
            // Player details
            _buildPlayerHeader(),
            Divider(),
            // Current bid info
            _buildCurrentBidInfo(),
            Divider(),
            // Bid history (scrollable)
            Expanded(
              child: ListView.builder(
                itemCount: bidHistory.length,
                itemBuilder: (context, index) {
                  final bid = bidHistory[index];
                  return ListTile(
                    leading: bid.isWinning ? Icon(Icons.check_circle) : null,
                    title: Text('\$${bid.bidAmount}'),
                    subtitle: Text('${bid.teamName} • ${timeAgo(bid.createdAt)}'),
                  );
                },
              ),
            ),
            Divider(),
            // Bid controls
            _buildBidControls(),
          ],
        ),
      ),
    );
  }
}
```

### 4.5 Nominate Player Flow

```dart
Future<void> _showNominatePlayerDialog() async {
  final draft = context.read<DraftProvider>().currentDraft;
  if (draft == null) return;

  // Check if can nominate more
  final activeCount = context.read<AuctionProvider>().activeNominations.length;
  if (activeCount >= draft.maxSimultaneousNominations) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Maximum nominations reached (${draft.maxSimultaneousNominations})')),
    );
    return;
  }

  // Show player picker
  final player = await showDialog<Player>(
    context: context,
    builder: (context) => AvailablePlayersDialog(),
  );

  if (player != null) {
    await context.read<AuctionProvider>().nominatePlayer(
      token,
      draftId,
      player.id,
      myRosterId,
    );
  }
}
```

### 4.6 Bid Placement with Proxy

```dart
void _showBidDialog(AuctionNomination nomination) {
  final TextEditingController maxBidController = TextEditingController();
  final currentBid = nomination.winningBid ?? 0;
  final minBid = currentBid + 1;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Place Bid on ${nomination.playerName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Current bid: \$${currentBid}'),
          Text('Minimum bid: \$${minBid}'),
          SizedBox(height: 16),
          TextField(
            controller: maxBidController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Your Maximum Bid',
              helperText: 'You\'ll only pay the minimum needed to win',
              prefixText: '\$',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final maxBid = int.tryParse(maxBidController.text);
            if (maxBid == null || maxBid < minBid) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Bid must be at least \$${minBid}')),
              );
              return;
            }

            Navigator.pop(context);
            await context.read<AuctionProvider>().placeBid(
              token,
              nomination.id,
              myRosterId,
              maxBid,
              draftId,
            );
          },
          child: Text('Place Bid'),
        ),
      ],
    ),
  );
}
```

### 4.7 Activity Feed (Tab in Bottom Drawer)

Show recent activity across all nominations:
```dart
class ActivityFeedWidget extends StatelessWidget {
  final List<ActivityItem> activities; // Recent bids, wins, expirations

  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return ListTile(
          leading: _getActivityIcon(activity.type),
          title: Text(activity.description),
          subtitle: Text(timeAgo(activity.timestamp)),
        );
      },
    );
  }
}
```

## Testing Checklist
- [ ] Grid shows multiple nominations simultaneously
- [ ] Can nominate if under max limit
- [ ] Can't nominate if at max limit
- [ ] Tap card opens detail dialog
- [ ] Bid placement updates card immediately
- [ ] Timer displays correctly in hours/minutes
- [ ] "YOU" indicator shows on winning nominations
- [ ] Timer reset works when new bid placed (12-24h reset)
- [ ] Activity feed shows recent events
- [ ] Can bid on multiple players at once

## Files to Create/Modify
- `lib/screens/slow_auction_draft_screen.dart` (new)
- `lib/widgets/nomination_grid_widget.dart` (new)
- `lib/widgets/nomination_card.dart` (new)
- `lib/widgets/nomination_detail_dialog.dart` (new)
- `lib/providers/auction_provider.dart` (extend from Task 3)

## Estimated Complexity
**Medium-High** - More complex UI with grid layout and multiple timers, but reuses backend from Task 3.
