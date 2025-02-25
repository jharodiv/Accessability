import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/accessability/logic/bloc/user/user_event.dart';
import 'package:frontend/accessability/logic/bloc/user/user_state.dart';
import 'package:frontend/accessability/data/repositories/user_repository.dart';


class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository userRepository;

  UserBloc({required this.userRepository}) : super(UserInitial()) {
    on<FetchUserData>(_onFetchUserData);
    on<UploadProfilePictureEvent>(_onUploadProfilePictureEvent);
  }

  Future<void> _onFetchUserData(FetchUserData event, Emitter<UserState> emit) async {
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
}