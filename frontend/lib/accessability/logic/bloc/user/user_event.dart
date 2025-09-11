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

class EnableBiometricLogin extends UserEvent {
  final String uid;
  final String deviceId;

  const EnableBiometricLogin(this.uid, this.deviceId);

  @override
  List<Object> get props => [uid, deviceId];
}

class DisableBiometricLogin extends UserEvent {
  final String uid;

  const DisableBiometricLogin(this.uid);

  @override
  List<Object> get props => [uid];
}

class UpdateUserName extends UserEvent {
  final String uid;
  final String firstName;
  final String lastName;

  UpdateUserName({
    required this.uid,
    required this.firstName,
    required this.lastName,
  });
}
