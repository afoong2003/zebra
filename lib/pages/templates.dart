import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/zebra_service.dart';
import '../services/printer_settings_helper.dart';

class UsePrinter extends StatefulWidget {
  final String printerName;

  const UsePrinter({super.key, required this.printerName});

  @override
  State<UsePrinter> createState() => _UsePrinterState();
}

class _UsePrinterState extends State<UsePrinter> {
  final ZebraService _zebraService = ZebraService();
  final PrinterSettingsHelper _settingsHelper = PrinterSettingsHelper();

  // Default Template ZPL commands
  final Map<String, String> _defaultTemplates = {
    'Template 1': '''
^FX Top section with logo, name and address.
^CF0,90
^FO75,75^GB150,150,150^FS
^FO112,112^FR^GB150,150,150^FS
^FO140,140^GB60,60,60^FS
^FO330,75^FDIntershipping, Inc.^FS
^CF0,45
^FO330,170^FD1000 Shipping Lane^FS
^FO330,230^FDShelbyville TN 38102^FS
^FO330,290^FDUnited States (USA)^FS
^FO75,375^GB1050,5,5^FS

^FX Second section with recipient address and permit information.
^CFA,45
^FO75,450^FDJohn Doe^FS
^FO75,510^FD100 Main Street^FS
^FO75,570^FDSpringfield TN 39021^FS
^FO75,630^FDUnited States (USA)^FS
^CFA,25
^FO900,450^GB225,225,5^FS
^FO960,510^FDPermit^FS
^FO960,585^FD123456^FS
^FO75,750^GB1050,5,5^FS

^FX Third section with bar code.
^BY7,2,405
^FO150,825^BC^FD12345678^FS

^FX Fourth section (the two boxes on the bottom).
^FO75,1350^GB1050,375,5^FS
^FO600,1350^GB5,375,5^FS
^CF0,60
^FO150,1440^FDCtr. X34B-1^FS
^FO150,1515^FDREF1 F00B47^FS
^FO150,1590^FDREF2 BL4H8^FS
^CF0,285
^FO705,1430^FDCA^FS
''',
    'Template 2': '''
^FX Simple Address Label
^CF0,60
^FO50,50^FDFrom: Your Company^FS
^FO50,120^FD123 Business St^FS
^FO50,190^FDCity, ST 12345^FS

^FO50,300^GB700,3,3^FS

^CF0,50
^FO50,350^FDTo: Customer Name^FS
^FO50,410^FD456 Customer Ave^FS
^FO50,470^FDTown, ST 67890^FS
''',
    'Template 3': '''
^FX Barcode Label
^CF0,50
^FO100,50^FDProduct: ABC-123^FS
^FO100,120^FDSKU: 987654321^FS

^BY3,3,100
^FO150,200^BC^FD987654321^FS

^CF0,40
^FO100,350^FDPrice: \$99.99^FS
^FO100,410^FDQuantity: 100^FS
''',
    'Template 4': '''
^FX QR Code Label
^CF0,50
^FO50,50^FDScan for Details^FS

^FO100,120^BQN,2,6^FDQA,https://example.com/product/12345^FS

^CF0,40
^FO50,380^FDProduct ID: 12345^FS
^FO50,440^FDManufactured: 2024-01^FS
''',
  };

  Map<String, String> _templateNames = {};
  Map<String, String> _templates = {};

  final Map<String, Uint8List?> _templateThumbnails = {};
  bool _isLoadingThumbnails = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final namesJson = prefs.getString('template_names');

    if (!mounted) return;
    setState(() {
      _templates = Map.from(_defaultTemplates);

      // Load saved ZPL for each default template
      for (var key in _defaultTemplates.keys) {
        final savedZpl = prefs.getString('template_zpl_$key');
        if (savedZpl != null) {
          _templates[key] = savedZpl;
        }
      }

      if (namesJson != null) {
        try {
          final decoded = json.decode(namesJson) as Map<String, dynamic>;
          _templateNames = decoded.map(
            (key, value) => MapEntry(key, value.toString()),
          );

          for (var key in _templateNames.keys) {
            if (!_defaultTemplates.containsKey(key)) {
              final savedZpl = prefs.getString('template_zpl_$key');
              if (savedZpl != null) {
                _templates[key] = savedZpl;
              }
            }
          }
        } catch (e) {
          print('Error loading template names: $e');
          _templateNames = {};
        }
      }

      // Initialize any missing template names with defaults
      for (var key in _defaultTemplates.keys) {
        if (!_templateNames.containsKey(key)) {
          _templateNames[key] = key;
        }
      }
    });

    _loadAllThumbnails();
  }

  Future<void> _loadAllThumbnails() async {
    if (_isLoadingThumbnails) return;

    if (!mounted) return;
    setState(() => _isLoadingThumbnails = true);

    final settings = await _settingsHelper.fetchAllSettings(
      forceRefresh: false,
    );
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    final defaultWidthDots =
        int.tryParse(
          settings['labelWidthDots'] ?? settings['labelWidth'] ?? '1200',
        ) ??
        1200;
    final defaultHeightDots =
        int.tryParse(settings['labelHeight'] ?? '1800') ?? 1800;
    final printerDpi = int.tryParse(settings['dpi'] ?? '203') ?? 203;

    int index = 0;
    // Copy keys to list to avoid ConcurrentModificationError
    final templateKeys = _templates.keys.toList();
    for (var templateKey in templateKeys) {
      if (!mounted) return;

      // Check if this template has saved dimensions (custom templates from upload)
      final savedWidth = prefs.getInt('template_width_$templateKey');
      final savedHeight = prefs.getInt('template_height_$templateKey');
      final savedRenderDpi = prefs.getInt('template_render_dpi_$templateKey');

      // Use saved dimensions if available, otherwise use printer defaults
      final widthDots = savedWidth ?? defaultWidthDots;
      final heightDots = savedHeight ?? defaultHeightDots;
      // For custom templates with saved render DPI, use that for preview
      final dpi = savedRenderDpi ?? printerDpi;

      await _loadTemplateThumbnail(templateKey, widthDots, heightDots, dpi);

      index++;
      if (index < _templates.length) {
        await Future.delayed(const Duration(milliseconds: 450));
      }
    }

    if (!mounted) return;
    setState(() => _isLoadingThumbnails = false);
  }

  // Generate single thumbnail for a template
  Future<void> _loadTemplateThumbnail(
    String templateKey,
    int widthDots,
    int heightDots,
    int printerDpi,
  ) async {
    try {
      final widthInches = widthDots / printerDpi;
      final heightInches = heightDots / printerDpi;

      String dpmm;
      if (printerDpi >= 580) {
        dpmm = '24dpmm';
      } else if (printerDpi >= 280) {
        dpmm = '12dpmm';
      } else if (printerDpi >= 180) {
        dpmm = '8dpmm';
      } else {
        dpmm = '6dpmm';
      }

      final fullZpl = '''
^XA
^PW$widthDots
^LL$heightDots

${_templates[templateKey]}

^XZ
''';

      final url = Uri.parse(
        'http://api.labelary.com/v1/printers/$dpmm/labels/${widthInches.toStringAsFixed(1)}x${heightInches.toStringAsFixed(1)}/0/',
      );

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'image/png',
            },
            body: fullZpl,
          )
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _templateThumbnails[templateKey] = response.bodyBytes;
        });
        print(
          'Loaded thumbnail for $templateKey (${response.bodyBytes.length} bytes)',
        );
      }
    } catch (e) {
      print('Error loading thumbnail for $templateKey: $e');
      if (!mounted) return;
      setState(() {
        _templateThumbnails[templateKey] = null;
      });
    }
  }

  Future<void> _saveTemplateNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('template_names', json.encode(_templateNames));
  }

  Future<void> _saveTemplateZpl(String templateKey, String zpl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('template_zpl_$templateKey', zpl);
  }

  Future<void> _updateTemplateName(String oldKey, String newName) async {
    if (newName.trim().isEmpty) return;

    setState(() {
      _templateNames[oldKey] = newName.trim();
    });
    await _saveTemplateNames();
  }

  // Generate a unique key for new templates
  String _generateTemplateKey() {
    int counter = _templates.length + 1;
    String key = 'Template $counter';
    while (_templates.containsKey(key)) {
      counter++;
      key = 'Template $counter';
    }
    return key;
  }

  // Add a new template
  Future<void> _addNewTemplate() async {
    final templateKey = _generateTemplateKey();
    final templateName = 'New Template';
    final defaultZpl = '^FX New Label\n^CF0,50\n^FO50,50^FDNew Label^FS';

    setState(() {
      _templates[templateKey] = defaultZpl;
      _templateNames[templateKey] = templateName;
    });

    await _saveTemplateZpl(templateKey, defaultZpl);
    await _saveTemplateNames();

    // Open the template for editing
    if (!mounted) return;
    _showTemplatePreview(templateKey, templateName, isNew: true);
  }

  // Delete a template
  Future<void> _deleteTemplate(String templateKey) async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _templates.remove(templateKey);
      _templateNames.remove(templateKey);
      _templateThumbnails.remove(templateKey);
    });

    // Remove from persistent storage
    await prefs.remove('template_zpl_$templateKey');
    await _saveTemplateNames();
  }

  // Show delete confirmation dialog
  Future<bool> _showDeleteConfirmation(String templateName) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('Delete Template?'),
                content: Text(
                  'Are you sure you want to delete "$templateName"? This action cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F8),
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        title: Text('Print to ${widget.printerName}'),
        backgroundColor: const Color(0xFFF5F5F8),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.black, height: 1.0),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Template Grid - aligned to top
            Padding(
              padding: const EdgeInsets.all(24),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: _templates.length + 1, // +1 for add button
                itemBuilder: (context, index) {
                  // Last item is the "Add Template" card
                  if (index == _templates.length) {
                    return _buildAddTemplateCard();
                  }
                  final templateKey = _templates.keys.elementAt(index);
                  final templateName =
                      _templateNames[templateKey] ?? templateKey;
                  return _buildTemplateCard(templateKey, templateName);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add template card
  Widget _buildAddTemplateCard() {
    return InkWell(
      onTap: _addNewTemplate,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white,
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 48, color: Colors.black),
            const SizedBox(height: 8),
            Text(
              'Add Template',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Updated template card with preview thumbnail
  Widget _buildTemplateCard(String templateKey, String templateName) {
    final thumbnail = _templateThumbnails[templateKey];
    final isLoading = _isLoadingThumbnails && thumbnail == null;

    return InkWell(
      onTap: () => _showTemplatePreview(templateKey, templateName),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child:
                    isLoading
                        ? Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          ),
                        )
                        : thumbnail != null
                        ? Image.memory(thumbnail, fit: BoxFit.contain)
                        : Icon(
                          Icons.receipt_long,
                          size: 48,
                          color: Colors.black,
                        ),
              ),
            ),
            // Template name at bottom
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Text(
                templateName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTemplatePreview(
    String templateKey,
    String templateName, {
    bool isNew = false,
  }) async {
    final settings = await _settingsHelper.fetchAllSettings(
      forceRefresh: false,
    );
    final prefs = await SharedPreferences.getInstance();

    final defaultWidthDots =
        int.tryParse(
          settings['labelWidthDots'] ?? settings['labelWidth'] ?? '1200',
        ) ??
        1200;
    final defaultHeightDots =
        int.tryParse(settings['labelHeight'] ?? '1800') ?? 1800;
    final printerDpi = int.tryParse(settings['dpi'] ?? '203') ?? 203;

    // Check if this template has saved dimensions (custom templates from upload)
    final savedWidth = prefs.getInt('template_width_$templateKey');
    final savedHeight = prefs.getInt('template_height_$templateKey');
    final savedRenderDpi = prefs.getInt('template_render_dpi_$templateKey');

    print('_showTemplatePreview for $templateKey:');
    print('  savedWidth: $savedWidth');
    print('  savedHeight: $savedHeight');
    print('  savedRenderDpi: $savedRenderDpi');
    print('  defaultWidthDots: $defaultWidthDots');
    print('  defaultHeightDots: $defaultHeightDots');
    print('  printerDpi: $printerDpi');

    // Use saved dimensions if available, otherwise use printer defaults
    final widthDots = savedWidth ?? defaultWidthDots;
    final heightDots = savedHeight ?? defaultHeightDots;
    // For custom templates with saved render DPI, use that for preview
    final previewDpi = savedRenderDpi ?? printerDpi;

    print('  Using widthDots: $widthDots');
    print('  Using heightDots: $heightDots');
    print('  Using previewDpi: $previewDpi');

    // For printing, use the saved dimensions directly
    // The ZPL graphic data is baked at a specific pixel size and cannot be scaled
    // So we use the exact dimensions the template was created with
    final printWidthDots = widthDots;
    final printHeightDots = heightDots;

    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => _TemplatePreviewDialog(
            templateKey: templateKey,
            templateName: templateName,
            templateZpl: _templates[templateKey]!,
            widthDots: widthDots,
            heightDots: heightDots,
            printerDpi: previewDpi,
            isNewTemplate: isNew,
            onPrint: (quantity) async {
              return await _printTemplate(
                templateName,
                templateKey,
                quantity,
                printWidthDots,
                printHeightDots,
              );
            },
            onNameChanged: (newName) async {
              await _updateTemplateName(templateKey, newName);
            },
            onZplChanged: (newZpl) async {
              //  Save ZPL to persistent storage and refresh thumbnail
              if (!mounted) return;
              setState(() {
                _templates[templateKey] = newZpl;
              });
              await _saveTemplateZpl(templateKey, newZpl);
              if (!mounted) return;
              await _loadTemplateThumbnail(
                templateKey,
                widthDots,
                heightDots,
                previewDpi,
              );
            },
            onDelete: () async {
              Navigator.pop(context);
              final confirmed = await _showDeleteConfirmation(templateName);
              if (confirmed) {
                await _deleteTemplate(templateKey);
              }
            },
          ),
    );
  }

  Future<SystemStatus?> _printTemplate(
    String templateName,
    String templateKey,
    int quantity,
    int widthDots,
    int heightDots,
  ) async {
    print('=== PRINTING $templateName ===');

    final messenger = ScaffoldMessenger.of(context);

    try {
      if (!_zebraService.isConnected) {
        print('ERROR: Not connected to printer');
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Not connected to printer'),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }

      final templateContent = _templates[templateKey]!;
      final trimmedContent = templateContent.trim();

      String zplCommand;

      // Check if template is already complete ZPL (from LabelZoom API)
      if (trimmedContent.startsWith('^XA') && trimmedContent.endsWith('^XZ')) {
        // Insert ^PQ before the final ^XZ for quantity
        if (quantity > 1) {
          zplCommand =
              trimmedContent.substring(0, trimmedContent.length - 3) +
              '^PQ$quantity\n^XZ';
        } else {
          zplCommand = trimmedContent;
        }
        print('Template is complete ZPL, using as-is');
      } else {
        // Wrap raw ZPL content with proper commands
        zplCommand = '''
^XA
^PW$widthDots
^LL$heightDots

$templateContent

^PQ$quantity
^XZ
''';
        print('Template is raw ZPL, wrapping with ^XA/^XZ');
      }

      print('Sending ZPL:');
      print('  Template: $templateName');
      print('  Quantity: $quantity');
      print('  Width: $widthDots dots');
      print('  Height: $heightDots dots');

      await _zebraService.printZpl(zplCommand);

      print('Print command sent successfully!');

      // Small delay to let printer process the command
      await Future.delayed(const Duration(milliseconds: 1000));

      // Check system status after printing
      print('Checking system status after print...');
      try {
        final status = await _zebraService.getSystemStatus();
        print(
          'Post-print status - Errors: ${status.hasErrors}, Warnings: ${status.hasWarnings}',
        );
        return status;
      } catch (e) {
        print('Error checking system status: $e');
        return null;
      }
    } catch (e, stackTrace) {
      print('ERROR during print: $e');
      print('Stack trace: $stackTrace');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return null;
    } finally {
      print('=== PRINT FINISHED ===');
    }
  }
}

//  Template Preview Dialog Widget (add onZplChanged callback)
class _TemplatePreviewDialog extends StatefulWidget {
  final String templateKey;
  final String templateName;
  final String templateZpl;
  final int widthDots;
  final int heightDots;
  final int printerDpi;
  final bool isNewTemplate;
  final Future<SystemStatus?> Function(int quantity) onPrint;
  final Function(String newName) onNameChanged;
  final Function(String newZpl) onZplChanged;
  final VoidCallback onDelete;

  const _TemplatePreviewDialog({
    required this.templateKey,
    required this.templateName,
    required this.templateZpl,
    required this.widthDots,
    required this.heightDots,
    required this.printerDpi,
    this.isNewTemplate = false,
    required this.onPrint,
    required this.onNameChanged,
    required this.onZplChanged,
    required this.onDelete,
  });

  @override
  State<_TemplatePreviewDialog> createState() => _TemplatePreviewDialogState();
}

class _TemplatePreviewDialogState extends State<_TemplatePreviewDialog> {
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  late TextEditingController _nameController;
  late TextEditingController _zplController;
  late String _currentTemplateName;
  int _quantity = 1;
  bool _isValidQuantity = true;
  bool _isEditingName = false;
  bool _isLoadingPreview = true;
  String? _previewError;
  Uint8List? _previewImageBytes;
  bool _hasUnsavedZplChanges = false;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _currentTemplateName = widget.templateName;
    _nameController = TextEditingController(text: widget.templateName);
    _zplController = TextEditingController(text: widget.templateZpl);

    _zplController.addListener(_onZplChanged);

    _loadLabelPreview();

    // Auto-open ZPL editor for new templates
    if (widget.isNewTemplate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openZplEditor();
      });
    }
  }

  void _onZplChanged() {
    // Only call setState if the value actually changed
    final hasChanges = _zplController.text != widget.templateZpl;
    if (hasChanges != _hasUnsavedZplChanges) {
      setState(() => _hasUnsavedZplChanges = hasChanges);
    }
  }

  @override
  void dispose() {
    _zplController.removeListener(_onZplChanged);
    _quantityController.dispose();
    _nameController.dispose();
    _zplController.dispose();
    super.dispose();
  }

  Future<void> _loadLabelPreview() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPreview = true;
      _previewError = null;
    });

    try {
      final widthInches = widget.widthDots / widget.printerDpi;
      final heightInches = widget.heightDots / widget.printerDpi;

      String dpmm;
      if (widget.printerDpi >= 580) {
        dpmm = '24dpmm';
      } else if (widget.printerDpi >= 280) {
        dpmm = '12dpmm';
      } else if (widget.printerDpi >= 180) {
        dpmm = '8dpmm';
      } else {
        dpmm = '6dpmm';
      }

      final fullZpl = '''
^XA
^PW${widget.widthDots}
^LL${widget.heightDots}

${_zplController.text}

^XZ
''';

      print('Requesting label preview from Labelary API');
      print('  DPMM: $dpmm');
      print(
        '  Dimensions: ${widthInches.toStringAsFixed(2)}" × ${heightInches.toStringAsFixed(2)}"',
      );
      print('  ZPL length: ${fullZpl.length} characters');

      final url = Uri.parse(
        'http://api.labelary.com/v1/printers/$dpmm/labels/${widthInches.toStringAsFixed(1)}x${heightInches.toStringAsFixed(1)}/0/',
      );

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'image/png',
            },
            body: fullZpl,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Request timeout - Labelary API took too long to respond',
              );
            },
          );

      if (!mounted) return;

      if (response.statusCode == 200) {
        print(
          'Successfully received preview image (${response.bodyBytes.length} bytes)',
        );
        setState(() {
          _previewImageBytes = response.bodyBytes;
          _isLoadingPreview = false;
          _hasUnsavedZplChanges = false;
        });
      } else {
        final errorMessage = response.body;
        print('Labelary API error (${response.statusCode}): $errorMessage');
        setState(() {
          _previewError =
              'Failed to generate preview (HTTP ${response.statusCode})';
          _isLoadingPreview = false;
        });
      }
    } catch (e) {
      print('Error loading label preview: $e');
      if (!mounted) return;
      setState(() {
        _previewError = 'Failed to load preview: ${e.toString()}';
        _isLoadingPreview = false;
      });
    }
  }

  Future<void> _saveName() async {
    if (_nameController.text.trim().isEmpty) {
      _nameController.text = _currentTemplateName;
      if (!mounted) return;
      setState(() => _isEditingName = false);
      return;
    }

    final newName = _nameController.text.trim();
    await widget.onNameChanged(newName);
    if (!mounted) return;
    setState(() {
      _currentTemplateName = newName;
      _isEditingName = false;
    });
  }

  // Open full-screen ZPL editor
  void _openZplEditor() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (context) => _ZplEditorScreen(
              controller: _zplController,
              templateName: widget.templateName,
            ),
      ),
    );

    // If user saved changes, reload preview and update template
    if (!mounted) return;
    if (result == true && _hasUnsavedZplChanges) {
      await widget.onZplChanged(_zplController.text); // Save ZPL changes
      // Wait for rate limit before loading preview (thumbnail already loading)
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      _loadLabelPreview();
    }
  }

  // Handle print and check status
  Future<void> _handlePrint() async {
    if (!_isValidQuantity || _isPrinting) return;

    setState(() => _isPrinting = true);

    try {
      final status = await widget.onPrint(_quantity);

      if (!mounted) return;

      setState(() => _isPrinting = false);

      // Check if there are errors and show dialog
      if (status != null && status.hasErrors) {
        _showPrintErrorDialog(status);
      } else {
        // Show success message
        /*
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully sent $_quantity label(s) to printer!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
*/
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPrinting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Show error dialog similar to printer_dashboard
  void _showPrintErrorDialog(SystemStatus status) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  status.hasErrors ? Icons.error : Icons.warning,
                  color: status.hasErrors ? Colors.red : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Print Status', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (status.errors.isNotEmpty) ...[
                    const Text(
                      'Errors:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...status.errors.map(
                      (error) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 16,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(error)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (status.warnings.isNotEmpty) ...[
                    const Text(
                      'Warnings:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...status.warnings.map(
                      (warning) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(warning)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final widthInches = widget.widthDots / widget.printerDpi;
    final heightInches = widget.heightDots / widget.printerDpi;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with editable name
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F8),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Editable template name
                        _isEditingName
                            ? Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    cursorColor: Colors.black,
                                    controller: _nameController,
                                    autofocus: true,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.black,
                                        ),
                                      ),
                                      border: OutlineInputBorder(),
                                    ),
                                    onSubmitted: (_) => _saveName(),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check, size: 20),
                                  onPressed: _saveName,
                                  tooltip: 'Save',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () {
                                    _nameController.text = _currentTemplateName;
                                    setState(() => _isEditingName = false);
                                  },
                                  tooltip: 'Cancel',
                                ),
                              ],
                            )
                            : Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _currentTemplateName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () {
                                    setState(() => _isEditingName = true);
                                  },
                                  tooltip: 'Edit name',
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                        const SizedBox(height: 4),
                        Text(
                          '${widthInches.toStringAsFixed(2)}" × ${heightInches.toStringAsFixed(2)}"',
                          style: TextStyle(fontSize: 12, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                  // Only show dialog close button when not editing name
                  if (!_isEditingName)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
            ),

            // Action buttons row (Edit ZPL and Delete)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Edit ZPL Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openZplEditor,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.code, size: 18),
                      label: const Text('Edit ZPL Code'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Delete Button
                  OutlinedButton(
                    onPressed: widget.onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                    child: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ),
            ),

            // Preview Area
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white),
                  //borderRadius: BorderRadius.circular(8),
                  //color: Colors.black,
                ),
                child: _buildPreviewArea(),
              ),
            ),

            // Quantity and Print Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F8),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                //border: Border(top: BorderSide(color: Colors.grey)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Print Quantity:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          cursorColor: Colors.black,
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color:
                                    _isValidQuantity
                                        ? Colors.black
                                        : Colors.red,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color:
                                    _isValidQuantity
                                        ? Colors.black
                                        : Colors.red,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color:
                                    _isValidQuantity
                                        ? Colors.black
                                        : Colors.red,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            errorText: !_isValidQuantity ? 'Min 1' : null,
                            errorStyle: const TextStyle(fontSize: 10),
                          ),
                          onChanged: (value) {
                            if (value.isEmpty) {
                              if (_isValidQuantity != false || _quantity != 0) {
                                setState(() {
                                  _isValidQuantity = false;
                                  _quantity = 0;
                                });
                              }
                              return;
                            }

                            final qty = int.tryParse(value);

                            if (qty == null || qty < 1) {
                              final newQty = qty ?? 0;
                              if (_isValidQuantity != false ||
                                  _quantity != newQty) {
                                setState(() {
                                  _isValidQuantity = false;
                                  _quantity = newQty;
                                });
                              }
                            } else if (qty > 999) {
                              if (_isValidQuantity != true ||
                                  _quantity != 999) {
                                setState(() {
                                  _isValidQuantity = true;
                                  _quantity = 999;
                                  _quantityController.text = '999';
                                  _quantityController
                                      .selection = TextSelection.fromPosition(
                                    TextPosition(
                                      offset: _quantityController.text.length,
                                    ),
                                  );
                                });
                              }
                            } else {
                              if (_isValidQuantity != true ||
                                  _quantity != qty) {
                                setState(() {
                                  _isValidQuantity = true;
                                  _quantity = qty;
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          (_isValidQuantity && !_isPrinting)
                              ? Colors.black
                              : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: (_isValidQuantity && !_isPrinting) ? 2 : 0,
                    ),
                    onPressed:
                        (_isValidQuantity && !_isPrinting)
                            ? _handlePrint
                            : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isPrinting)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        else
                          Icon(
                            Icons.print,
                            size: 20,
                            color:
                                _isValidQuantity ? Colors.white : Colors.grey,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _isPrinting ? 'Printing...' : 'Print Label',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                (_isValidQuantity && !_isPrinting)
                                    ? Colors.white
                                    : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (_isLoadingPreview) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.black),
            SizedBox(height: 16),
            Text(
              'Loading preview...',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    if (_previewError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Preview Error',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _previewError!,
                style: TextStyle(fontSize: 12, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _loadLabelPreview,
                icon: const Icon(color: Colors.black, Icons.refresh),
                label: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_previewImageBytes != null) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.memory(_previewImageBytes!, fit: BoxFit.contain),
      );
    }

    return Center(
      child: Text(
        'No preview available',
        style: TextStyle(fontSize: 14, color: Colors.grey),
      ),
    );
  }
}

class _ZplEditorScreen extends StatefulWidget {
  final TextEditingController controller;
  final String templateName;

  const _ZplEditorScreen({
    required this.controller,
    required this.templateName,
  });

  @override
  State<_ZplEditorScreen> createState() => _ZplEditorScreenState();
}

class _ZplEditorScreenState extends State<_ZplEditorScreen> {
  late String _originalText;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _originalText = widget.controller.text;
    widget.controller.addListener(_checkForChanges);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_checkForChanges);
    super.dispose();
  }

  void _checkForChanges() {
    final hasChanges = widget.controller.text != _originalText;
    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        title: Text('Edit ${widget.templateName}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          TextButton.icon(
            onPressed:
                _hasChanges
                    ? () {
                      Navigator.pop(
                        context,
                        true,
                      ); // Return true = changes saved
                    }
                    : null,
            icon: const Icon(Icons.check),
            label: const Text('Done'),
            style: TextButton.styleFrom(
              foregroundColor: _hasChanges ? Colors.black : Colors.grey,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.black, height: 1.0),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          cursorColor: Colors.black,
          controller: widget.controller,
          maxLines: null,
          expands: true,
          autofocus: true,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black,
            height: 1.5,
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            hintText: 'Enter ZPL code here...',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
