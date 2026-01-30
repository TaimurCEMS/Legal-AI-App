/// Organization settings model (Slice 15)
class OrgSettingsModel {
  final String orgId;
  final String name;
  final String? description;
  final String plan;
  final String? timezone;
  final BusinessHours? businessHours;
  final String? defaultCaseVisibility;
  final bool? defaultTaskVisibility;
  final String? website;
  final Address? address;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OrgSettingsModel({
    required this.orgId,
    required this.name,
    this.description,
    required this.plan,
    this.timezone,
    this.businessHours,
    this.defaultCaseVisibility,
    this.defaultTaskVisibility,
    this.website,
    this.address,
    this.createdAt,
    this.updatedAt,
  });

  factory OrgSettingsModel.fromJson(Map<String, dynamic> json) {
    return OrgSettingsModel(
      orgId: json['orgId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      plan: json['plan'] as String? ?? 'FREE',
      timezone: json['timezone'] as String?,
      businessHours: json['businessHours'] != null
          ? BusinessHours.fromJson(
              Map<String, dynamic>.from(json['businessHours'] as Map))
          : null,
      defaultCaseVisibility: json['defaultCaseVisibility'] as String?,
      defaultTaskVisibility: json['defaultTaskVisibility'] as bool?,
      website: json['website'] as String?,
      address: json['address'] != null
          ? Address.fromJson(
              Map<String, dynamic>.from(json['address'] as Map))
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orgId': orgId,
      'name': name,
      if (description != null) 'description': description,
      'plan': plan,
      if (timezone != null) 'timezone': timezone,
      if (businessHours != null) 'businessHours': businessHours!.toJson(),
      if (defaultCaseVisibility != null)
        'defaultCaseVisibility': defaultCaseVisibility,
      if (defaultTaskVisibility != null)
        'defaultTaskVisibility': defaultTaskVisibility,
      if (website != null) 'website': website,
      if (address != null) 'address': address!.toJson(),
    };
  }
}

class BusinessHours {
  final String start;
  final String end;

  const BusinessHours({required this.start, required this.end});

  factory BusinessHours.fromJson(Map<String, dynamic> json) {
    return BusinessHours(
      start: json['start'] as String? ?? '09:00',
      end: json['end'] as String? ?? '17:00',
    );
  }

  Map<String, dynamic> toJson() => {'start': start, 'end': end};
}

class Address {
  final String? street;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  const Address({
    this.street,
    this.city,
    this.state,
    this.postalCode,
    this.country,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      street: json['street'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postalCode'] as String?,
      country: json['country'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (street != null) 'street': street,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (postalCode != null) 'postalCode': postalCode,
      if (country != null) 'country': country,
    };
  }
}
