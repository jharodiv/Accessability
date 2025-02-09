import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/accessability/logic/bloc/user/user_event.dart';
import 'package:frontend/accessability/logic/bloc/user/user_state.dart';
import 'package:frontend/accessability/data/repositories/user_repository.dart';


class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository userRepository;

  UserBloc(this.userRepository) : super(UserInitial()) {
   on<FetchUserData>((event, emit) async {
  emit(UserLoading());
  print('FetchUserData event received'); // Debug print
  try {
    final user = await userRepository.getCachedUser();
    if (user != null) {
      print('User found: ${user.username}'); // Debug print
      emit(UserLoaded(user));
    } else {
      print('User not found in cache'); // Debug print
      emit(UserError('User not found'));
    }
  } catch (e) {
    print('Error fetching user data: ${e.toString()}'); // Debug print
    emit(UserError('Failed to fetch user data: ${e.toString()}'));
  }
});
  }
}