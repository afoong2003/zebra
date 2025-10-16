enum PrinterCategory {
  desktop,
  industrial,
  mobile,
  card,
  printEngine,
  healthcare,
  unknown,
}

class PrinterEntity {
  final int? id;
  final String name;
  final String model;
  final PrinterCategory category;
  final String imageUrl;

  PrinterEntity({
    this.id,
    required this.name,
    required this.model,
    required this.category,
    required this.imageUrl,
  });

  factory PrinterEntity.fromJson(Map<String, dynamic> json) {
    return PrinterEntity(
      id: json['id'] as int?,
      name: json['name'] as String,
      model: json['model'] as String,
      category: _categoryFromString(json['category'] as String?),
      imageUrl: json['imageUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model': model,
      'category': category.name,
      'imageUrl': imageUrl,
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