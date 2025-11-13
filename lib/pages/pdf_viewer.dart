import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerPage extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerPage({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  late PdfViewerController _pdfViewerController;
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;
  PdfTextSearchResult? _searchResult;

  @override
  void initState() {
    _pdfViewerController = PdfViewerController();
    super.initState();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showSearchDialog() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchResult?.clear();
        _searchController.clear();
      }
    });
  }

  void _searchText(String searchText) {
    if (searchText.isEmpty) {
      return;
    }
    _searchResult = _pdfViewerController.searchText(searchText);

    if (_searchResult != null) {
      _searchResult!.addListener(() {
        if (_searchResult!.hasResult && mounted) {
          setState(() {});
        }
      });
    }
  }

  void _openBookmarkView() {
    if (_pdfViewerKey.currentState?.isBookmarkViewOpen ?? false) {
      Navigator.pop(context);
    } else {
      _pdfViewerKey.currentState?.openBookmarkView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        title: Text(widget.title),
        backgroundColor: const Color(0xFFF5F5F8),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.black,
            height: 1.0,
          ),
        ),
        actions: [
          // Search Icon
          IconButton(
            icon: Icon(_showSearchBar ? Icons.search_off : Icons.search),
            tooltip: 'Search',
            onPressed: _showSearchDialog,
          ),
          // Bookmark Icon
          IconButton(
            icon: Icon(
              (_pdfViewerKey.currentState?.isBookmarkViewOpen ?? false)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
            tooltip: 'Bookmarks',
            onPressed: _openBookmarkView,
          ),
        ],
      ),
      body: Stack(
        children: [
          // PDF Viewer
          SfPdfViewer.network(
            widget.pdfUrl,
            key: _pdfViewerKey,
            controller: _pdfViewerController,
            onDocumentLoadFailed: (details) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to load PDF: ${details.error}')),
              );
            },
          ),

          // Search Bar Overlay
          if (_showSearchBar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                elevation: 4,
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search in document...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          _searchResult?.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (text) {
                                setState(() {});
                              },
                              onSubmitted: _searchText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Previous Match
                          IconButton(
                            icon: const Icon(Icons.arrow_upward),
                            tooltip: 'Previous',
                            onPressed: _searchController.text.isEmpty
                                ? null
                                : () {
                                    _searchResult?.previousInstance();
                                  },
                          ),
                          // Next Match
                          IconButton(
                            icon: const Icon(Icons.arrow_downward),
                            tooltip: 'Next',
                            onPressed: _searchController.text.isEmpty
                                ? null
                                : () {
                                    _searchResult?.nextInstance();
                                  },
                          ),
                        ],
                      ),
                      // Search Results Info
                      if (_searchResult?.hasResult == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Found ${_searchResult!.totalInstanceCount} matches '
                            '(${_searchResult!.currentInstanceIndex}/${_searchResult!.totalInstanceCount})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      if (_searchResult != null &&
                          !_searchResult!.hasResult &&
                          _searchResult!.isSearchCompleted &&
                          _searchController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'No matches found',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}