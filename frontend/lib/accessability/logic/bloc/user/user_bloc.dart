import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_state.dart';
import 'package:AccessAbility/accessability/data/repositories/user_repository.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository userRepository;

  UserBloc({required this.userRepository}) : super(UserInitial()) {
    on<FetchUserData>(_onFetchUserData);
    on<UploadProfilePictureEvent>(_onUploadProfilePictureEvent);
    on<EnableBiometricLogin>(_onEnableBiometricLogin);
    on<DisableBiometricLogin>(_onDisableBiometricLogin);
    on<ResetUserState>((event, emit) => emit(UserInitial()));
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

  Future<void> _onEnableBiometricLogin(
    EnableBiometricLogin event,
    Emitter<UserState> emit,
  ) async {
    emit(UserLoading());
    try {
      // Update Firestore
      await userRepository.updateUserData(event.uid, {
        'biometricEnabled': true,
        'deviceId': event.deviceId,
      });

      // Fetch updated user data
      final user = await userRepository.fetchUserData(event.uid);
      if (user != null) {
        // Cache the updated user data
        userRepository.cacheUserData(user);
        emit(UserLoaded(user));
      } else {
        emit(UserError('User not found'));
      }
    } catch (e) {
      emit(UserError('Failed to enable biometric login: ${e.toString()}'));
    }
  }

  Future<void> _onDisableBiometricLogin(
    DisableBiometricLogin event,
    Emitter<UserState> emit,
  ) async {
    emit(UserLoading());
    try {
      // Update Firestore
      await userRepository.updateUserData(event.uid, {
        'biometricEnabled': false,
        'deviceId': null,
      });

      // Fetch updated user data
      final user = await userRepository.fetchUserData(event.uid);
      if (user != null) {
        // Cache the updated user data
        userRepository.cacheUserData(user);
        emit(UserLoaded(user));
      } else {
        emit(UserError('User not found'));
      }
    } catch (e) {
      emit(UserError('Failed to disable biometric login: ${e.toString()}'));
    }
  }
}
