class EmergencyContact {
  final String? id; // Firestore document ID (optional)
  final String name;
  final String location;
  final String arrival;
  final String update;

  EmergencyContact({
    this.id,
    required this.name,
    required this.location,
    required this.arrival,
    required this.update,
  });

  // Creates an EmergencyContact instance from a Map.
  // Optionally, the Firestore document ID can be provided.
  factory EmergencyContact.fromMap(Map<String, dynamic> map, {String? id}) {
    return EmergencyContact(
      id: id,
      name: map['name'] ?? '',
      location: map['location'] ?? '',
      arrival: map['arrival'] ?? '',
      update: map['update'] ?? '',
    );
  }

  // Converts the EmergencyContact instance into a Map.
  // This map can then be stored in Firestore.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'location': location,
      'arrival': arrival,
      'update': update,
    };
  }

  // Optional: Create a copy of the EmergencyContact with updated values.
  EmergencyContact copyWith({
    String? id,
    String? name,
    String? location,
    String? arrival,
    String? update,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      arrival: arrival ?? this.arrival,
      update: update ?? this.update,
    );
  }
}
