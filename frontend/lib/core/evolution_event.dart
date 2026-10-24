import '../data/models.dart';

/// Ephemeral presentation event. Rewards and character state have already been saved.
class EvolutionEvent {
  const EvolutionEvent({
    required this.id,
    required this.before,
    required this.after,
  });
  final String id;
  final Companion before, after;
}
