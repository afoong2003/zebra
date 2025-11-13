import 'package:supabase_flutter/supabase_flutter.dart';

Future<List<Map<String, dynamic>>> getCategories() async {
  try {
    final List<Map<String, dynamic>> data = await Supabase.instance.client
        .from('categories')
        .select();
    return data;
  } catch (error) {
    print('Error fetching categories: $error');
    return [];
  }
}

Future<List<Map<String, dynamic>>> getSeriesByCategory({
  required int categoryId,
  required List<String> seriesLabels,
}) async {
  try {
    final List<Map<String, dynamic>> data = await Supabase.instance.client
        .from('series')
        .select('name, image_url')
        .eq('category_id', categoryId)
        .inFilter('name', seriesLabels);
    return data;
  } catch (error) {
    print('Error fetching series: $error');
    return [];
  }
}

Future<List<Map<String, dynamic>>> getModelsByCategoryAndSeries({
  required int categoryId,
  required int seriesId,
  required List<String> model,
}) async {
  try {
    final List<Map<String, dynamic>> data = await Supabase.instance.client
        .from('printer_models')
        .select('name, image_url, manual_url')
        .eq('category_id', categoryId)
        .eq('series_id', seriesId)
        .inFilter('name', model);
    return data;
  } catch (error) {
    print('Error fetching models: $error');
    return [];
  }
}

/// Fetches printer model information from Supabase
/// Returns a map with 'name' and 'image_url', or empty map if not found
Future<Map<String, String?>> fetchModelName(String printerName) async {
  try {
    // Fetch printer_models from Supabase
    final List<Map<String, dynamic>> models = await Supabase.instance.client
        .from('printer_models')
        .select('name, image_url');
    
    final match = models.firstWhere(
      (row) {
        final rowName = row['name'] as String?;
        if (rowName == null) return false;
        return rowName.toLowerCase().trim() == printerName.toLowerCase().trim();
      },
      orElse: () => <String, dynamic>{},
    );
    
    if (match.isEmpty) {
      print('No matching printer model found for: $printerName');
      return {'name': null, 'image_url': null};
    }
    
    return {
      'name': match['name'] as String?,
      'image_url': match['image_url'] as String?,
    };
  } catch (error) {
    print('Error fetching model name: $error');
    return {'name': null, 'image_url': null};
  }
}

