/// Organization statistics model (Slice 15)
class OrgStatsModel {
  final String orgId;
  final String orgName;
  final String plan;
  final OrgStatsCounts counts;
  final RecentActivity recentActivity;
  final StorageInfo storage;

  const OrgStatsModel({
    required this.orgId,
    required this.orgName,
    required this.plan,
    required this.counts,
    required this.recentActivity,
    required this.storage,
  });

  factory OrgStatsModel.fromJson(Map<String, dynamic> json) {
    return OrgStatsModel(
      orgId: json['orgId'] as String? ?? '',
      orgName: json['orgName'] as String? ?? '',
      plan: json['plan'] as String? ?? 'FREE',
      counts: OrgStatsCounts.fromJson(
          Map<String, dynamic>.from((json['counts'] ?? {}) as Map)),
      recentActivity: RecentActivity.fromJson(Map<String, dynamic>.from(
          (json['recentActivity'] ?? {}) as Map)),
      storage: StorageInfo.fromJson(
          Map<String, dynamic>.from((json['storage'] ?? {}) as Map)),
    );
  }
}

class OrgStatsCounts {
  final int members;
  final int cases;
  final int clients;
  final int documents;
  final int tasks;
  final int events;
  final int notes;
  final int timeEntries;
  final int invoices;

  const OrgStatsCounts({
    this.members = 0,
    this.cases = 0,
    this.clients = 0,
    this.documents = 0,
    this.tasks = 0,
    this.events = 0,
    this.notes = 0,
    this.timeEntries = 0,
    this.invoices = 0,
  });

  factory OrgStatsCounts.fromJson(Map<String, dynamic> json) {
    return OrgStatsCounts(
      members: json['members'] as int? ?? 0,
      cases: json['cases'] as int? ?? 0,
      clients: json['clients'] as int? ?? 0,
      documents: json['documents'] as int? ?? 0,
      tasks: json['tasks'] as int? ?? 0,
      events: json['events'] as int? ?? 0,
      notes: json['notes'] as int? ?? 0,
      timeEntries: json['timeEntries'] as int? ?? 0,
      invoices: json['invoices'] as int? ?? 0,
    );
  }
}

class RecentActivity {
  final Last30Days? last30Days;

  const RecentActivity({this.last30Days});

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      last30Days: json['last30Days'] != null
          ? Last30Days.fromJson(
              Map<String, dynamic>.from(json['last30Days'] as Map))
          : null,
    );
  }
}

class Last30Days {
  final int casesCreated;
  final int documentsUploaded;
  final int tasksCreated;
  final int eventsCreated;

  const Last30Days({
    this.casesCreated = 0,
    this.documentsUploaded = 0,
    this.tasksCreated = 0,
    this.eventsCreated = 0,
  });

  factory Last30Days.fromJson(Map<String, dynamic> json) {
    return Last30Days(
      casesCreated: json['casesCreated'] as int? ?? 0,
      documentsUploaded: json['documentsUploaded'] as int? ?? 0,
      tasksCreated: json['tasksCreated'] as int? ?? 0,
      eventsCreated: json['eventsCreated'] as int? ?? 0,
    );
  }
}

class StorageInfo {
  final double totalMB;
  final int totalBytes;

  const StorageInfo({this.totalMB = 0, this.totalBytes = 0});

  factory StorageInfo.fromJson(Map<String, dynamic> json) {
    return StorageInfo(
      totalMB: (json['totalMB'] as num?)?.toDouble() ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
    );
  }
}
