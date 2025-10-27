enum PrinterCategory {
  desktop,
  industrial,
  mobile,
  card,
  printEngine,
  healthcare,
  unknown 
}

class Printer {
  final int? id; 
  final String name;
  final String model;
  final String status; 
  final PrinterCategory category;
  final String imageUrl;
  final String description;

  Printer({
    this.id,
    required this.name,
    required this.model,
    required this.status, 
    required this.category,
    required this.imageUrl,
    required this.description,
  });

  factory Printer.fromJson(Map<String, dynamic> json) {
    return Printer(
      id: json['id'] as int?,
      name: json['name'] as String,
      model: json['model'] as String,
      status: json['status'] as String,
      category: _categoryFromString(json['category'] as String?),
      imageUrl: json['imageUrl'] as String, 
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model': model,
      'status': status,
      'category': category.name,
      'imageUrl': imageUrl, 
      'description': description,
    };
  }
}

PrinterCategory _categoryFromString(String? categoryString) {
  if (categoryString == null) {
    return PrinterCategory.unknown;
  }
  return PrinterCategory.values.firstWhere(
    (e) => e.name.toLowerCase() == categoryString.toLowerCase(),
    orElse: () => PrinterCategory.unknown,
  );
}