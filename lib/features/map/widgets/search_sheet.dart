import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/place.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/search_provider.dart';

class SearchSheet extends ConsumerStatefulWidget {
  final LatLng searchCenter;
  final ValueChanged<Place> onPlaceSelected;

  const SearchSheet({
    super.key,
    required this.searchCenter,
    required this.onPlaceSelected,
  });

  @override
  ConsumerState<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<SearchSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();

    if (value.trim().isEmpty) {
      ref.read(searchProvider.notifier).clear();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchProvider.notifier).search(
            value,
            widget.searchCenter,
          );
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(searchProvider.notifier).clear();
    setState(() {});
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final searchState = ref.watch(searchProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.searchPlaceholder,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildResults(searchState, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(
    SearchState state,
    AppLocalizations l10n,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      );
    }

    if (state.query.isEmpty) {
      return Center(
        child: Text(
          l10n.searchPlaceholder,
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5),
          ),
        ),
      );
    }

    if (state.results.isEmpty) {
      return Center(child: Text(l10n.noResults));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final place = state.results[index];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.location_on_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(
            place.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: place.address.isNotEmpty
              ? Text(
                  place.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          onTap: () => widget.onPlaceSelected(place),
        );
      },
    );
  }
}
