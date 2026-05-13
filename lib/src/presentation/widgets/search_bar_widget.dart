import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';
import '../bloc/search_state.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';

class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isListVisible = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isListVisible = _focusNode.hasFocus;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: (value) {
                context.read<SearchBloc>().add(SearchQueryChanged(value));
              },
              style: const TextStyle(
                color: Color(0xFF637381),
                fontSize: 18,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar direcciones o paradas',
                hintStyle: const TextStyle(
                  color: Color(0xFF919EAB),
                  fontSize: 18,
                ),
                border: InputBorder.none,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.search,
                    color: Color(0xFF919EAB),
                    size: 28,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF919EAB)),
                        onPressed: () {
                          _controller.clear();
                          context.read<SearchBloc>().add(const SearchClearRequested());
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
        if (_isListVisible)
          BlocBuilder<SearchBloc, SearchState>(
            builder: (context, state) {
              if (state is SearchLoading) {
                return Card(
                  margin: const EdgeInsets.only(top: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: const LinearProgressIndicator(),
                );
              }
              if (state is SearchNoResults) {
                return Card(
                  margin: const EdgeInsets.only(top: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: const ListTile(
                    title: Text('No se encontraron coincidencias'),
                  ),
                );
              }
              if (state is SearchResultsLoaded) {
                return Card(
                  margin: const EdgeInsets.only(top: 8),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemCount: state.results.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = state.results[index];
                        return ListTile(
                          leading: const Icon(Icons.place_outlined, color: Color(0xFF919EAB)),
                          title: Text(
                            result.name,
                            style: const TextStyle(color: Color(0xFF212B36)),
                          ),
                          onTap: () {
                            _controller.text = result.name;
                            _focusNode.unfocus();
                            context.read<MapBloc>().add(MapShowSearchResultRequested(result));
                          },
                        );
                      },
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

// Previsualización oficial para VS Code
@Preview(name: 'Search Bar Aesthetic')
Widget previewSearchBar() {
  return const Scaffold(
    backgroundColor: Color(0xFFF4F6F8),
    body: Padding(
      padding: EdgeInsets.all(20.0),
      child: SearchBarWidget(),
    ),
  );
}
