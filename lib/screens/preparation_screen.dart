import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Screen showing preparation checklist before photo capture
class PreparationScreen extends StatefulWidget {
  final VoidCallback onReady;

  const PreparationScreen({super.key, required this.onReady});

  @override
  State<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends State<PreparationScreen> {
  final List<bool> _checklist = [false, false, false, false, false];

  List<Map<String, dynamic>> _items(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      {
        'icon': Icons.wb_sunny_outlined,
        'title': l10n.goodLighting,
        'subtitle': l10n.goodLightingDesc,
      },
      {
        'icon': Icons.water_drop_outlined,
        'title': l10n.cleanMouth,
        'subtitle': l10n.cleanMouthDesc,
      },
      {
        'icon': Icons.face_outlined,
        'title': l10n.removeLipProducts,
        'subtitle': l10n.removeLipProductsDesc,
      },
      {
        'icon': Icons.crop_free,
        'title': l10n.mirrorNearby,
        'subtitle': l10n.mirrorNearbyDesc,
      },
      {
        'icon': Icons.timer_outlined,
        'title': l10n.setAside2Minutes,
        'subtitle': l10n.screeningTakes60Seconds,
      },
    ];
  }

  bool get _allChecked => _checklist.every((item) => item);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = _items(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.beforeWeStart),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.checklist,
                              color: Colors.blue[700],
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.preparationChecklist,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.preparationSubtitle,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Checklist items
                    ...List.generate(items.length, (index) {
                      final item = items[index];
                      return _buildChecklistItem(
                        index: index,
                        icon: item['icon'] as IconData,
                        title: item['title'] as String,
                        subtitle: item['subtitle'] as String,
                      );
                    }),

                    const SizedBox(height: 24),

                    // Guided sequence (labels can be adjusted after capture)
                    Text(
                      l10n.preparationPhotoSequenceTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.preparationPhotoSequenceHint,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPhotoList(),
                  ],
                ),
              ),
            ),

            // Bottom button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (!_allChecked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Please confirm all items above',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _allChecked ? widget.onReady : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt),
                          const SizedBox(width: 8),
                          Text(
                            l10n.imReady,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildChecklistItem({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isChecked = _checklist[index];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _checklist[index] = !_checklist[index];
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isChecked ? Colors.green[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isChecked ? Colors.green : Colors.grey[300]!,
              width: isChecked ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isChecked
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isChecked ? Colors.green : Colors.grey[600],
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isChecked ? Colors.green[800] : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isChecked ? Colors.green : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isChecked ? Colors.green : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isChecked
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoList() {
    final photos = [
      {'icon': Icons.face, 'name': 'Front View'},
      {'icon': Icons.chevron_right, 'name': 'Right Cheek'},
      {'icon': Icons.chevron_left, 'name': 'Left Cheek'},
      {'icon': Icons.sentiment_satisfied, 'name': 'Tongue'},
      {'icon': Icons.keyboard_arrow_up, 'name': 'Palate'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: photos.map((photo) {
          return Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Icon(
                  photo['icon'] as IconData,
                  color: Colors.grey[700],
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                photo['name'] as String,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
