import 'dart:convert';

import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/fikir_card.dart';
import 'package:fikir/core/design/widgets/gradient_button.dart';
import 'package:fikir/features/premium/data/premium_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrivacyPolicyScreen extends ConsumerStatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  ConsumerState<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends ConsumerState<PrivacyPolicyScreen> {
  bool _isExporting = false;

  Future<void> _handleDataExport() async {
    setState(() => _isExporting = true);
    final repo = ref.read(premiumRepositoryProvider);

    try {
      final export = await repo.exportUserData();
      if (!mounted) return;

      if (export != null) {
        final prettyJson = const JsonEncoder.withIndent('  ').convert(export);
        _showExportDialog(prettyJson);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load user export dossier')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showExportDialog(String jsonContent) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your Data Dossier (Proclamation 1321/2024)'),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonContent,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonContent));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dossier copied to clipboard')),
              );
            },
            child: const Text('Copy All'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Legal Guard', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Proclamation Badge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Proclamation No. 1321/2024 Compliant',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                      ),
                      Text(
                        'Federal Democratic Republic of Ethiopia Personal Data Protection Law',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Location Privacy & Anti-Triangulation
          const FikirCard(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: FikirColors.primaryCoral),
                    SizedBox(width: 8),
                    Text('Location Obfuscation Guarantee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• Your precise GPS coordinates (latitude & longitude) are NEVER broadcast or sent to any other user.',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  '• Distance is calculated server-side and rounded to the nearest integer kilometer.',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  '• A randomized jitter offset (200m–800m) is applied internally to prevent coordinate multilateration and triangulation attacks.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Data Retention & Deletion
          const FikirCard(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Text('Data Retention & Deletion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• When you delete your account, your profile and photos immediately disappear from discovery.',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  '• A 30-day quarantine retention window allows safety checks before irreversible, cascading deletion from storage.',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  '• Banned phone numbers and device fingerprints are quarantined to protect community members from repeat offenders.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Data Subject Rights: Export Data
          const Text('Your Data Rights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Under Proclamation No. 1321/2024, you have the right to receive an export of all personal data held by Fikir.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 14),
          GradientButton(
            isLoading: _isExporting,
            text: 'Download My Data (መረጃዬን አውርድ)',
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: _handleDataExport,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
