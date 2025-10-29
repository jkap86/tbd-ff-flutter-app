# Task 5: Add Auction Type Selection to Draft Setup

## Objective
Update the draft setup screen to allow commissioners to choose auction draft types and configure auction-specific settings.

## Dependencies
- **Can start immediately** - UI only, doesn't require Tasks 1-4
- Will integrate with backend once Task 1 is complete

## Sub-tasks

### 5.1 Update Draft Model (lib/models/draft_model.dart)

```dart
class Draft {
  // ... existing fields ...
  final String draftType; // 'snake', 'linear', 'auction', 'slow_auction'

  // Auction-specific fields
  final int startingBudget;
  final int minBid;
  final int maxSimultaneousNominations;
  final int? nominationTimerHours;
  final bool reserveBudgetPerSlot;

  Draft({
    // ... existing params ...
    required this.draftType,
    this.startingBudget = 200,
    this.minBid = 1,
    this.maxSimultaneousNominations = 1,
    this.nominationTimerHours,
    this.reserveBudgetPerSlot = false,
  });

  factory Draft.fromJson(Map<String, dynamic> json) {
    return Draft(
      // ... existing fields ...
      draftType: json['draft_type'] as String? ?? 'snake',
      startingBudget: json['starting_budget'] as int? ?? 200,
      minBid: json['min_bid'] as int? ?? 1,
      maxSimultaneousNominations: json['max_simultaneous_nominations'] as int? ?? 1,
      nominationTimerHours: json['nomination_timer_hours'] as int?,
      reserveBudgetPerSlot: json['reserve_budget_per_slot'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // ... existing fields ...
      'draft_type': draftType,
      'starting_budget': startingBudget,
      'min_bid': minBid,
      'max_simultaneous_nominations': maxSimultaneousNominations,
      'nomination_timer_hours': nominationTimerHours,
      'reserve_budget_per_slot': reserveBudgetPerSlot,
    };
  }
}
```

### 5.2 Update Draft Service (lib/services/draft_service.dart)

Update `createDraft()` to send auction parameters:

```dart
Future<Draft?> createDraft({
  required String token,
  required int leagueId,
  required String draftType,
  int? thirdRoundReversal,
  int? pickTimeSeconds,
  int? rounds,
  String? timerMode,
  int? teamTimeBudgetSeconds,
  // Auction-specific
  int? startingBudget,
  int? minBid,
  int? maxSimultaneousNominations,
  int? nominationTimerHours,
  bool? reserveBudgetPerSlot,
}) async {
  final body = {
    'league_id': leagueId,
    'draft_type': draftType,
    if (thirdRoundReversal != null) 'third_round_reversal': thirdRoundReversal,
    if (pickTimeSeconds != null) 'pick_time_seconds': pickTimeSeconds,
    if (rounds != null) 'rounds': rounds,
    if (timerMode != null) 'timer_mode': timerMode,
    if (teamTimeBudgetSeconds != null) 'team_time_budget_seconds': teamTimeBudgetSeconds,
    if (startingBudget != null) 'starting_budget': startingBudget,
    if (minBid != null) 'min_bid': minBid,
    if (maxSimultaneousNominations != null) 'max_simultaneous_nominations': maxSimultaneousNominations,
    if (nominationTimerHours != null) 'nomination_timer_hours': nominationTimerHours,
    if (reserveBudgetPerSlot != null) 'reserve_budget_per_slot': reserveBudgetPerSlot,
  };

  // ... rest of implementation
}
```

### 5.3 Update Draft Setup Screen UI

**Current Flow:**
1. Choose draft type (snake/linear)
2. Configure snake-specific settings
3. Configure timer settings

**New Flow:**
1. Choose draft type (snake/linear/auction/slow_auction)
2. If snake/linear → show existing settings
3. If auction/slow_auction → show auction settings
4. Create draft

**UI Layout Changes:**

```dart
class _DraftSetupScreenState extends State<DraftSetupScreen> {
  String _draftType = 'snake';

  // Existing fields
  bool _thirdRoundReversal = false;
  int _pickTimeSeconds = 90;
  int _rounds = 15;
  String _timerMode = 'traditional';
  int? _teamTimeBudgetSeconds;

  // New auction fields
  int _startingBudget = 200;
  int _minBid = 1;
  int _maxSimultaneousNominations = 1;
  int? _nominationTimerHours;
  bool _reserveBudgetPerSlot = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Setup Draft')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Draft Type Selection
            _buildDraftTypeSelector(),

            SizedBox(height: 24),

            // Conditional settings based on draft type
            if (_draftType == 'snake' || _draftType == 'linear')
              ..._buildSnakeLinearSettings(),

            if (_draftType == 'auction' || _draftType == 'slow_auction')
              ..._buildAuctionSettings(),

            SizedBox(height: 24),

            // Create button
            ElevatedButton(
              onPressed: _createDraft,
              child: Text('Create Draft'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 5.4 Draft Type Selector Widget

```dart
Widget _buildDraftTypeSelector() {
  return Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Draft Type',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text('Snake'),
                selected: _draftType == 'snake',
                onSelected: (_) => setState(() => _draftType = 'snake'),
              ),
              ChoiceChip(
                label: Text('Linear'),
                selected: _draftType == 'linear',
                onSelected: (_) => setState(() => _draftType = 'linear'),
              ),
              ChoiceChip(
                label: Text('Auction'),
                selected: _draftType == 'auction',
                onSelected: (_) => setState(() => _draftType = 'auction'),
              ),
              ChoiceChip(
                label: Text('Slow Auction'),
                selected: _draftType == 'slow_auction',
                onSelected: (_) => setState(() => _draftType = 'slow_auction'),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            _getDraftTypeDescription(),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    ),
  );
}

String _getDraftTypeDescription() {
  switch (_draftType) {
    case 'snake':
      return 'Traditional snake draft with alternating pick order';
    case 'linear':
      return 'Same pick order every round';
    case 'auction':
      return 'Live auction - all teams online at once, one player at a time';
    case 'slow_auction':
      return 'Asynchronous auction - multiple players nominated simultaneously over days/weeks';
    default:
      return '';
  }
}
```

### 5.5 Auction Settings Widgets

```dart
List<Widget> _buildAuctionSettings() {
  return [
    Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 16),

            // Starting Budget
            TextField(
              decoration: InputDecoration(
                labelText: 'Starting Budget',
                prefixText: '\$',
                helperText: 'How much money each team starts with',
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: _startingBudget.toString()),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) _startingBudget = parsed;
              },
            ),

            SizedBox(height: 16),

            // Min Bid
            TextField(
              decoration: InputDecoration(
                labelText: 'Minimum Bid',
                prefixText: '\$',
                helperText: 'Minimum bid increment',
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: _minBid.toString()),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) _minBid = parsed;
              },
            ),

            SizedBox(height: 16),

            // Reserve Budget Toggle
            SwitchListTile(
              title: Text('Reserve \$1 Per Roster Slot'),
              subtitle: Text('Prevents teams from running out of money'),
              value: _reserveBudgetPerSlot,
              onChanged: (value) {
                setState(() => _reserveBudgetPerSlot = value);
              },
            ),
          ],
        ),
      ),
    ),

    SizedBox(height: 16),

    Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nomination Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 16),

            if (_draftType == 'auction') ...[
              // Pick Time (for regular auction)
              TextField(
                decoration: InputDecoration(
                  labelText: 'Bidding Time',
                  suffixText: 'seconds',
                  helperText: 'Time limit for each player nomination',
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: _pickTimeSeconds.toString()),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) _pickTimeSeconds = parsed;
                },
              ),
            ],

            if (_draftType == 'slow_auction') ...[
              // Max Simultaneous Nominations
              TextField(
                decoration: InputDecoration(
                  labelText: 'Max Simultaneous Nominations',
                  helperText: 'How many players can be up for bid at once (20-30 recommended)',
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: _maxSimultaneousNominations.toString()),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) _maxSimultaneousNominations = parsed;
                },
              ),

              SizedBox(height: 16),

              // Nomination Timer
              TextField(
                decoration: InputDecoration(
                  labelText: 'Nomination Timer',
                  suffixText: 'hours',
                  helperText: 'Hours until player is awarded (resets with new bid)',
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: (_nominationTimerHours ?? 24).toString()),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  _nominationTimerHours = parsed;
                },
              ),
            ],
          ],
        ),
      ),
    ),
  ];
}
```

### 5.6 Create Draft with Auction Settings

```dart
Future<void> _createDraft() async {
  final authProvider = context.read<AuthProvider>();
  final draftProvider = context.read<DraftProvider>();

  final success = await draftProvider.createDraft(
    token: authProvider.token!,
    leagueId: widget.leagueId,
    draftType: _draftType,
    thirdRoundReversal: _thirdRoundReversal ? 1 : 0,
    pickTimeSeconds: _pickTimeSeconds,
    rounds: _rounds,
    timerMode: _timerMode,
    teamTimeBudgetSeconds: _teamTimeBudgetSeconds,
    // Auction-specific
    startingBudget: _startingBudget,
    minBid: _minBid,
    maxSimultaneousNominations: _maxSimultaneousNominations,
    nominationTimerHours: _nominationTimerHours,
    reserveBudgetPerSlot: _reserveBudgetPerSlot,
  );

  if (success && mounted) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Draft created successfully')),
    );
  }
}
```

### 5.7 Show Appropriate Draft Screen

When navigating to draft room, check draft type:

```dart
void _navigateToDraft(Draft draft) {
  Widget draftScreen;

  switch (draft.draftType) {
    case 'snake':
    case 'linear':
      draftScreen = DraftRoomScreen(
        draftId: draft.id,
        leagueId: draft.leagueId,
        leagueName: widget.leagueName,
      );
      break;
    case 'auction':
      draftScreen = AuctionDraftScreen(
        draftId: draft.id,
        leagueId: draft.leagueId,
        leagueName: widget.leagueName,
      );
      break;
    case 'slow_auction':
      draftScreen = SlowAuctionDraftScreen(
        draftId: draft.id,
        leagueId: draft.leagueId,
        leagueName: widget.leagueName,
      );
      break;
    default:
      throw Exception('Unknown draft type: ${draft.draftType}');
  }

  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => draftScreen),
  );
}
```

## Testing Checklist
- [ ] Can select all 4 draft types
- [ ] Description updates when draft type changes
- [ ] Auction settings appear for auction/slow_auction
- [ ] Snake settings appear for snake/linear
- [ ] Starting budget can be customized
- [ ] Reserve budget toggle works
- [ ] Max simultaneous nominations for slow auction
- [ ] Timer settings appropriate for each type
- [ ] Draft creates successfully with auction settings
- [ ] Navigates to correct draft screen based on type

## Files to Modify
- `lib/models/draft_model.dart` (add auction fields)
- `lib/services/draft_service.dart` (update createDraft)
- `lib/screens/draft_setup_screen.dart` (add auction UI)
- `lib/providers/draft_provider.dart` (pass auction params)

## Estimated Complexity
**Low-Medium** - Mostly UI work, straightforward form additions.
