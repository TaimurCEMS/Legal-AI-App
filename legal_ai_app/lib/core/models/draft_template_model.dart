import 'chat_thread_model.dart';

enum DraftTemplateCategory {
  letter('LETTER', 'Letter'),
  contract('CONTRACT', 'Contract'),
  motion('MOTION', 'Motion'),
  brief('BRIEF', 'Brief'),
  other('OTHER', 'Other');

  const DraftTemplateCategory(this.value, this.displayLabel);
  final String value;
  final String displayLabel;

  static DraftTemplateCategory fromString(String value) {
    return DraftTemplateCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DraftTemplateCategory.other,
    );
  }
}

class DraftTemplateModel {
  final String templateId;
  final String name;
  final String description;
  final DraftTemplateCategory category;
  final JurisdictionModel? jurisdiction;

  const DraftTemplateModel({
    required this.templateId,
    required this.name,
    required this.description,
    required this.category,
    this.jurisdiction,
  });

  factory DraftTemplateModel.fromJson(Map<String, dynamic> json) {
    return DraftTemplateModel(
      templateId: json['templateId'] as String,
      name: json['name'] as String? ?? 'Untitled Template',
      description: json['description'] as String? ?? '',
      category: DraftTemplateCategory.fromString(
        json['category'] as String? ?? 'OTHER',
      ),
      jurisdiction: json['jurisdiction'] != null
          ? JurisdictionModel.fromJson(
              Map<String, dynamic>.from(json['jurisdiction'] as Map),
            )
          : null,
    );
  }
}

