import 'package:image_picker/image_picker.dart';
import 'package:equatable/equatable.dart';

abstract class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object> get props => [];
}

class FetchUserData extends UserEvent {}

class ResetUserState extends UserEvent {}

class UploadProfilePictureEvent extends UserEvent {
  final String uid; // The user's unique ID
  final XFile profilePicture; // The new profile picture file

  const UploadProfilePictureEvent({
    required this.uid,
    required this.profilePicture,
  });
}

// New events for Place operations
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
}

class DeletePlaceEvent extends UserEvent {
  final String placeId;

  const DeletePlaceEvent({
    required this.placeId,
  });
}
