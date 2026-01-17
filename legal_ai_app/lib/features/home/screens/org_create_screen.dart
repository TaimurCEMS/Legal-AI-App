import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/buttons/secondary_button.dart';
import '../../common/widgets/text_fields/app_text_field.dart';
import '../providers/org_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Organization creation screen
class OrgCreateScreen extends StatefulWidget {
  const OrgCreateScreen({super.key});

  @override
  State<OrgCreateScreen> createState() => _OrgCreateScreenState();
}

class _OrgCreateScreenState extends State<OrgCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateOrg() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final orgProvider = context.read<OrgProvider>();

    if (authProvider.currentUser == null) {
      return;
    }

    final success = await orgProvider.createOrg(
      name: _nameController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      userId: authProvider.currentUser!.uid,
    );

    if (success && mounted) {
      context.go(RouteNames.home);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orgProvider.errorMessage ?? 'Failed to create organization'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrgProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Organization'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create Organization',
                    style: AppTypography.headlineLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Set up your organization to get started',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppTextField(
                    label: 'Organization Name',
                    hint: 'Enter organization name',
                    controller: _nameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Organization name is required';
                      }
                      if (value.length < 1 || value.length > 100) {
                        return 'Name must be between 1 and 100 characters';
                      }
                      return null;
                    },
                    prefixIcon: const Icon(Icons.business_outlined),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Description (Optional)',
                    hint: 'Enter organization description',
                    controller: _descriptionController,
                    maxLines: 3,
                    validator: (value) {
                      if (value != null && value.length > 500) {
                        return 'Description must be 500 characters or less';
                      }
                      return null;
                    },
                    prefixIcon: const Icon(Icons.description_outlined),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Create Organization',
                    onPressed: _handleCreateOrg,
                    isLoading: orgProvider.isLoading,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    label: 'Cancel',
                    onPressed: () {
                      context.pop();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
