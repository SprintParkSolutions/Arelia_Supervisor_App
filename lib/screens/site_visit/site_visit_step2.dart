import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import 'site_visit_step3.dart';

class SiteVisitStep2 extends StatefulWidget {
  const SiteVisitStep2({
    super.key,
    required this.reportId,
    required this.leadId,
    required this.supervisorId,
  });
  final String reportId;
  final String leadId;
  final String supervisorId;

  @override
  State<SiteVisitStep2> createState() => _SiteVisitStep2State();
}

class _SiteVisitStep2State extends State<SiteVisitStep2> {
  static const _gold = Color(0xFFBF7A16);
  File? selectedFile;
  bool loading = false;
  String fileName = '';
  int? fileSize;

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || !mounted) return;
    selectedFile = File(result.files.single.path!);
    setState(() {
      fileName = result.files.single.name;
      fileSize = result.files.single.size;
    });
  }

  Future<void> uploadFile() async {
    if (selectedFile == null) {
      _openPreview();
      return;
    }
    setState(() => loading = true);
    final success = await ApiService.uploadBlueprint(
      reportId: widget.reportId,
      file: selectedFile!,
    );
    if (!mounted) return;
    setState(() => loading = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blueprint upload failed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    _openPreview();
  }

  Future<void> _openPreview() async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SiteVisitStep3(
          leadId: widget.leadId,
          supervisorId: widget.supervisorId,
          blueprintFile: selectedFile,
          blueprintName: fileName.isEmpty ? null : fileName,
        ),
      ),
    );
    if (submitted == true && mounted) Navigator.pop(context, true);
  }

  String _sizeLabel() {
    if (fileSize == null) return '';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(0)} KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFFFCF8F2),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: !loading,
        child: Scaffold(
          backgroundColor: const Color(0xFFFCF8F2),
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/arelia_lead_details_background.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x08FFFFFF), Color(0xC8FCF8F2)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _header(),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                        children: [
                          const _StepProgress(activeStep: 2),
                          const SizedBox(height: 25),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: _cardDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: Color(0xFFF8EFE3),
                                      child: Icon(
                                        Icons.description_outlined,
                                        color: _gold,
                                        size: 26,
                                      ),
                                    ),
                                    SizedBox(width: 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Upload Layout Blueprint',
                                            style: TextStyle(
                                              fontFamily: 'serif',
                                              fontSize: 23,
                                              color: Color(0xFF2D241C),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Add blueprint or supporting layout files for this site visit.',
                                            style: TextStyle(
                                              color: Color(0xFF77716A),
                                              fontSize: 13,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                InkWell(
                                  onTap: pickFile,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 34,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0x66FFF9F1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0x77D49A46),
                                        width: 1.4,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.architecture_outlined,
                                          color: Color(0xFFD3A261),
                                          size: 70,
                                        ),
                                        const SizedBox(height: 16),
                                        OutlinedButton.icon(
                                          onPressed: pickFile,
                                          icon: const Icon(
                                            Icons.upload_file_outlined,
                                          ),
                                          label: Text(
                                            fileName.isEmpty
                                                ? 'Choose Blueprint (Optional)'
                                                : 'Change Blueprint',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _gold,
                                            minimumSize: const Size(220, 50),
                                            side: const BorderSide(
                                              color: _gold,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        const Text.rich(
                                          TextSpan(
                                            text: 'Tap to select a file, or ',
                                            children: [
                                              TextSpan(
                                                text: 'browse',
                                                style: TextStyle(color: _gold),
                                              ),
                                            ],
                                          ),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF7E7770),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'PDF, JPG, PNG up to 10 MB',
                                          style: TextStyle(
                                            color: Color(0xFF9B958E),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (fileName.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      color: const Color(0xAFFFFFFF),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0x44BF7A16),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const CircleAvatar(
                                          backgroundColor: Color(0xFFF7E9D4),
                                          child: Icon(
                                            Icons.picture_as_pdf_outlined,
                                            color: _gold,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                fileName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                'Ready to upload • ${_sizeLabel()}',
                                                style: const TextStyle(
                                                  color: Color(0xFF817A73),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.check_circle_outline,
                                          color: _gold,
                                        ),
                                        IconButton(
                                          onPressed: () => setState(() {
                                            selectedFile = null;
                                            fileName = '';
                                            fileSize = null;
                                          }),
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextButton(
                            onPressed: loading ? null : _openPreview,
                            child: const Text(
                              'Skip for now',
                              style: TextStyle(
                                color: _gold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _NextButton(loading: loading, onTap: uploadFile),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (loading) ...[
                const ModalBarrier(
                  dismissible: false,
                  color: Color(0x66000000),
                ),
                const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: _gold),
                          SizedBox(width: 16),
                          Text('Uploading blueprint…'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
    child: Row(
      children: [
        _SmallBack(onTap: () => Navigator.pop(context)),
        const Expanded(
          child: Text(
            'Site Visit Report',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 29,
              color: Color(0xFF251E18),
            ),
          ),
        ),
        const SizedBox(width: 50),
      ],
    ),
  );
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.activeStep});
  final int activeStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepDot(number: 1, activeStep: activeStep, label: 'Details'),
        const Expanded(child: Divider(color: Color(0xFFCA8B31))),
        _StepDot(number: 2, activeStep: activeStep, label: 'Upload'),
        const Expanded(child: Divider(color: Color(0xFFCA8B31))),
        _StepDot(number: 3, activeStep: activeStep, label: 'Preview'),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.number,
    required this.activeStep,
    required this.label,
  });
  final int number;
  final int activeStep;
  final String label;

  @override
  Widget build(BuildContext context) {
    final completed = number < activeStep;
    final active = number == activeStep;
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: completed || active
                ? const Color(0xFFC98522)
                : const Color(0xFFE4DED6),
            child: completed
                ? const Icon(Icons.check, color: Colors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: active ? Colors.white : const Color(0xFF77716A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFFB26D0B) : const Color(0xFF6F6861),
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBack extends StatelessWidget {
  const _SmallBack({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xEFFFFFFF),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x55BF7A16)),
        ),
        child: const Icon(Icons.arrow_back, color: Color(0xFFBF7A16)),
      ),
    ),
  );
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFE1A13A), Color(0xFFB96F0D)],
      ),
      borderRadius: BorderRadius.circular(17),
    ),
    child: ElevatedButton.icon(
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.3,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.arrow_forward_rounded),
      label: Text(
        loading ? 'Uploading...' : 'Next · Preview',
        style: const TextStyle(fontFamily: 'serif', fontSize: 20),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        shadowColor: Colors.transparent,
      ),
    ),
  );
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: const Color(0xEFFFFFFF),
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: const Color(0x44BF7A16)),
  boxShadow: const [
    BoxShadow(color: Color(0x116B4B20), blurRadius: 20, offset: Offset(0, 7)),
  ],
);
