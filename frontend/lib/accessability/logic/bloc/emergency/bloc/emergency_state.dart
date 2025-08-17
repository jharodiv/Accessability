import 'package:equatable/equatable.dart';
import 'package:AccessAbility/accessability/data/model/emergency_contact.dart';

abstract class EmergencyState extends Equatable {
  const EmergencyState();

  @override
  List<Object?> get props => [];
}

class EmergencyInitial extends EmergencyState {}

class EmergencyLoading extends EmergencyState {}

class EmergencyOperationSuccess extends EmergencyState {}

class EmergencyOperationError extends EmergencyState {
  final String message;
  const EmergencyOperationError(this.message);

  @override
  List<Object?> get props => [message];
}

class EmergencyContactsLoaded extends EmergencyState {
  final List<EmergencyContact> contacts;
  const EmergencyContactsLoaded(this.contacts);

  @override
  List<Object?> get props => [contacts];
}
