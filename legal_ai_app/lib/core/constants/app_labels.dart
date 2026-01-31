/// UI labels for legal terminology (MASTER_SPEC_V2.0: Organization → Firm, Case → Matter).
/// Use these for all user-facing strings; backend/API names remain org/case.
class AppLabels {
  AppLabels._();

  // Firm (replaces "Organization" in UI)
  static const String firm = 'Firm';
  static const String firmName = 'Firm name';
  static const String firmSettings = 'Firm Settings';
  static const String firmDashboard = 'Firm Dashboard';
  static const String firmExport = 'Firm Export';
  static const String currentFirm = 'Current Firm';
  static const String switchFirm = 'Switch Firm';
  static const String firmId = 'Firm ID';
  static const String firmSelection = 'Firm Selection';
  static const String joinFirm = 'Join Firm';
  static const String createFirm = 'Create Firm';

  // Matter (replaces "Case" in UI)
  static const String matter = 'Matter';
  static const String matters = 'Matters';
  static const String matterName = 'Matter name';
  static const String matterDetails = 'Matter details';
  static const String allMatters = 'All matters';
  static const String createMatter = 'Create Matter';
  static const String noMattersYet = 'No matters yet';
  static const String mattersCreated = 'Matters created';

  // Success messages (Firm)
  static const String successFirmCreated = 'Firm created successfully!';
  static const String successFirmJoined = 'Successfully joined firm!';
}
