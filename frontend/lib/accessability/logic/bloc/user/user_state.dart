import 'package:AccessAbility/accessability/data/model/user_model.dart';
import 'package:AccessAbility/accessability/data/model/emergency_contact.dart';
import 'package:AccessAbility/accessability/data/model/place.dart';

abstract class UserState {}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserLoaded extends UserState {
  final UserModel user;

  UserLoaded(this.user);
}

class UserError extends UserState {
  final String message;

  UserError(this.message);
}

// Place Operation States
class PlaceOperationLoading extends UserState {}

class PlaceOperationSuccess extends UserState {}

class PlacesLoaded extends UserState {
  final List<Place> places;

  PlacesLoaded(this.places);
}

class PlaceOperationError extends UserState {
  final String message;

  PlaceOperationError(this.message);
}

// --- Emergency Contact States ---

class EmergencyContactOperationLoading extends UserState {}

class EmergencyContactOperationSuccess extends UserState {}

class EmergencyContactsLoaded extends UserState {
  final List<EmergencyContact> contacts;

  EmergencyContactsLoaded(this.contacts);
}

class EmergencyContactOperationError extends UserState {
  final String message;

  EmergencyContactOperationError(this.message);
}
