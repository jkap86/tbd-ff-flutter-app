import 'package:flutter/material.dart';
import '../models/auction_model.dart';
import 'nomination_card.dart';

class NominationGridWidget extends StatelessWidget {
  final List<AuctionNomination> nominations;
  final int? myRosterId;
  final Function(AuctionNomination) onTapNomination;
  final Function(AuctionNomination) onPlaceBid;

  const NominationGridWidget({
    Key? key,
    required this.nominations,
    required this.myRosterId,
    required this.onTapNomination,
    required this.onPlaceBid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (nominations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.gavel, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No active nominations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Be the first to nominate a player!',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: nominations.length,
      itemBuilder: (context, index) {
        final nomination = nominations[index];
        final isMyBid = myRosterId != null && nomination.winningRosterId == myRosterId;

        return NominationCard(
          nomination: nomination,
          isMyBid: isMyBid,
          onTap: () => onTapNomination(nomination),
          onBid: () => onPlaceBid(nomination),
        );
      },
    );
  }
}
