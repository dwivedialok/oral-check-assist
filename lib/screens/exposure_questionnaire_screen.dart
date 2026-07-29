import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../models/exposure_data.dart';
import '../providers/screening_provider.dart';
import '../services/eri_service.dart';

/// Tobacco exposure questionnaire shown concurrently with AI analysis.
class ExposureQuestionnaireScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const ExposureQuestionnaireScreen({super.key, required this.onComplete});

  @override
  State<ExposureQuestionnaireScreen> createState() =>
      _ExposureQuestionnaireScreenState();
}

class _ExposureQuestionnaireScreenState
    extends State<ExposureQuestionnaireScreen> {
  bool? _usesTobacco;
  bool _isProcessing = false;
  final Set<TobaccoType> _selectedTypes = {};
  DurationCategory? _selectedDuration;
  FrequencyCategory? _selectedFrequency;
  bool _showValidation = false;
  final TextEditingController _otherDescriptionController =
      TextEditingController();

  bool get _isOtherSelected => _selectedTypes.contains(TobaccoType.other);

  bool get _isFormValid =>
      _selectedTypes.isNotEmpty &&
      _selectedDuration != null &&
      _selectedFrequency != null &&
      (!_isOtherSelected || _otherDescriptionController.text.trim().isNotEmpty);

  void _submitNoTobacco() {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    // Defer actual processing so the loading state paints first.
    // ONNX inference on the main thread can block event dispatch; painting
    // the processing indicator before yielding ensures the user sees feedback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<ScreeningProvider>(context, listen: false);
      provider.setExposureData(const ExposureData.none());
      widget.onComplete();
    });
  }

  void _submitQuestionnaire() {
    setState(() => _showValidation = true);
    if (!_isFormValid) return;
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final eri = ERIService();
      final data = eri.computeExposureData(
        tobaccoTypes: _selectedTypes.toList(),
        duration: _selectedDuration,
        frequency: _selectedFrequency,
        otherDescription: _isOtherSelected
            ? _otherDescriptionController.text.trim()
            : null,
      );

      final provider = Provider.of<ScreeningProvider>(context, listen: false);
      provider.setExposureData(data);
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _otherDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(l10n.eriQuestionnaireTitle),
            centerTitle: true,
            elevation: 0,
            automaticallyImplyLeading: _usesTobacco != true,
            leading: _usesTobacco == true
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _isProcessing
                        ? null
                        : () => setState(() => _usesTobacco = null),
                  )
                : null,
          ),
          body: SafeArea(
            child: Column(
              children: [
                _buildAnalysisStatusBanner(),
                Expanded(
                  child: _usesTobacco == null
                      ? _buildGateQuestion()
                      : _usesTobacco!
                      ? _buildFullQuestionnaire()
                      : _buildGateQuestion(),
                ),
              ],
            ),
          ),
        ),
        if (_isProcessing) _buildProcessingOverlay(),
      ],
    );
  }

  Widget _buildAnalysisStatusBanner() {
    return Selector<ScreeningProvider, bool>(
      selector: (_, p) => p.isAnalyzing || p.isLoadingModels,
      builder: (context, isRunning, _) {
        if (!isRunning) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.blue[50],
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI analysis running in the background…',
                  style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.25),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[600]!),
              ),
              const SizedBox(height: 16),
              const Text(
                'Processing…',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Gate question
  // ---------------------------------------------------------------------------

  Widget _buildGateQuestion() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.orange[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.smoke_free, size: 40, color: Colors.orange[700]),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.eriGateQuestion,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.eriGateHelper,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : _submitNoTobacco,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(l10n.eriNo, style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => setState(() => _usesTobacco = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.eriYes,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Full questionnaire
  // ---------------------------------------------------------------------------

  Widget _buildFullQuestionnaire() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(l10n.eriTypeQuestion, l10n.eriSelectAll),
                const SizedBox(height: 12),
                _buildTobaccoTypeChips(),
                if (_isOtherSelected) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otherDescriptionController,
                    decoration: InputDecoration(
                      labelText: l10n.eriOtherSpecifyLabel,
                      hintText: l10n.eriOtherSpecifyHint,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_showValidation &&
                      _otherDescriptionController.text.trim().isEmpty)
                    _buildValidationError(l10n.eriOtherSpecifyError),
                ],
                if (_showValidation && _selectedTypes.isEmpty)
                  _buildValidationError(l10n.eriTypeRequiredError),
                const SizedBox(height: 28),
                _buildSectionHeader(l10n.eriDurationQuestion, null),
                const SizedBox(height: 12),
                _buildDurationSelector(),
                if (_showValidation && _selectedDuration == null)
                  _buildValidationError(l10n.eriDurationRequiredError),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  l10n.eriFrequencyQuestion,
                  l10n.eriFrequencyHelper,
                ),
                const SizedBox(height: 12),
                _buildFrequencySelector(),
                if (_showValidation && _selectedFrequency == null)
                  _buildValidationError(l10n.eriFrequencyRequiredError),
                const SizedBox(height: 24),
                _buildDisclaimer(),
              ],
            ),
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String? subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }

  Widget _buildTobaccoTypeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TobaccoType.values.map((type) {
        final selected = _selectedTypes.contains(type);
        return FilterChip(
          label: Text(type.localizedName(context)),
          selected: selected,
          onSelected: (val) {
            setState(() {
              if (val) {
                _selectedTypes.add(type);
              } else {
                _selectedTypes.remove(type);
              }
            });
          },
          selectedColor: Colors.orange[100],
          checkmarkColor: Colors.orange[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selected ? Colors.orange[400]! : Colors.grey[300]!,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      children: DurationCategory.values.map((d) {
        return RadioListTile<DurationCategory>(
          value: d,
          groupValue: _selectedDuration,
          onChanged: (val) => setState(() => _selectedDuration = val),
          title: Text(
            d.localizedName(context),
            style: const TextStyle(fontSize: 14),
          ),
          activeColor: Colors.orange[700],
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _buildFrequencySelector() {
    return Column(
      children: FrequencyCategory.values.map((f) {
        return RadioListTile<FrequencyCategory>(
          value: f,
          groupValue: _selectedFrequency,
          onChanged: (val) => setState(() => _selectedFrequency = val),
          title: Text(
            f.localizedName(context),
            style: const TextStyle(fontSize: 14),
          ),
          activeColor: Colors.orange[700],
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _buildValidationError(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: Colors.red[700]),
          const SizedBox(width: 4),
          Text(message, style: TextStyle(fontSize: 12, color: Colors.red[700])),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _submitQuestionnaire,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.continueButton,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _usesTobacco = null),
              child: Text(AppLocalizations.of(context)!.eriChangeAnswer),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey[600], size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.eriDisclaimer,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}
