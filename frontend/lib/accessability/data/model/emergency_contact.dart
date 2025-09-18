class EmergencyContact {
  final String? id; // Firestore document ID (optional)
  final String name;
  final String location;
  final String relationship;
  final String address;
  final String phone; // <-- re-added

  EmergencyContact({
    this.id,
    required this.name,
    required this.location,
    required this.relationship,
    required this.address,
    required this.phone,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map, {String? id}) {
    return EmergencyContact(
      id: id,
      name: map['name'] as String? ?? '',
      location: map['location'] as String? ?? '',
      relationship: map['relationship'] as String? ?? '',
      address: map['address'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'location': location,
      'relationship': relationship,
      'address': address,
      'phone': phone,
    };
  }

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? location,
    String? relationship,
    String? address,
    String? phone,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      relationship: relationship ?? this.relationship,
      address: address ?? this.address,
      phone: phone ?? this.phone,
    );
  }
}
