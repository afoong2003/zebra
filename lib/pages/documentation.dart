import 'package:flutter/material.dart';
import '../printers/desktop.dart';
import '../printers/industrial.dart';
import '../printers/mobile.dart';
import '../printers/card.dart';
import '../printers/print_engines.dart';
import '../printers/healthcare.dart';
import '../services/fetch_data.dart';


class DocumentationPage extends StatefulWidget {
  const DocumentationPage({super.key});

  @override
  State<DocumentationPage> createState() => _DocumentationPageState();
}

class _DocumentationPageState extends State<DocumentationPage> {
  late Future<List<Map<String, dynamic>>> _categoriesFuture;

  final List<Map<String, dynamic>> staticCategories = [
    {'label': 'Desktop', 'page': const DesktopPage()},
    {'label': 'Industrial', 'page': const IndustrialPage()},
    {'label': 'Mobile', 'page': const MobilePage()},
    {'label': 'Card', 'page': const CardPage()},
    {'label': 'Print Engine', 'page': const PrintEnginesPage()},
    {'label': 'Healthcare', 'page': const HealthcarePage()},
  ];

  @override
  void initState() {
    super.initState();
    _categoriesFuture = getCategories();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        title: const Text('Documentation'),
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
          future: _categoriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.black));
            }
            final dbCategories = snapshot.data ?? [];
            // Map category name to image_url for quick lookup
            final Map<String, String> nameToImage = {
              for (var cat in dbCategories)
                (cat['name'] as String).toLowerCase().trim(): 
                (cat['image_url'] as String)
            };

            return Column(
              children: [
                //const SizedBox(height: 55),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: staticCategories.map((cat) {
                      final label = cat['label'] as String;
                      final imageUrl = nameToImage[label.toLowerCase().trim()] ??
                          'https://via.placeholder.com/80?text=$label';
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        
                        
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => cat['page'] as Widget),
                          );
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
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
