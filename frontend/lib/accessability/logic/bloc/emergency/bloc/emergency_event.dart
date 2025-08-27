import 'package:equatable/equatable.dart';
import 'package:accessability/accessability/data/model/emergency_contact.dart';

abstract class EmergencyEvent extends Equatable {
  const EmergencyEvent();

  @override
  List<Object?> get props => [];
}

class AddEmergencyContactEvent extends EmergencyEvent {
  final String uid;
  final EmergencyContact contact;

  const AddEmergencyContactEvent({required this.uid, required this.contact});

  @override
  List<Object?> get props => [uid, contact];
}

class FetchEmergencyContactsEvent extends EmergencyEvent {
  final String uid;

  const FetchEmergencyContactsEvent({required this.uid});

  @override
  List<Object?> get props => [uid];
}

class UpdateEmergencyContactEvent extends EmergencyEvent {
  final String uid;
  final String contactId;
  final EmergencyContact contact;

  const UpdateEmergencyContactEvent({
    required this.uid,
    required this.contactId,
    required this.contact,
  });

  @override
  List<Object?> get props => [uid, contactId, contact];
}

class DeleteEmergencyContactEvent extends EmergencyEvent {
  final String uid;
  final String contactId;

  const DeleteEmergencyContactEvent(
      {required this.uid, required this.contactId});

  @override
  List<Object?> get props => [uid, contactId];
}
