import 'dart:io'
    if (dart.library.html) 'package:oral_cavity_classifier_app/io_stub.dart'
    as io;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../models/photo_capture.dart';
import '../providers/screening_provider.dart';
import '../widgets/camera_overlay.dart';
import '../widgets/quality_indicator.dart';

/// Screen for capturing individual photos in the screening session
class PhotoCaptureScreen extends StatefulWidget {
  final PhotoType photoType;
  final VoidCallback onPhotoCaptured;
  final VoidCallback? onSkip;

  const PhotoCaptureScreen({
    super.key,
    required this.photoType,
    required this.onPhotoCaptured,
    this.onSkip,
  });

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isCapturing = false;
  PhotoQualityMetrics _currentQuality = PhotoQualityMetrics.empty;
  io.File? _previewImage;

  /// On web, bytes for confirm/inference (stub File cannot be read).
  Uint8List? _previewImageBytes;

  /// On web, resized bytes for display (prevents WebGL errors).
  Uint8List? _displayImageBytes;

  /// Optional user-selected anatomical label for this slot. Null means "use
  /// slot default". Purely presentational — not passed into inference.
  OralPhotoLabel? _selectedLabel;

  /// Free-text paired with [OralPhotoLabel.custom]. Trimmed and bounded
  /// to [kMaxCustomLabelLength] when saved through the picker.
  String? _customLabelText;

  @override
  void initState() {
    super.initState();
    _loadExistingLabelForSlot();
  }

  @override
  void didUpdateWidget(PhotoCaptureScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoType != widget.photoType) {
      _previewImage = null;
      _previewImageBytes = null;
      _displayImageBytes = null;
      _currentQuality = PhotoQualityMetrics.empty;
      _loadExistingLabelForSlot();
    }
  }

  /// Load any previously-set label for this slot so retake preserves it (AC5).
  void _loadExistingLabelForSlot() {
    final provider = context.read<ScreeningProvider>();
    final existing = provider.currentSession?.getPhoto(widget.photoType);
    _selectedLabel = existing?.photoLabel;
    _customLabelText = existing?.customLabelText;
  }

  /// The label to show right now in the "Current View" row. Resolves null
  /// (no user override) to the slot default.
  OralPhotoLabel get _effectiveLabel =>
      _selectedLabel ?? widget.photoType.defaultLabel;

  String _effectiveLabelDisplay(AppLocalizations l10n) {
    final label = _effectiveLabel;
    if (label == OralPhotoLabel.custom) {
      final text = _customLabelText?.trim();
      if (text != null && text.isNotEmpty) return text;
      return widget.photoType.localizedNameL10n(l10n);
    }
    return label.localizedNameL10n(l10n);
  }

  bool get _isRequiredPhoto => widget.photoType == PhotoType.frontView;

  static const int _minCropDimension = 224;
  static const double _tightCropAreaRatioThreshold = 0.20;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ScreeningProvider>(context);
    final currentIndex = widget.photoType.captureOrder + 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                // Top bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  color: Colors.black,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => _showExitConfirmation(context),
                          ),
                          Text(
                            AppLocalizations.of(context)!.photoXOfY(
                              currentIndex,
                              _isRequiredPhoto
                                  ? AppLocalizations.of(context)!.requiredLabel
                                  : AppLocalizations.of(context)!.optionalLabel,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (widget.onSkip != null)
                            TextButton(
                              onPressed: () => widget.onSkip!(),
                              child: Text(
                                AppLocalizations.of(context)!.skip,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            )
                          else
                            const SizedBox(width: 48),
                        ],
                      ),
                      LinearProgressIndicator(
                        value: currentIndex / 5,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                // Photo area: tap to open full-screen zoom/rotate viewer
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _previewImage != null ||
                              (kIsWeb &&
                                  _displayImageBytes != null &&
                                  _displayImageBytes!.isNotEmpty)
                          ? GestureDetector(
                              onTap: () => _openFullScreenViewer(context),
                              child:
                                  kIsWeb &&
                                      _displayImageBytes != null &&
                                      _displayImageBytes!.isNotEmpty
                                  ? Image.memory(
                                      _displayImageBytes!,
                                      fit: BoxFit.contain,
                                      gaplessPlayback: true,
                                      filterQuality: FilterQuality.medium,
                                      errorBuilder: (context, error, stackTrace) {
                                        debugPrint(
                                          '❌ [Image] Failed to display image: $error',
                                        );
                                        debugPrint(
                                          '   Stack trace: $stackTrace',
                                        );
                                        return Container(
                                          color: Colors.grey[900],
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.error_outline,
                                                  color: Colors.red,
                                                  size: 48,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Failed to display image',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Image.file(
                                      _previewImage! as dynamic,
                                      fit: BoxFit.contain,
                                    ),
                            )
                          : Container(
                              color: Colors.grey[900],
                              child: const Center(
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                      IgnorePointer(
                        child: CameraOverlay(
                          photoType: widget.photoType,
                          isReady: _currentQuality.isAcceptable,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom panel: instructions, quality, buttons (does not cover photo)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.photoType.localizedName(context),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          widget.photoType.instruction(context),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_previewImage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: QualityIndicator(metrics: _currentQuality),
                        ),
                      if (_previewImage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildLabelOverrideRow(context),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCircleButton(
                            icon: Icons.photo_library,
                            label: AppLocalizations.of(context)!.gallery,
                            onTap: () => _pickFromGallery(provider),
                          ),
                          _buildCaptureButton(context, provider),
                          _buildCircleButton(
                            icon: Icons.lightbulb_outline,
                            label: AppLocalizations.of(context)!.tips,
                            onTap: () => _showTips(context),
                          ),
                        ],
                      ),
                      if (_previewImage != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _clearPreview,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: Text(AppLocalizations.of(context)!.retake),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _cropPreviewImage(provider),
                              icon: const Icon(Icons.crop, size: 18),
                              label: Text(
                                AppLocalizations.of(context)!.cropPhoto,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _currentQuality.isAcceptable
                                  ? () => _confirmPhoto(provider)
                                  : null,
                              icon: const Icon(Icons.check, size: 18),
                              label: Text(
                                AppLocalizations.of(context)!.usePhoto,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Loading overlay
            if (_isCapturing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildCaptureButton(BuildContext context, ScreeningProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _previewImage == null ? () => _capturePhoto(provider) : null,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _previewImage == null ? Colors.white : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _previewImage == null ? Colors.white : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _previewImage == null ? AppLocalizations.of(context)!.capture : '',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _capturePhoto(ScreeningProvider provider) async {
    debugPrint('📷 [Camera] Starting camera capture...');
    setState(() => _isCapturing = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: kIsWeb
            ? 1920
            : null, // Add maxWidth on web to prevent oversized images
      );

      if (image != null) {
        debugPrint('📷 [Camera] Image captured: ${image.path}');
        final file = io.File(image.path);
        final bytes = await image.readAsBytes();
        debugPrint('📷 [Camera] Read ${bytes.length} bytes');

        // Validate bytes on web
        if (kIsWeb && (bytes.isEmpty || bytes.length < 100)) {
          debugPrint('❌ [Camera] Invalid image bytes: ${bytes.length} bytes');
          setState(() => _isCapturing = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(
                    context,
                  )!.failedToCapture('Invalid image data'),
                ),
              ),
            );
          }
          return;
        }

        final quality = kIsWeb
            ? await provider.assessQualityFromBytes(bytes)
            : await provider.assessQuality(file);

        debugPrint(
          '📷 [Camera] Quality assessed: ${(quality.overall * 100).toStringAsFixed(1)}% (acceptable: ${quality.isAcceptable})',
        );

        final displayBytes = kIsWeb
            ? _prepareDisplayBytes(bytes, 'Camera')
            : null;

        setState(() {
          _previewImage = file;
          _previewImageBytes = kIsWeb
              ? bytes
              : null; // Keep original for inference
          _displayImageBytes = kIsWeb
              ? displayBytes
              : null; // Use resized for display
          _currentQuality = quality;
          _isCapturing = false;
        });

        debugPrint(
          '📷 [Camera] Preview updated - has preview: ${_previewImage != null}, has bytes: ${_previewImageBytes != null}, has display: ${_displayImageBytes != null}',
        );
      } else {
        debugPrint('📷 [Camera] No image captured (user cancelled)');
        setState(() => _isCapturing = false);
      }
    } catch (e, st) {
      debugPrint('❌ [Camera] Error capturing image: $e');
      debugPrint('   Stack trace: $st');
      setState(() => _isCapturing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToCapture(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery(ScreeningProvider provider) async {
    debugPrint('📷 [Gallery] Starting gallery pick...');
    setState(() => _isCapturing = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1920,
      );

      if (image != null) {
        debugPrint('📷 [Gallery] Image selected: ${image.path}');
        final file = io.File(image.path);
        final bytes = await image.readAsBytes();
        debugPrint('📷 [Gallery] Read ${bytes.length} bytes');

        final quality = kIsWeb
            ? await provider.assessQualityFromBytes(bytes)
            : await provider.assessQuality(file);

        debugPrint(
          '📷 [Gallery] Quality assessed: ${(quality.overall * 100).toStringAsFixed(1)}% (acceptable: ${quality.isAcceptable})',
        );

        final displayBytes = kIsWeb
            ? _prepareDisplayBytes(bytes, 'Gallery')
            : null;

        setState(() {
          _previewImage = file;
          _previewImageBytes = kIsWeb
              ? bytes
              : null; // Keep original for inference
          _displayImageBytes = kIsWeb
              ? displayBytes
              : null; // Use resized for display
          _currentQuality = quality;
          _isCapturing = false;
        });

        debugPrint(
          '📷 [Gallery] Preview updated - has preview: ${_previewImage != null}, has bytes: ${_previewImageBytes != null}, has display: ${_displayImageBytes != null}',
        );
      } else {
        debugPrint('📷 [Gallery] No image selected');
        setState(() => _isCapturing = false);
      }
    } catch (e, st) {
      debugPrint('❌ [Gallery] Error picking image: $e');
      debugPrint('   Stack trace: $st');
      setState(() => _isCapturing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToPickImage(e.toString()),
            ),
          ),
        );
      }
    }
  }

  void _clearPreview() {
    debugPrint('🔄 [Preview] Clearing preview');
    setState(() {
      _previewImage = null;
      _previewImageBytes = null;
      _displayImageBytes = null;
      _currentQuality = PhotoQualityMetrics.empty;
    });
  }

  Uint8List _prepareDisplayBytes(Uint8List bytes, String source) {
    if (!kIsWeb) return bytes;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      debugPrint(
        '📷 [$source] Decoded image: ${decoded.width}x${decoded.height}',
      );
      const maxDisplaySize = 1920;
      img.Image resized = decoded;
      if (decoded.width > maxDisplaySize || decoded.height > maxDisplaySize) {
        final ratio = decoded.width > decoded.height
            ? maxDisplaySize / decoded.width
            : maxDisplaySize / decoded.height;
        resized = img.copyResize(
          decoded,
          width: (decoded.width * ratio).round(),
          height: (decoded.height * ratio).round(),
        );
        debugPrint(
          '📷 [$source] Resized for display: ${resized.width}x${resized.height}',
        );
      }
      return Uint8List.fromList(img.encodePng(resized));
    } catch (e) {
      debugPrint('❌ [$source] Failed to resize image for display: $e');
      return bytes;
    }
  }

  Future<void> _cropPreviewImage(ScreeningProvider provider) async {
    if (_previewImage == null) return;
    setState(() => _isCapturing = true);

    try {
      final l10n = AppLocalizations.of(context)!;
      final beforeBytes = kIsWeb && _previewImageBytes != null
          ? _previewImageBytes!
          : await _previewImage!.readAsBytes();
      if (!mounted) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: _previewImage!.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 95,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: l10n.cropImageTitle,
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            hideBottomControls: false,
            lockAspectRatio: false,
            initAspectRatio: CropAspectRatioPreset.original,
          ),
          IOSUiSettings(
            title: l10n.cropImageTitle,
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
            resetButtonHidden: false,
            aspectRatioLockEnabled: false,
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 520, height: 520),
            // mode_1 keeps the crop box inside the image canvas.
            viewwMode: WebViewMode.mode_1,
            // Default web drag mode is `crop` (draw / resize crop box). `move`
            // only pans the image and hides the usual “select region” behavior.
            dragMode: WebDragMode.crop,
            minCropBoxHeight: _minCropDimension.toDouble(),
            minCropBoxWidth: _minCropDimension.toDouble(),
            zoomable: true,
            rotatable: true,
            scalable: true,
            cropBoxMovable: true,
            cropBoxResizable: true,
            guides: true,
            highlight: true,
            modal: true,
          ),
        ],
      );

      if (cropped == null) {
        setState(() => _isCapturing = false);
        return;
      }

      final croppedBytes = await cropped.readAsBytes();
      final cropGuard = _evaluateCropGuardrails(beforeBytes, croppedBytes);

      if (cropGuard.tooSmall) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.cropTooSmall(_minCropDimension)),
              backgroundColor: Colors.orange[800],
            ),
          );
        }
        setState(() => _isCapturing = false);
        return;
      }

      if (cropGuard.tightAreaWarning && mounted) {
        final percent = (cropGuard.areaRatio * 100)
            .clamp(0, 100)
            .toStringAsFixed(0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.cropTightWarning(percent)),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      final editedFile = io.File(cropped.path);
      final quality = kIsWeb
          ? await provider.assessQualityFromBytes(croppedBytes)
          : await provider.assessQuality(editedFile);

      final displayBytes = kIsWeb
          ? _prepareDisplayBytes(croppedBytes, 'Crop')
          : null;

      setState(() {
        _previewImage = editedFile;
        _previewImageBytes = kIsWeb ? croppedBytes : null;
        _displayImageBytes = kIsWeb ? displayBytes : null;
        _currentQuality = quality;
      });

      if (!quality.isAcceptable && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.croppedPhotoNeedsRetake),
            backgroundColor: Colors.orange[800],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToCropImage(e.toString()),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  _CropGuardResult _evaluateCropGuardrails(
    Uint8List beforeBytes,
    Uint8List afterBytes,
  ) {
    final before = img.decodeImage(beforeBytes);
    final after = img.decodeImage(afterBytes);
    if (after == null) {
      return const _CropGuardResult(
        tooSmall: true,
        tightAreaWarning: false,
        areaRatio: 0,
      );
    }

    final tooSmall =
        after.width < _minCropDimension || after.height < _minCropDimension;

    double areaRatio = 1.0;
    if (before != null && before.width > 0 && before.height > 0) {
      areaRatio = (after.width * after.height) / (before.width * before.height);
    }

    return _CropGuardResult(
      tooSmall: tooSmall,
      tightAreaWarning: areaRatio < _tightCropAreaRatioThreshold,
      areaRatio: areaRatio,
    );
  }

  Future<void> _confirmPhoto(ScreeningProvider provider) async {
    if (_previewImage == null) return;

    setState(() => _isCapturing = true);

    try {
      // Display-only label fields are forwarded alongside the image. The
      // provider stores them on the PhotoCapture; they are NOT passed into
      // inference.
      final labelForProvider = _selectedLabel;
      final customTextForProvider = _selectedLabel == OralPhotoLabel.custom
          ? _customLabelText?.trim()
          : null;

      if (kIsWeb && _previewImageBytes != null) {
        await provider.capturePhoto(
          widget.photoType,
          _previewImage!,
          knownQuality: _currentQuality,
          imageBytes: _previewImageBytes,
          label: labelForProvider,
          customLabelText: customTextForProvider,
        );
      } else {
        await provider.capturePhoto(
          widget.photoType,
          _previewImage!,
          knownQuality: _currentQuality,
          label: labelForProvider,
          customLabelText: customTextForProvider,
        );
      }
      widget.onPhotoCaptured();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToSavePhoto(e.toString()),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  /// Compact label row shown on the preview/confirm step.
  ///
  /// Pattern: "Current View: Tongue   [ Change ]". Tapping Change opens a
  /// bottom-sheet picker with 6 options (5 presets + Custom with text
  /// input). Selection is held in local state and forwarded into
  /// [_confirmPhoto].
  Widget _buildLabelOverrideRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = _effectiveLabelDisplay(l10n);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.label_outline, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.photoLabelCurrentView,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _openLabelPicker,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(l10n.photoLabelChange),
          ),
        ],
      ),
    );
  }

  Future<void> _openLabelPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showModalBottomSheet<_LabelPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PhotoLabelPickerSheet(
        initialLabel: _effectiveLabel,
        initialCustomText: _customLabelText,
        slotDefault: widget.photoType.defaultLabel,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedLabel = result.label;
      _customLabelText = result.customText;
    });
    // Micro-confirmation so the user sees the label changed.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${l10n.photoLabelCurrentView}: ${_effectiveLabelDisplay(l10n)}',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showTips(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(
                    context,
                  )!.tipsForPhotoType(widget.photoType.localizedName(context)),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._getTipsForPhotoType(context).map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tip)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.gotIt),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getTipsForPhotoType(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.photoType) {
      case PhotoType.frontView:
        return [
          l10n.tipFrontView1,
          l10n.tipFrontView2,
          l10n.tipFrontView3,
          l10n.tipFrontView4,
        ];
      case PhotoType.rightCheek:
        return [
          l10n.tipRightCheek1,
          l10n.tipRightCheek2,
          l10n.tipRightCheek3,
          l10n.tipRightCheek4,
        ];
      case PhotoType.leftCheek:
        return [
          l10n.tipLeftCheek1,
          l10n.tipLeftCheek2,
          l10n.tipLeftCheek3,
          l10n.tipLeftCheek4,
        ];
      case PhotoType.tongue:
        return [
          l10n.tipTongue1,
          l10n.tipTongue2,
          l10n.tipTongue3,
          l10n.tipTongue4,
        ];
      case PhotoType.palate:
        return [
          l10n.tipPalate1,
          l10n.tipPalate2,
          l10n.tipPalate3,
          l10n.tipPalate4,
        ];
    }
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.exitCheck),
        content: Text(AppLocalizations.of(context)!.exitCheckMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.continueButton),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.exit),
          ),
        ],
      ),
    );
  }

  void _openFullScreenViewer(BuildContext context) {
    if (_previewImage == null &&
        (kIsWeb
            ? (_displayImageBytes == null && _previewImageBytes == null)
            : true)) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => _PhotoFullScreenViewer(
          file: _previewImage,
          imageBytes: kIsWeb
              ? (_displayImageBytes ?? _previewImageBytes)
              : _previewImageBytes,
        ),
      ),
    );
  }
}

/// Full-screen photo viewer with zoom (pinch) and rotate.
class _PhotoFullScreenViewer extends StatefulWidget {
  final io.File? file;
  final Uint8List? imageBytes;

  const _PhotoFullScreenViewer({this.file, this.imageBytes});

  @override
  State<_PhotoFullScreenViewer> createState() => _PhotoFullScreenViewerState();
}

class _CropGuardResult {
  final bool tooSmall;
  final bool tightAreaWarning;
  final double areaRatio;

  const _CropGuardResult({
    required this.tooSmall,
    required this.tightAreaWarning,
    required this.areaRatio,
  });
}

/// Result returned by [_PhotoLabelPickerSheet]. Null [label] means "revert
/// to slot default"; [customText] is only meaningful when
/// [label] == [OralPhotoLabel.custom].
class _LabelPickerResult {
  final OralPhotoLabel? label;
  final String? customText;
  const _LabelPickerResult({required this.label, this.customText});
}

/// Bottom-sheet picker with 6 options: the 5 canonical presets plus a
/// Custom option that reveals a single-line text field.
class _PhotoLabelPickerSheet extends StatefulWidget {
  final OralPhotoLabel initialLabel;
  final String? initialCustomText;
  final OralPhotoLabel slotDefault;

  const _PhotoLabelPickerSheet({
    required this.initialLabel,
    required this.initialCustomText,
    required this.slotDefault,
  });

  @override
  State<_PhotoLabelPickerSheet> createState() => _PhotoLabelPickerSheetState();
}

class _PhotoLabelPickerSheetState extends State<_PhotoLabelPickerSheet> {
  late OralPhotoLabel _selected;
  late TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLabel;
    _customController = TextEditingController(
      text: widget.initialCustomText ?? '',
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  bool get _customInvalid =>
      _selected == OralPhotoLabel.custom &&
      _customController.text.trim().isEmpty;

  void _onSave() {
    final trimmed = _customController.text.trim();
    if (_selected == OralPhotoLabel.custom && trimmed.isEmpty) return;

    // Null = "revert to slot default" so PhotoCapture.photoLabel stays
    // null and legacy/default behavior is preserved for that slot.
    final OralPhotoLabel? resolved = _selected == widget.slotDefault
        ? null
        : _selected;
    final String? customText = _selected == OralPhotoLabel.custom
        ? trimmed
        : null;

    Navigator.of(
      context,
    ).pop(_LabelPickerResult(label: resolved, customText: customText));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + mq.viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.photoLabelPickerTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.photoLabelPickerHelper,
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...OralPhotoLabel.values.map((label) {
            final isSelected = _selected == label;
            final title = label.localizedNameL10n(l10n);
            return RadioListTile<OralPhotoLabel>(
              value: label,
              // ignore: deprecated_member_use
              groupValue: _selected,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              // ignore: deprecated_member_use
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selected = v);
              },
            );
          }),
          if (_selected == OralPhotoLabel.custom) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customController,
              autofocus: true,
              maxLength: kMaxCustomLabelLength,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: l10n.photoLabelCustomHint,
                errorText: _customInvalid ? l10n.photoLabelCustomEmpty : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (!_customInvalid) _onSave();
              },
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _customInvalid ? null : _onSave,
              child: Text(l10n.photoLabelSave),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _PhotoFullScreenViewerState extends State<_PhotoFullScreenViewer> {
  double _rotationRad = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Transform.rotate(
                angle: _rotationRad,
                child: kIsWeb && widget.imageBytes != null
                    ? Image.memory(widget.imageBytes!, fit: BoxFit.contain)
                    : Image.file(widget.file! as dynamic, fit: BoxFit.contain),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.rotate_right, color: Colors.white),
                      tooltip: AppLocalizations.of(context)!.rotate90,
                      onPressed: () {
                        setState(() => _rotationRad += math.pi / 2);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: AppLocalizations.of(context)!.close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    AppLocalizations.of(context)!.pinchToZoom,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
