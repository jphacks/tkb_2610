import 'package:flutter/material.dart';
import '../core/theme.dart';

class YoinokoNavigation extends StatelessWidget {
  const YoinokoNavigation({
    super.key,
    required this.index,
    required this.onSelect,
  });
  final int index;
  final ValueChanged<int> onSelect;
  static const labels = ['ほーむ', 'うちのこ', 'とうこう', 'ずかん', 'せってい'];
  static const icons = [
    Icons.home_outlined,
    null,
    Icons.edit_note_rounded,
    Icons.menu_book_outlined,
    Icons.settings_outlined,
  ];
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: line)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: List.generate(
            5,
            (i) => Expanded(
              child: Semantics(
                selected: index == i,
                button: true,
                label: labels[i],
                excludeSemantics: true,
                child: InkWell(
                  key: ValueKey('tab-$i'),
                  onTap: () => onSelect(i),
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 58),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        i == 1
                            ? Image.asset(
                                'assets/icons/uchinoko.png',
                                width: 34,
                                height: 28,
                                fit: BoxFit.cover,
                                color: index == i ? orange : muted,
                                colorBlendMode: BlendMode.srcIn,
                                cacheWidth: 136,
                                excludeFromSemantics: true,
                              )
                            : Icon(
                                icons[i],
                                size: 28,
                                color: index == i ? orange : muted,
                              ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: OutlinedLabel(
                            labels[i],
                            color: index == i ? orange : muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class OutlinedLabel extends StatelessWidget {
  const OutlinedLabel(this.text, {super.key, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      fontFamily: 'Rounded',
      fontSize: 13,
      fontWeight: FontWeight.w700,
      height: 1.3,
    );
    return Stack(
      children: [
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = color,
          ),
        ),
        Text(text, style: base.copyWith(color: Colors.white)),
      ],
    );
  }
}
