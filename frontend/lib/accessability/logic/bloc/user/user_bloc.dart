import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/accessability/data/repositories/auth_repository.dart';
import 'package:frontend/accessability/data/model/user_model.dart';
import 'package:frontend/accessability/logic/bloc/user/user_event.dart';
import 'package:frontend/accessability/logic/bloc/user/user_state.dart';


class UserBloc extends Bloc<UserEvent, UserState> {
  final AuthRepository authRepository;

  UserBloc(this.authRepository) : super(UserInitial()) {
    on<FetchUserData>((event, emit) async {
      emit(UserLoading());
      try {
        final user = await authRepository.getCachedUser();
        if (user != null) {
          emit(UserLoaded(user));
        } else {
          emit(UserError('User not found'));
        }
      } catch (e) {
        emit(UserError('Failed to fetch user data: ${e.toString()}'));
      }
    });
  }
}