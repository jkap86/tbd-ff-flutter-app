/// Chatbot knowledge base for the fantasy football app
/// Contains Q&A pairs for all major features and functionality

import '../services/chatbot_service.dart';

final List<ChatbotQuestion> chatbotKnowledge = [
  // LEAGUES
  ChatbotQuestion(
    id: 'create_league',
    category: 'Leagues',
    keywords: ['create', 'league', 'new', 'start', 'make'],
    question: 'How do I create a new league?',
    answer: 'To create a new league:\n1. Tap the + button on the home screen\n2. Enter league name and settings\n3. Choose draft type (Snake, Auction, or Slow Auction)\n4. Set scoring settings\n5. Tap "Create League"',
    alternativePhrasings: ['How can I start a new league?', 'Create league steps'],
  ),
  ChatbotQuestion(
    id: 'join_league',
    category: 'Leagues',
    keywords: ['join', 'league', 'enter', 'code'],
    question: 'How do I join an existing league?',
    answer: 'To join a league:\n1. Get the league code from your commissioner\n2. Tap "Join League" on the home screen\n3. Enter the league code\n4. Tap "Join"\n\nYou can also join by tapping a shared league link.',
    alternativePhrasings: ['How to join a league?', 'Enter league with code'],
  ),
  ChatbotQuestion(
    id: 'league_settings',
    category: 'Leagues',
    keywords: ['league', 'settings', 'change', 'edit', 'modify'],
    question: 'How do I change league settings?',
    answer: 'To modify league settings:\n1. Go to your league\n2. Tap the Settings icon\n3. Update desired settings (roster size, scoring, etc.)\n4. Tap "Save Changes"\n\nNote: Some settings cannot be changed after the draft begins.',
    alternativePhrasings: ['Edit league settings', 'Modify league configuration'],
  ),

  // DRAFTING
  ChatbotQuestion(
    id: 'snake_draft',
    category: 'Draft',
    keywords: ['snake', 'draft', 'order', 'serpentine'],
    question: 'How does a snake draft work?',
    answer: 'Snake Draft:\n1. Teams draft in order (1, 2, 3...)\n2. Order reverses each round (serpentine)\n3. Example: If you pick 10th in round 1, you pick 1st in round 2\n4. Draft continues until all roster spots are filled\n\nThe draft order is randomized before the draft starts.',
    alternativePhrasings: ['What is a snake draft?', 'Explain serpentine draft'],
  ),
  ChatbotQuestion(
    id: 'auction_draft',
    category: 'Draft',
    keywords: ['auction', 'draft', 'bidding', 'budget', 'salary'],
    question: 'How does an auction draft work?',
    answer: 'Auction Draft:\n1. Each team gets a budget (typically \$200)\n2. Players are nominated one at a time\n3. Teams bid on players\n4. Highest bidder wins the player\n5. Continue until all roster spots are filled\n\nManage your budget wisely - save money for later rounds!',
    alternativePhrasings: ['What is an auction draft?', 'Explain bidding draft'],
  ),
  ChatbotQuestion(
    id: 'slow_auction',
    category: 'Draft',
    keywords: ['slow', 'auction', 'offline', 'extended'],
    question: 'What is a slow auction draft?',
    answer: 'Slow Auction Draft:\n1. Similar to auction draft but extended over time\n2. Each nomination has a bidding window (e.g., 8 hours)\n3. Teams can bid anytime during the window\n4. Perfect for leagues where live drafts are difficult\n5. Draft can take several days to complete',
    alternativePhrasings: ['Explain slow auction', 'How does slow draft work?'],
  ),
  ChatbotQuestion(
    id: 'draft_prep',
    category: 'Draft',
    keywords: ['draft', 'prep', 'prepare', 'strategy', 'rankings'],
    question: 'How do I prepare for my draft?',
    answer: 'Draft Preparation:\n1. Review player rankings and projections\n2. Create a custom ranking list\n3. Understand your league scoring settings\n4. Plan your strategy (RB heavy, balanced, etc.)\n5. Research player news and injuries\n6. Mock draft to practice\n\nTip: Know your league settings - they affect player value!',
    alternativePhrasings: ['Draft preparation tips', 'How to get ready for draft?'],
  ),

  // LINEUP MANAGEMENT
  ChatbotQuestion(
    id: 'set_lineup',
    category: 'Lineup',
    keywords: ['set', 'lineup', 'starting', 'bench', 'starters'],
    question: 'How do I set my lineup?',
    answer: 'To set your lineup:\n1. Go to your team page\n2. Tap "Set Lineup"\n3. Drag players between starting spots and bench\n4. Ensure all starting spots are filled\n5. Tap "Save Lineup"\n\nLineups lock at game time - set them before kickoff!',
    alternativePhrasings: ['How to manage lineup?', 'Change starting players'],
  ),
  ChatbotQuestion(
    id: 'lineup_lock',
    category: 'Lineup',
    keywords: ['lineup', 'lock', 'locked', 'change', 'game', 'started'],
    question: 'When does my lineup lock?',
    answer: 'Lineup Locking:\n- Each player locks at their game kickoff time\n- You can change unlocked players anytime before their game\n- Once locked, players cannot be moved until next week\n- Weekly lineups typically lock on Thursday night\n\nSet your lineup early to avoid last-minute issues!',
    alternativePhrasings: ['When do lineups lock?', 'Lineup locking time'],
  ),

  // TRADES
  ChatbotQuestion(
    id: 'propose_trade',
    category: 'Trades',
    keywords: ['trade', 'propose', 'offer', 'trading'],
    question: 'How do I propose a trade?',
    answer: 'To propose a trade:\n1. Go to the Trade tab\n2. Select the team you want to trade with\n3. Choose players to send and receive\n4. Add an optional message\n5. Tap "Propose Trade"\n\nThe other team has 48 hours to accept, decline, or counter.',
    alternativePhrasings: ['How to offer a trade?', 'Start a trade'],
  ),
  ChatbotQuestion(
    id: 'accept_trade',
    category: 'Trades',
    keywords: ['accept', 'trade', 'review', 'offer', 'pending'],
    question: 'How do I review and accept trades?',
    answer: 'To review trade offers:\n1. Check notifications for new trade offers\n2. Go to Trade tab > Pending Trades\n3. Review the proposed trade\n4. Tap "Accept", "Decline", or "Counter"\n\nTrades may have a review period where league members can veto.',
    alternativePhrasings: ['Review trade offers', 'Accept pending trades'],
  ),
  ChatbotQuestion(
    id: 'trade_deadline',
    category: 'Trades',
    keywords: ['trade', 'deadline', 'when', 'cutoff'],
    question: 'When is the trade deadline?',
    answer: 'Trade Deadline:\n- Default deadline is typically Week 10-12\n- Commissioner can set custom deadline\n- Check your league settings for exact date\n- No trades are allowed after the deadline\n\nPlan ahead - make moves before the deadline!',
    alternativePhrasings: ['What is the trade deadline?', 'Trade cutoff date'],
  ),

  // WAIVERS & FREE AGENTS
  ChatbotQuestion(
    id: 'waiver_claim',
    category: 'Waivers',
    keywords: ['waiver', 'claim', 'add', 'pickup', 'player'],
    question: 'How do I submit a waiver claim?',
    answer: 'To submit a waiver claim:\n1. Go to Available Players\n2. Find the player you want\n3. Tap on them and select "Claim"\n4. Choose a player to drop (if needed)\n5. Set your waiver priority\n6. Tap "Submit Claim"\n\nWaivers typically process Wednesday mornings.',
    alternativePhrasings: ['How to claim waivers?', 'Add player from waivers'],
  ),
  ChatbotQuestion(
    id: 'waiver_priority',
    category: 'Waivers',
    keywords: ['waiver', 'priority', 'order', 'position'],
    question: 'How does waiver priority work?',
    answer: 'Waiver Priority:\n- Teams are ordered 1st to last\n- When you successfully claim a player, you move to last\n- Higher priority gets the player if multiple teams claim\n- Priority resets each week in some leagues\n\nCheck your league settings for the specific waiver system!',
    alternativePhrasings: ['What is waiver priority?', 'Explain waiver order'],
  ),
  ChatbotQuestion(
    id: 'free_agent',
    category: 'Waivers',
    keywords: ['free', 'agent', 'fa', 'pickup', 'add'],
    question: 'What is the difference between waivers and free agents?',
    answer: 'Waivers vs Free Agents:\n- Waivers: Players recently dropped or new to league, requires claim submission and processing\n- Free Agents: Available for immediate pickup, no waiting period\n- Players typically stay on waivers for 24-48 hours after being dropped\n\nFree agents are first-come, first-served!',
    alternativePhrasings: ['Waivers vs free agents', 'FA vs waivers'],
  ),

  // SCORING
  ChatbotQuestion(
    id: 'scoring_system',
    category: 'Scoring',
    keywords: ['scoring', 'points', 'system', 'calculate'],
    question: 'How does scoring work?',
    answer: 'Scoring System:\n- Points are awarded based on player statistics\n- Common scoring: Passing TDs, rushing yards, receptions, etc.\n- Your league may use PPR (Points Per Reception) or Standard\n- Check league settings for exact point values\n- Players in your starting lineup earn points\n\nHighest total score wins each week!',
    alternativePhrasings: ['How are points calculated?', 'Explain scoring'],
  ),
  ChatbotQuestion(
    id: 'ppr_scoring',
    category: 'Scoring',
    keywords: ['ppr', 'reception', 'points', 'catch'],
    question: 'What is PPR scoring?',
    answer: 'PPR (Points Per Reception):\n- Players earn 1 point for each catch (0.5 in Half-PPR)\n- Makes pass-catching RBs and WRs more valuable\n- Standard scoring has no points for receptions\n- Check your league settings to see which system you use\n\nPPR increases scoring and changes draft strategy!',
    alternativePhrasings: ['What does PPR mean?', 'Explain points per reception'],
  ),

  // PLAYOFFS
  ChatbotQuestion(
    id: 'playoffs',
    category: 'Playoffs',
    keywords: ['playoff', 'bracket', 'postseason', 'championship'],
    question: 'How do playoffs work?',
    answer: 'Playoffs:\n- Top teams (usually 4-6) make playoffs\n- Single-elimination bracket tournament\n- Typically starts Week 14 or 15\n- Championship game in Week 16 or 17\n- Higher seeds get home field advantage\n\nRegular season record determines seeding!',
    alternativePhrasings: ['How do fantasy playoffs work?', 'Playoff structure'],
  ),

  // APP FEATURES
  ChatbotQuestion(
    id: 'live_scoring',
    category: 'Features',
    keywords: ['live', 'scoring', 'real', 'time', 'updates'],
    question: 'Does the app have live scoring?',
    answer: 'Live Scoring:\n- Scores update in real-time during games\n- Track your matchup as it happens\n- Get notifications for big plays by your players\n- See projections update throughout the week\n\nStay connected to never miss a moment!',
    alternativePhrasings: ['Real-time scoring', 'Live updates'],
  ),
  ChatbotQuestion(
    id: 'notifications',
    category: 'Features',
    keywords: ['notification', 'alerts', 'push', 'remind'],
    question: 'What notifications can I receive?',
    answer: 'Notifications:\n- Trade offers and responses\n- Waiver claim results\n- Lineup reminders before games\n- Injury updates for your players\n- Matchup results\n- League messages\n\nCustomize notification settings in your profile!',
    alternativePhrasings: ['What alerts do I get?', 'Push notifications'],
  ),
  ChatbotQuestion(
    id: 'chat',
    category: 'Features',
    keywords: ['chat', 'message', 'talk', 'communicate', 'league'],
    question: 'Can I chat with league members?',
    answer: 'League Chat:\n- Every league has a built-in chat\n- Send messages to all league members\n- Trash talk, coordinate trades, discuss moves\n- Access chat from the league page\n\nKeep the conversation friendly and fun!',
    alternativePhrasings: ['How to message league?', 'League messaging'],
  ),
];
