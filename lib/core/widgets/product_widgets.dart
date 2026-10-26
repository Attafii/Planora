import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../models/paged.dart';

void feedback(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.ink,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Confirm',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class ProductPage extends StatelessWidget {
  const ProductPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.embedded = false,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 24,
                runSpacing: 16,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle!,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
    return embedded
        ? content
        : Scaffold(
            appBar: AppBar(),
            body: SafeArea(child: content),
          );
  }
}

class BusyButton extends StatefulWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.enabled = true,
  });
  final String label;
  final Future<void> Function() onPressed;
  final IconData? icon;
  final bool outlined, enabled;
  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;
  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } catch (e) {
      if (mounted) feedback(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_busy) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 20),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(_busy ? 'Please wait…' : widget.label)),
      ],
    );
    return widget.outlined
        ? OutlinedButton(
            onPressed: widget.enabled && !_busy ? _run : null,
            child: content,
          )
        : FilledButton(
            onPressed: widget.enabled && !_busy ? _run : null,
            child: content,
          );
  }
}

class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.muted),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    ),
  );
}

class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback) builder;
  @override
  State<AsyncView<T>> createState() => AsyncViewState<T>();
}

class AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void refresh() {
    if (!mounted) return;
    // setState callbacks must be synchronous and must not return the Future.
    final next = widget.load();
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, s) {
      if (s.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (s.hasError) {
        return StateMessage(
          title: 'Could not load this view',
          message: s.error.toString(),
          icon: Icons.cloud_off_outlined,
          action: OutlinedButton(
            onPressed: refresh,
            child: const Text('Retry'),
          ),
        );
      }
      return widget.builder(context, s.data as T, refresh);
    },
  );
}

class PagedView<T> extends StatefulWidget {
  const PagedView({
    super.key,
    required this.load,
    required this.itemBuilder,
    required this.emptyTitle,
    required this.emptyMessage,
    this.emptyAction,
  });
  final Future<Paged<T>> Function(int) load;
  final Widget Function(BuildContext, T) itemBuilder;
  final String emptyTitle, emptyMessage;
  final Widget? emptyAction;
  @override
  State<PagedView<T>> createState() => PagedViewState<T>();
}

class PagedViewState<T> extends State<PagedView<T>> {
  final List<T> _items = [];
  bool _loading = true, _more = false;
  Object? _error;
  @override
  void initState() {
    super.initState();
    _fetch(true);
  }

  Future<void> refresh() => _fetch(true);
  Future<void> _fetch(bool reset) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await widget.load(reset ? 0 : _items.length);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(p.items);
        _more = p.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return StateMessage(
        title: 'Could not load the list',
        message: _error.toString(),
        icon: Icons.cloud_off_outlined,
        action: OutlinedButton(onPressed: refresh, child: const Text('Retry')),
      );
    }
    if (_items.isEmpty) {
      return StateMessage(
        title: widget.emptyTitle,
        message: widget.emptyMessage,
        action: widget.emptyAction,
      );
    }
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: _items.length + 1,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          if (i < _items.length) return widget.itemBuilder(ctx, _items[i]);
          return Column(
            children: [
              if (_error != null)
                Text(
                  _error.toString(),
                  style: const TextStyle(color: AppColors.error),
                ),
              if (_more || _error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => _fetch(false),
                    child: Text(_loading ? 'Loading…' : 'Load more'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text(label.replaceAll('_', ' ')),
    visualDensity: VisualDensity.compact,
    backgroundColor: AppColors.tint,
  );
}

class ProgressMeter extends StatelessWidget {
  const ProgressMeter(this.percent, {super.key, this.label});
  final int percent;
  final String? label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${label ?? 'Progress'} $percent percent',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label ?? 'Progress',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 6,
            color: AppColors.teal,
            backgroundColor: AppColors.tint,
          ),
        ),
      ],
    ),
  );
}

class SearchBox extends StatefulWidget {
  const SearchBox({super.key, required this.onSearch, this.hint = 'Search'});
  final ValueChanged<String> onSearch;
  final String hint;
  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    textInputAction: TextInputAction.search,
    onSubmitted: widget.onSearch,
    decoration: InputDecoration(
      hintText: widget.hint,
      prefixIcon: const Icon(Icons.search),
      helperText: 'Press Enter or Search to apply',
      suffixIcon: IconButton(
        tooltip: 'Clear search',
        onPressed: () {
          _controller.clear();
          widget.onSearch('');
        },
        icon: const Icon(Icons.close),
      ),
    ),
  );
}

String readableDate(String? value) =>
    value == null ? 'No target date' : value.substring(0, 10);
