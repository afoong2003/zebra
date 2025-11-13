import 'package:flutter/material.dart';
import '../services/fetch_data.dart';

class MobilePage extends StatefulWidget {
  const MobilePage({super.key});

  @override
  State<MobilePage> createState() => _MobilePageState();
}

class _MobilePageState extends State<MobilePage> {
  late Future<List<Map<String, dynamic>>> _seriesFuture;

  final List<String> staticSeries = [
    'ZQ600 Plus Series',
    'ZQ500 Series',
    'ZQ300 Plus Series',
  ];

  @override
  void initState() {
    super.initState();
    _seriesFuture = getSeriesByCategory(categoryId: 3, seriesLabels: staticSeries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        title: const Text('Mobile Printers'),
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
              children: staticSeries.map((label) {
                final imageUrl = nameToImage[label.toLowerCase().trim()] ??
                    'https://via.placeholder.com/80?text=${Uri.encodeComponent(label)}';
                return Container(
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
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

class ZQ600Models extends StatefulWidget {
  const ZQ600Models({super.key});

  @override
  State<ZQ600Models> createState() => _ZQ600ModelsState();
}

class _ZQ600ModelsState extends State<ZQ600Models> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Color(0xFFF5F5F8),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Container(
            color: Colors.black,
            height: 1.0,
          ),
        ),
      ),
      body: Center(
        child: Text('Settings Page'),
      ),
    );
  }
}

class ZQ300Models extends StatefulWidget {
  const ZQ300Models({super.key});

  @override
  State<ZQ300Models> createState() => _ZQ300ModelsState();
}

class _ZQ300ModelsState extends State<ZQ300Models> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Color(0xFFF5F5F8),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Container(
            color: Colors.black,
            height: 1.0,
          ),
        ),
      ),
      body: Center(
        child: Text('Settings Page'),
      ),
    );
  }
}

class ZQ500Models extends StatefulWidget {
  const ZQ500Models({super.key});

  @override
  State<ZQ500Models> createState() => _ZQ500ModelsState();
}

class _ZQ500ModelsState extends State<ZQ500Models> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Color(0xFFF5F5F8),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Container(
            color: Colors.black,
            height: 1.0,
          ),
        ),
      ),
      body: Center(
        child: Text('Settings Page'),
      ),
    );
  }
}