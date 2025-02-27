import 'package:flutter_bloc/flutter_bloc.dart';
import 'emergency_event.dart';
import 'emergency_state.dart';
import 'package:AccessAbility/accessability/data/repositories/emergency_repository.dart';

class EmergencyBloc extends Bloc<EmergencyEvent, EmergencyState> {
  final EmergencyRepository emergencyRepository;

  EmergencyBloc({required this.emergencyRepository})
      : super(EmergencyInitial()) {
    on<AddEmergencyContactEvent>(_onAddEmergencyContact);
    on<FetchEmergencyContactsEvent>(_onFetchEmergencyContacts);
    on<UpdateEmergencyContactEvent>(_onUpdateEmergencyContact);
    on<DeleteEmergencyContactEvent>(_onDeleteEmergencyContact);
  }

  Future<void> _onAddEmergencyContact(
      AddEmergencyContactEvent event, Emitter<EmergencyState> emit) async {
    emit(EmergencyLoading());
    try {
      await emergencyRepository.addEmergencyContact(event.uid, event.contact);
      emit(EmergencyOperationSuccess());
    } catch (e) {
      emit(EmergencyOperationError(
          'Failed to add emergency contact: ${e.toString()}'));
    }
  }

  Future<void> _onFetchEmergencyContacts(
      FetchEmergencyContactsEvent event, Emitter<EmergencyState> emit) async {
    emit(EmergencyLoading());
    try {
      final contacts =
          await emergencyRepository.getEmergencyContacts(event.uid);
      emit(EmergencyContactsLoaded(contacts));
    } catch (e) {
      emit(EmergencyOperationError(
          'Failed to fetch emergency contacts: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateEmergencyContact(
      UpdateEmergencyContactEvent event, Emitter<EmergencyState> emit) async {
    emit(EmergencyLoading());
    try {
      await emergencyRepository.updateEmergencyContact(
          event.uid, event.contactId, event.contact);
      emit(EmergencyOperationSuccess());
    } catch (e) {
      emit(EmergencyOperationError(
          'Failed to update emergency contact: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteEmergencyContact(
      DeleteEmergencyContactEvent event, Emitter<EmergencyState> emit) async {
    emit(EmergencyLoading());
    try {
      await emergencyRepository.deleteEmergencyContact(
          event.uid, event.contactId);
      emit(EmergencyOperationSuccess());
    } catch (e) {
      emit(EmergencyOperationError(
          'Failed to delete emergency contact: ${e.toString()}'));
    }
  }
}
