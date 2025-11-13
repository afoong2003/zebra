import 'package:flutter/material.dart';
import '../services/fetch_data.dart';
import '../pages/pdf_viewer.dart';

class DesktopPage extends StatefulWidget {
  const DesktopPage({super.key});

  @override
  State<DesktopPage> createState() => _DesktopPageState();
}

class _DesktopPageState extends State<DesktopPage> {
  late Future<List<Map<String, dynamic>>> _seriesFuture;

  final List<String> staticSeries = [
    'ZD600 Series',
    'ZD400 Series',
    'ZD200 Series',
  ];

  // Map each label to its destination page
  final Map<String, Widget> seriesPages = {
    'ZD600 Series': const ZD600Models(),
    'ZD400 Series': const ZD400Models(),
    'ZD200 Series': const ZD200Models(),
  };

  @override
  void initState() {
    super.initState();
    _seriesFuture = getSeriesByCategory(categoryId: 1, seriesLabels: staticSeries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        title: const Text('Desktop Printers'),
        backgroundColor: const Color(0xFFF5F5F8),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.black,
            height: 1.0,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _seriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final dbSeries = snapshot.data ?? [];
            // Map series name to image_url for quick lookup
            final Map<String, String> nameToImage = {
              for (var series in dbSeries)
                (series['name'] as String).toLowerCase().trim():
                  (series['image_url'] as String)
            };

            return GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: staticSeries.map((label) {
                final imageUrl = nameToImage[label.toLowerCase().trim()] ??
                    'https://via.placeholder.com/80?text=${Uri.encodeComponent(label)}';
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final page = seriesPages[label];
                    if (page != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => page),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 80,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.image_not_supported,
                                    size: 48, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          label,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

class ZD600Models extends StatefulWidget {
  const ZD600Models({super.key});

  @override
  State<ZD600Models> createState() => _ZD600ModelsState();
}

class _ZD600ModelsState extends State<ZD600Models> {
  late Future<List<Map<String, dynamic>>> _seriesFuture;

  final List<String> models = [
    'ZD621',
    'ZD611',
    'ZD621R',
    'ZD611R'
  ];

  @override
  void initState() {
    super.initState();
    _seriesFuture = getModelsByCategoryAndSeries(categoryId: 1, seriesId: 1, model: models);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZD600 Series'),
        backgroundColor: const Color(0xFFF5F5F8),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.black,
            height: 1.0,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _seriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.black));
            }
            final dbSeries = snapshot.data ?? [];
            
            // Create maps for both image_url and manual_url
            final Map<String, String> nameToImage = {
              for (var series in dbSeries)
                (series['name'] as String).toLowerCase().trim():
                  (series['image_url'] as String)
            };
            final Map<String, String> nameToManual = {
              for (var series in dbSeries)
                (series['name'] as String).toLowerCase().trim():
                  (series['manual_url'] as String)
            };

            return GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: models.map((label) {
                final imageUrl = nameToImage[label.toLowerCase().trim()] ??
                    'https://via.placeholder.com/80?text=${Uri.encodeComponent(label)}';
                final manualUrl = nameToManual[label.toLowerCase().trim()];
                
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (manualUrl != null && manualUrl.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PdfViewerPage(
                            pdfUrl: manualUrl,
                            title: '$label Manual',
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No manual available for this model')),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 80,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.image_not_supported,
                                    size: 48, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          label,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

class ZD400Models extends StatefulWidget {
  const ZD400Models({super.key});

  @override
  State<ZD400Models> createState() => _ZD400ModelsState();
}

class _ZD400ModelsState extends State<ZD400Models> {
  late Future<List<Map<String, dynamic>>> _seriesFuture;

  final List<String> models = [
    'ZD421',
    'ZD411D',
    'ZD411T',
  ];

  @override
  void initState() {
    super.initState();
    _seriesFuture = getModelsByCategoryAndSeries(categoryId: 1, seriesId: 2, model: models);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZD600 Series'),
        backgroundColor: const Color(0xFFF5F5F8),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.black,
            height: 1.0,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _seriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.black));
            }
            final dbSeries = snapshot.data ?? [];
            // Map series name to image_url for quick lookup
            final Map<String, String> nameToImage = {
              for (var series in dbSeries)
                (series['name'] as String).toLowerCase().trim():
                  (series['image_url'] as String)
            };

            return GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: models.map((label) {
                final imageUrl = nameToImage[label.toLowerCase().trim()] ??
                    'https://via.placeholder.com/80?text=${Uri.encodeComponent(label)}';
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  /*
                  onTap: () {
                    final page = seriesPages[label];
                    if (page != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => page),
                      );
                    }
                  },
                  */
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 80,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.image_not_supported,
                                    size: 48, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          label,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

class ZD200Models extends StatefulWidget {
  const ZD200Models({super.key});

  @override
  State<ZD200Models> createState() => _ZD200ModelsState();
}

class _ZD200ModelsState extends State<ZD200Models> {
  late Future<List<Map<String, dynamic>>> _seriesFuture;

  final List<String> models = [
    'ZD220',
  ];

  @override
  void initState() {
    super.initState();
    _seriesFuture = getModelsByCategoryAndSeries(categoryId: 1, seriesId: 3, model: models);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZD600 Series'),
        backgroundColor: const Color(0xFFF5F5F8),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.black,
            height: 1.0,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _seriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.black));
            }
            final dbSeries = snapshot.data ?? [];
            // Map series name to image_url for quick lookup
            final Map<String, String> nameToImage = {
              for (var series in dbSeries)
                (series['name'] as String).toLowerCase().trim():
                  (series['image_url'] as String)
            };

            return GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: models.map((label) {
                final imageUrl = nameToImage[label.toLowerCase().trim()] ??
                    'https://via.placeholder.com/80?text=${Uri.encodeComponent(label)}';
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  /*
                  onTap: () {
                    final page = seriesPages[label];
                    if (page != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => page),
                      );
                    }
                  },
                  */
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 80,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.image_not_supported,
                                    size: 48, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          label,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}