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
