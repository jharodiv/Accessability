import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/accessability/logic/bloc/user/user_event.dart';
import 'package:frontend/accessability/logic/bloc/user/user_state.dart';
import 'package:frontend/accessability/data/repositories/user_repository.dart';


class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository userRepository;

  UserBloc(this.userRepository) : super(UserInitial()) {
    on<FetchUserData>((event, emit) async {
      if (state is! UserLoaded) { // Only fetch if not already loaded
        emit(UserLoading());
        try {
          print("UserBloc: Fetching user data...");
          final user = await userRepository.getCachedUser();
          if (user != null) {
            emit(UserLoaded(user));
            print("UserBloc: User fetched successfully: ${user.toJson()}");
          } else {
            emit(UserError('User not found'));
          }
        } catch (e) {
          emit(UserError('Failed to fetch user data: ${e.toString()}'));
        }
      }
    });

    on<ResetUserState>((event, emit) {
      emit(UserInitial()); // Reset to initial state
    });
  }
}