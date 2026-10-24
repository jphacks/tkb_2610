import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../data/models.dart';
import 'common.dart';

/// Fetches on demand, deduplicates by ID and keeps failures retryable at the same offset.
class PagedList<T> extends StatefulWidget {
  const PagedList({
    super.key,
    required this.load,
    required this.idOf,
    required this.builder,
  });
  final Future<PageResult<T>> Function(int offset) load;
  final String Function(T item) idOf;
  final Widget Function(List<T> items, int total, Widget footer) builder;
  @override
  State<PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<PagedList<T>> {
  final items = <T>[];
  int offset = 0, total = 0;
  bool busy = false, hasMore = true;
  String? error;
  @override
  void initState() {
    super.initState();
    Future.microtask(fetch);
  }

  Future<void> fetch({bool reset = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final page = await widget.load(reset ? 0 : offset);
      if (!mounted) return;
      setState(() {
        final merged = {
          if (!reset)
            for (final item in items) widget.idOf(item): item,
          for (final item in page.items) widget.idOf(item): item,
        };
        items
          ..clear()
          ..addAll(merged.values);
        offset = page.nextOffset;
        total = page.totalCount;
        hasMore = page.hasMore && page.items.isNotEmpty;
        busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = GameController.message(e);
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => fetch(reset: true),
    child: widget.builder(
      items,
      total,
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            if (error != null) ErrorNotice(error!),
            if (busy)
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (!busy && (hasMore || error != null))
              OutlinedButton(
                onPressed: fetch,
                child: Text(error != null ? '再読み込み' : 'もっと見る'),
              ),
          ],
        ),
      ),
    ),
  );
}
