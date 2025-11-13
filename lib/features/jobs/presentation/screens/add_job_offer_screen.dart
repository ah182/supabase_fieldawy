import 'package:easy_localization/easy_localization.dart';
// ignore: unused_import
import 'package:fieldawy_store/features/jobs/application/job_offers_provider.dart';
import 'package:fieldawy_store/features/jobs/data/job_offers_repository.dart';
import 'package:fieldawy_store/features/jobs/domain/job_offer_model.dart';
import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class AddJobOfferScreen extends ConsumerStatefulWidget {
  const AddJobOfferScreen({super.key, this.jobToEdit});

  final JobOffer? jobToEdit;

  @override
  ConsumerState<AddJobOfferScreen> createState() => _AddJobOfferScreenState();
}

class _AddJobOfferScreenState extends ConsumerState<AddJobOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  
  int _wordCount = 0;
  bool _isSubmitting = false;
  String _completePhoneNumber = '';

  bool get _isEditing => widget.jobToEdit != null;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_updateWordCount);
    
    if (_isEditing) {
      _titleController.text = widget.jobToEdit!.title;
      _descriptionController.text = widget.jobToEdit!.description;
      final phone = widget.jobToEdit!.phone;
      // Extract the national number from the full phone (remove country code)
      if (phone.startsWith('+20')) {
        _phoneController.text = phone.substring(3); // Remove +20
      } else if (phone.startsWith('20')) {
        _phoneController.text = phone.substring(2); // Remove 20
      } else {
        _phoneController.text = phone;
      }
      _completePhoneNumber = widget.jobToEdit!.phone;
      _updateWordCount();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _updateWordCount() {
    final text = _descriptionController.text.trim();
    if (text.isEmpty) {
      setState(() => _wordCount = 0);
      return;
    }
    final words = text.split(RegExp(r'\s+'));
    setState(() => _wordCount = words.length);
  }

  Future<void> _submitJobOffer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(jobOffersRepositoryProvider);
      
      if (_isEditing) {
        await repository.updateJobOffer(
          jobId: widget.jobToEdit!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          phone: _completePhoneNumber,
        );
      } else {
        await repository.createJobOffer(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          phone: _completePhoneNumber,
        );
      }

      if (mounted) {
        setState(() => _isSubmitting = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'jobOfferUpdated'.tr() : 'jobOfferSubmitted'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'editJobOffer'.tr() : 'addJobOffer'.tr()),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'jobOfferInfo'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'jobTitle'.tr(),
                hintText: 'jobTitleHint'.tr(),
                prefixIcon: const Icon(Icons.work_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'jobTitleRequired'.tr();
                }
                if (value.trim().length < 10) {
                  return 'jobTitleTooShort'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            
            TextFormField(
              controller: _descriptionController,
              maxLines: 8,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'jobDescription'.tr(),
                hintText: 'jobDescriptionHint'.tr(),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 120),
                  child: Icon(Icons.description_outlined),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                helperText: '$_wordCount / 100 ${'words'.tr()}',
                helperStyle: TextStyle(
                  color: _wordCount > 100 ? Colors.red : Colors.grey[600],
                  fontWeight: _wordCount > 100 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'jobDescriptionRequired'.tr();
                }
                if (_wordCount < 20) {
                  return 'jobDescriptionTooShort'.tr();
                }
                if (_wordCount > 100) {
                  return 'jobDescriptionTooLong'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            
            IntlPhoneField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'phoneNumber'.tr(),
                hintText: 'phoneNumberHint'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              initialCountryCode: 'EG',
              languageCode: context.locale.languageCode,
              disableLengthCheck: false,
              onChanged: (phone) {
                setState(() {
                  _completePhoneNumber = phone.completeNumber;
                });
              },
              validator: (phone) {
                if (phone == null || phone.number.isEmpty) {
                  return 'phoneNumberRequired'.tr();
                }
                return null;
              },
              invalidNumberMessage: 'phoneNumberInvalid'.tr(),
              dropdownIconPosition: IconPosition.trailing,
              showCountryFlag: true,
              showDropdownIcon: true,
              flagsButtonPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            const SizedBox(height: 32),
            
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitJobOffer,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _isSubmitting 
                    ? 'submitting'.tr() 
                    : (_isEditing ? 'updateJobOffer'.tr() : 'submitJobOffer'.tr()),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
