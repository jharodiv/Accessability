import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_state.dart';
import 'package:AccessAbility/accessability/data/repositories/user_repository.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository userRepository;

  UserBloc({required this.userRepository}) : super(UserInitial()) {
    on<FetchUserData>(_onFetchUserData);
    on<UploadProfilePictureEvent>(_onUploadProfilePictureEvent);

    // Emergency Contact event handlers
    on<AddEmergencyContactEvent>(_onAddEmergencyContactEvent);
    on<FetchEmergencyContactsEvent>(_onFetchEmergencyContactsEvent);
    on<UpdateEmergencyContactEvent>(_onUpdateEmergencyContactEvent);
    on<DeleteEmergencyContactEvent>(_onDeleteEmergencyContactEvent);
  }

  Future<void> _onFetchUserData(
      FetchUserData event, Emitter<UserState> emit) async {
    emit(UserLoading());
    try {
      final user = await userRepository.getCachedUser();
      if (user != null) {
        emit(UserLoaded(user));
      } else {
        emit(UserError('No user data available'));
      }
    } catch (e) {
      emit(UserError('Failed to fetch user data: ${e.toString()}'));
    }
  }

  Future<void> _onUploadProfilePictureEvent(
    UploadProfilePictureEvent event,
    Emitter<UserState> emit,
  ) async {
    emit(UserLoading());
    try {
      final updatedUser = await userRepository.updateProfilePicture(
        event.uid,
        event.profilePicture,
      );
      emit(UserLoaded(updatedUser));
    } catch (e) {
      emit(UserError('Failed to update profile picture: ${e.toString()}'));
    }
  }

  // --- Emergency Contact Event Handlers ---

  Future<void> _onAddEmergencyContactEvent(
      AddEmergencyContactEvent event, Emitter<UserState> emit) async {
    emit(EmergencyContactOperationLoading());
    try {
      await userRepository.addEmergencyContact(event.uid, event.contact);
      emit(EmergencyContactOperationSuccess());
    } catch (e) {
      emit(EmergencyContactOperationError(
          'Failed to add emergency contact: ${e.toString()}'));
    }
  }

  Future<void> _onFetchEmergencyContactsEvent(
      FetchEmergencyContactsEvent event, Emitter<UserState> emit) async {
    emit(EmergencyContactOperationLoading());
    try {
      final contacts = await userRepository.getEmergencyContacts(event.uid);
      emit(EmergencyContactsLoaded(contacts));
    } catch (e) {
      emit(EmergencyContactOperationError(
          'Failed to fetch emergency contacts: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateEmergencyContactEvent(
      UpdateEmergencyContactEvent event, Emitter<UserState> emit) async {
    emit(EmergencyContactOperationLoading());
    try {
      await userRepository.updateEmergencyContact(
          event.uid, event.contactId, event.contact);
      emit(EmergencyContactOperationSuccess());
    } catch (e) {
      emit(EmergencyContactOperationError(
          'Failed to update emergency contact: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteEmergencyContactEvent(
      DeleteEmergencyContactEvent event, Emitter<UserState> emit) async {
    emit(EmergencyContactOperationLoading());
    try {
      await userRepository.deleteEmergencyContact(event.uid, event.contactId);
      emit(EmergencyContactOperationSuccess());
    } catch (e) {
      emit(EmergencyContactOperationError(
          'Failed to delete emergency contact: ${e.toString()}'));
    }
  }
}
