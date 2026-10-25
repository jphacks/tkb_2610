import 'dart:math' as math;
import '../data/models.dart';

/// A shared motion vocabulary for the starter and all seven evolution families.
/// Coordinates are relative to the image size, so small status portraits stay subtle.
class CharacterPose {
  const CharacterPose({
    this.x = 0,
    this.y = 0,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.faceLeft = false,
  });
  final double x, y, rotation, scaleX, scaleY;
  final bool faceLeft;
}

CharacterPose characterPose({
  required CharacterForm form,
  required double seconds,
  required double travelSeconds,
  required CharacterMotion motion,
  double travel = 0,
  bool? walking,
  bool? facingRight,
}) {
  if (motion == CharacterMotion.sleeping) return const CharacterPose();
  final family = form.firstCategory ?? -1;
  // Half the cycle is spent resting. Smooth endpoints prevent abrupt turns.
  final phase = travelSeconds % 24;
  double position = 0;
  var moving = false;
  var right = true;
  double ease(double t) => t * t * (3 - 2 * t);
  if (phase >= 3 && phase < 6) {
    position = ease((phase - 3) / 3);
    moving = true;
  } else if (phase >= 6 && phase < 9) {
    position = 1;
  } else if (phase >= 9 && phase < 15) {
    position = 1 - 2 * ease((phase - 9) / 6);
    moving = true;
    right = false;
  } else if (phase >= 15 && phase < 18) {
    position = -1;
    right = false;
  } else if (phase >= 18 && phase < 21) {
    position = -1 + ease((phase - 18) / 3);
    moving = true;
  }
  moving =
      (walking ?? (moving && travel > 0)) && motion == CharacterMotion.idle;
  final energy = motion == CharacterMotion.lowEnergy ? .35 : 1.0;
  final excited =
      motion == CharacterMotion.happy || motion == CharacterMotion.tapped;
  final tempo = switch (family) {
    -1 => 1.2,
    0 => .65,
    1 => 2.2,
    2 => 1.25,
    3 => 1.6,
    4 => .45,
    5 => .7,
    _ => 1.9,
  };
  final wave = math.sin(seconds * math.pi * 2 * (moving ? tempo : .45));
  final breath = math.sin(seconds * math.pi * 2 * .45);
  final hop = math
      .pow(math.sin(seconds * math.pi * (excited ? 2.2 : tempo)), 2)
      .toDouble();
  var y = 0.0, rotation = 0.0, sx = 1.0, sy = 1.0;
  switch (family) {
    case 0: // Jellyfish pulse and drift.
      y = -.018 - wave * (moving ? .035 : .018);
      rotation = wave * .035;
      sx += breath * .022;
      sy -= breath * .018;
    case 4: // Whale swimming through the room.
      y = -.015 - wave * (moving ? .026 : .015);
      rotation = wave * (moving ? .07 : .025);
      sy += breath * .012;
    case 5: // Turtle: a small, slow waddle.
      y = moving ? -hop * .008 : 0;
      rotation = wave * (moving ? .025 : .006);
      sy += breath * .009;
    case 3: // Lion: a heavier stride.
      y = moving ? -hop * .018 : 0;
      rotation = wave * (moving ? .025 : .008);
      sy += breath * .012;
    default: // Pono, deer, sheep and cat each have their own hop cadence.
      final height = family == 1
          ? .05
          : family == 2
          ? .04
          : family == 6
          ? .03
          : .045;
      y = moving ? -hop * height : -math.max(0, breath) * .006;
      rotation = wave * (moving ? .045 : .012);
      final squash = moving ? wave * .022 : breath * .012;
      sx += squash;
      sy -= squash;
  }
  if (excited) {
    y -= hop * .055;
    rotation += wave * .045;
    sx += wave * .025;
    sy -= wave * .025;
  }
  return CharacterPose(
    x: position * travel,
    y: y * energy,
    rotation: rotation * energy,
    scaleX: 1 + (sx - 1) * energy,
    scaleY: 1 + (sy - 1) * energy,
    // These side-facing drawings point left in their source artwork.
    faceLeft:
        (facingRight ?? (travel > 0 && right)) && [1, 4, 5].contains(family),
  );
}
