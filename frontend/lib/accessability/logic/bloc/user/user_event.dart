import 'package:image_picker/image_picker.dart';

abstract class UserEvent {}

class FetchUserData extends UserEvent {}

class ResetUserState extends UserEvent {}

class UploadProfilePictureEvent extends UserEvent {
  final String uid; // The user's unique ID
  final XFile profilePicture; // The new profile picture file

  UploadProfilePictureEvent({
    required this.uid,
    required this.profilePicture,
  });
}