import 'package:bloc/bloc.dart';
import 'package:frontend/accessability/data/repositories/auth_repository.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_event.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_state.dart';
import 'package:frontend/accessability/logic/bloc/user/user_bloc.dart';
import 'package:frontend/accessability/logic/bloc/user/user_event.dart';
import 'package:meta/meta.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final UserBloc userBloc;

  AuthBloc(this.authRepository, this.userBloc) : super(AuthInitial()) {
    on<LoginEvent>((event, emit) async {
      emit(AuthLoading());
      try {
        final loginModel = await authRepository.login(event.email, event.password);
        
        emit(AuthenticatedLogin(loginModel, hasCompletedOnboarding: loginModel.hasCompletedOnboarding));
        
        // Dispatch FetchUserData event to UserBloc
        userBloc.add(FetchUserData());
      } catch (e) {
        emit(AuthError('Login failed: ${e.toString()}'));
      }
    });

   on<CompleteOnboardingEvent>((event, emit) async {
  emit(AuthLoading());
  try {
    final user = await authRepository.getCachedUser();
    if (user != null) {
      print('AuthBloc: Completing onboarding for user ${user.uid}');
      await authRepository.completeOnboarding(user.uid);
      emit(const AuthSuccess('Onboarding completed successfully'));
    } else {
      print('AuthBloc: User not found');
      emit(const AuthError('User not found'));
    }
  } catch (e) {
    print('AuthBloc: Error completing onboarding - ${e.toString()}');
    emit(AuthError('Failed to complete onboarding: ${e.toString()}'));
  }
});
  }
}