import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:home_care_admin/core/api_client.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final ImagePicker _picker = ImagePicker();

  final List<_DocItem> _documents = [
    _DocItem(
      title: 'Government ID',
      subtitle: 'Aadhaar Card / PAN Card',
      icon: Icons.badge_outlined,
    ),
    _DocItem(
      title: 'Address Proof',
      subtitle: 'Utility bill / Voter ID / Aadhaar',
      icon: Icons.home_outlined,
    ),
    _DocItem(
      title: 'Qualification Certificate',
      subtitle: 'Degree / Diploma certificate',
      icon: Icons.school_outlined,
    ),
    _DocItem(
      title: 'Experience Certificate',
      subtitle: 'Previous employer certificate',
      icon: Icons.work_outlined,
    ),
    _DocItem(
      title: 'Profile Photo',
      subtitle: 'Clear photo with white background',
      icon: Icons.person_outline,
    ),
  ];

  Future<void> _pickAndUpload(int index) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (file == null) return;

      setState(() {
        _documents[index].status = UploadStatus.uploading;
        _documents[index].localPath = file.path;
      });

      final url = await ApiClient.uploadFile(file.path);

      setState(() {
        _documents[index].status = UploadStatus.done;
        _documents[index].uploadedUrl = url;
      });

      Get.snackbar(
        'Uploaded',
        '${_documents[index].title} uploaded successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      setState(() {
        _documents[index].status = UploadStatus.failed;
      });
      Get.snackbar(
        'Upload Failed',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    }
  }

  int get _uploadedCount =>
      _documents.where((d) => d.status == UploadStatus.done).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Upload Documents'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verification Documents',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Upload documents to verify your credentials. Approved faster with complete documents.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _uploadedCount / _documents.length,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_uploadedCount / ${_documents.length} documents uploaded',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _documents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = _documents[index];
                return _DocumentCard(
                  doc: doc,
                  onTap: () => _pickAndUpload(index),
                  onRetry: () => _pickAndUpload(index),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                if (_uploadedCount == 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Color(0xFFD97706), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You can submit with 0 documents and add them later from your profile.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Get.offAllNamed('/verification'),
                    child: Text(
                      _uploadedCount > 0
                          ? 'Submit Documents ($_uploadedCount uploaded)'
                          : 'Skip for now',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
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

enum UploadStatus { idle, uploading, done, failed }

class _DocItem {
  final String title;
  final String subtitle;
  final IconData icon;
  UploadStatus status;
  String? localPath;
  String? uploadedUrl;

  _DocItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.status = UploadStatus.idle,
    this.localPath,
    this.uploadedUrl,
  });
}

class _DocumentCard extends StatelessWidget {
  final _DocItem doc;
  final VoidCallback onTap;
  final VoidCallback onRetry;

  const _DocumentCard({
    required this.doc,
    required this.onTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: doc.status == UploadStatus.done
              ? const Color(0xFF86EFAC)
              : doc.status == UploadStatus.failed
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: doc.status == UploadStatus.done
                ? const Color(0xFFDCFCE7)
                : doc.status == UploadStatus.failed
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: doc.localPath != null && doc.status == UploadStatus.done
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(doc.localPath!),
                    fit: BoxFit.cover,
                  ),
                )
              : Icon(
                  doc.status == UploadStatus.done
                      ? Icons.check_circle_rounded
                      : doc.status == UploadStatus.failed
                          ? Icons.error_rounded
                          : doc.icon,
                  color: doc.status == UploadStatus.done
                      ? const Color(0xFF16A34A)
                      : doc.status == UploadStatus.failed
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF2563EB),
                  size: 26,
                ),
        ),
        title: Text(
          doc.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          doc.status == UploadStatus.done
              ? 'Uploaded successfully'
              : doc.status == UploadStatus.failed
                  ? 'Upload failed — tap to retry'
                  : doc.status == UploadStatus.uploading
                      ? 'Uploading...'
                      : doc.subtitle,
          style: TextStyle(
            fontSize: 12,
            color: doc.status == UploadStatus.done
                ? const Color(0xFF16A34A)
                : doc.status == UploadStatus.failed
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF64748B),
          ),
        ),
        trailing: doc.status == UploadStatus.uploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF2563EB),
                ),
              )
            : GestureDetector(
                onTap: doc.status == UploadStatus.failed ? onRetry : onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: doc.status == UploadStatus.done
                        ? const Color(0xFFDCFCE7)
                        : doc.status == UploadStatus.failed
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    doc.status == UploadStatus.done
                        ? 'Change'
                        : doc.status == UploadStatus.failed
                            ? 'Retry'
                            : 'Upload',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: doc.status == UploadStatus.done
                          ? const Color(0xFF16A34A)
                          : doc.status == UploadStatus.failed
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
