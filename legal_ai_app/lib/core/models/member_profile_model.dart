/// Member profile model (Slice 15)
class MemberProfileModel {
  final String memberUid;
  final String orgId;
  final String? email;
  final String? displayName;
  final String role;
  final DateTime? joinedAt;
  final String? bio;
  final String? title;
  final List<String> specialties;
  final List<BarAdmission> barAdmissions;
  final List<Education> education;
  final String? phoneNumber;
  final String? photoUrl;
  final bool isPublic;

  const MemberProfileModel({
    required this.memberUid,
    required this.orgId,
    this.email,
    this.displayName,
    required this.role,
    this.joinedAt,
    this.bio,
    this.title,
    this.specialties = const [],
    this.barAdmissions = const [],
    this.education = const [],
    this.phoneNumber,
    this.photoUrl,
    this.isPublic = true,
  });

  factory MemberProfileModel.fromJson(Map<String, dynamic> json) {
    return MemberProfileModel(
      memberUid: json['memberUid'] as String? ?? json['uid'] as String? ?? '',
      orgId: json['orgId'] as String? ?? '',
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      role: json['role'] as String? ?? 'VIEWER',
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'] as String)
          : null,
      bio: json['bio'] as String?,
      title: json['title'] as String?,
      specialties: (json['specialties'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      barAdmissions: (json['barAdmissions'] as List<dynamic>?)
              ?.map((e) => BarAdmission.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      education: (json['education'] as List<dynamic>?)
              ?.map((e) => Education.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      phoneNumber: json['phoneNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      isPublic: json['isPublic'] as bool? ?? true,
    );
  }

  String get displayLabel {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    if (email != null && email!.isNotEmpty) return email!;
    return 'User ${memberUid.substring(0, memberUid.length > 8 ? 8 : memberUid.length)}...';
  }
}

class BarAdmission {
  final String jurisdiction;
  final String? barNumber;
  final int? admittedYear;

  const BarAdmission({
    required this.jurisdiction,
    this.barNumber,
    this.admittedYear,
  });

  factory BarAdmission.fromJson(Map<String, dynamic> json) {
    return BarAdmission(
      jurisdiction: json['jurisdiction'] as String? ?? '',
      barNumber: json['barNumber'] as String?,
      admittedYear: json['admittedYear'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jurisdiction': jurisdiction,
      if (barNumber != null) 'barNumber': barNumber,
      if (admittedYear != null) 'admittedYear': admittedYear,
    };
  }
}

class Education {
  final String institution;
  final String degree;
  final int? year;

  const Education({
    required this.institution,
    required this.degree,
    this.year,
  });

  factory Education.fromJson(Map<String, dynamic> json) {
    return Education(
      institution: json['institution'] as String? ?? '',
      degree: json['degree'] as String? ?? '',
      year: json['year'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'institution': institution,
      'degree': degree,
      if (year != null) 'year': year,
    };
  }
}
