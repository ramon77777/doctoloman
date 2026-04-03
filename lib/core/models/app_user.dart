enum AppUserRole {
  patient,
  professional,
}

class AppUser {
  final String id;
  final String name;
  final String phone;
  final AppUserRole role;

  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
  });

  bool get isPatient => role == AppUserRole.patient;
  bool get isProfessional => role == AppUserRole.professional;

  AppUser copyWith({
    String? id,
    String? name,
    String? phone,
    AppUserRole? role,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'role': role.name,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: (map['id'] as String?)?.trim() ?? '',
      name: (map['name'] as String?)?.trim() ?? '',
      phone: (map['phone'] as String?)?.trim() ?? '',
      role: _roleFromString(map['role'] as String?),
    );
  }

  static AppUserRole _roleFromString(String? raw) {
    switch (raw) {
      case 'professional':
        return AppUserRole.professional;
      case 'patient':
      default:
        return AppUserRole.patient;
    }
  }

  @override
  String toString() {
    return 'AppUser(id: $id, name: $name, phone: $phone, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppUser &&
        other.id == id &&
        other.name == name &&
        other.phone == phone &&
        other.role == role;
  }

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ phone.hashCode ^ role.hashCode;
}