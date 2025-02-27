import 'package:AccessAbility/accessability/firebaseServices/models/emergency_contact.dart';
import 'package:image_picker/image_picker.dart';
import 'package:equatable/equatable.dart';

abstract class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object> get props => [];
}

// Existing Events
class FetchUserData extends UserEvent {}

class ResetUserState extends UserEvent {}

class UploadProfilePictureEvent extends UserEvent {
  final String uid;
  final XFile profilePicture;

  const UploadProfilePictureEvent({
    required this.uid,
    required this.profilePicture,
  });

  @override
  List<Object> get props => [uid, profilePicture];
}

class AddPlaceEvent extends UserEvent {
  final String name;
  final String category;
  final double latitude;
  final double longitude;

  const AddPlaceEvent({
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object> get props => [name, category, latitude, longitude];
}

class GetPlacesByCategoryEvent extends UserEvent {
  final String category;

  const GetPlacesByCategoryEvent({
    required this.category,
  });

  @override
  List<Object> get props => [category];
}

class DeletePlaceEvent extends UserEvent {
  final String placeId;

  const DeletePlaceEvent({
    required this.placeId,
  });

  @override
  List<Object> get props => [placeId];
}

// --- Emergency Contact Events ---

class AddEmergencyContactEvent extends UserEvent {
  final String uid;
  final EmergencyContact contact;

  const AddEmergencyContactEvent({
    required this.uid,
    required this.contact,
  });

  @override
  List<Object> get props => [uid, contact];
}

class FetchEmergencyContactsEvent extends UserEvent {
  final String uid;

  const FetchEmergencyContactsEvent({
    required this.uid,
  });

  @override
  List<Object> get props => [uid];
}

class UpdateEmergencyContactEvent extends UserEvent {
  final String uid;
  final String contactId;
  final EmergencyContact contact;

  const UpdateEmergencyContactEvent({
    required this.uid,
    required this.contactId,
    required this.contact,
  });

  @override
  List<Object> get props => [uid, contactId, contact];
}

class DeleteEmergencyContactEvent extends UserEvent {
  final String uid;
  final String contactId;

  const DeleteEmergencyContactEvent({
    required this.uid,
    required this.contactId,
  });

  @override
  List<Object> get props => [uid, contactId];
}
