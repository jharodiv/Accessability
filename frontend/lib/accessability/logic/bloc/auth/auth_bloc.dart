import 'package:bloc/bloc.dart';
import 'package:frontend/accessability/data/model/login_model.dart';
import 'package:frontend/accessability/data/repositories/auth_repository.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_event.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_state.dart';
import 'package:frontend/accessability/logic/bloc/user/user_bloc.dart';
import 'package:frontend/accessability/logic/bloc/user/user_event.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final UserBloc userBloc;

  AuthBloc(this.authRepository, this.userBloc) : super(AuthInitial()) {
      on<LoginEvent>((event, emit) async {
        emit(AuthLoading());
        try {
          final loginModel = await authRepository.login(event.email, event.password);
          emit(AuthenticatedLogin(loginModel, hasCompletedOnboarding: loginModel.hasCompletedOnboarding));
          userBloc.add(FetchUserData()); // Fetch user data after login
        } catch (e) {
          emit(AuthError('Login failed: ${e.toString()}'));
        }
      });

   on<CheckAuthStatus>((event, emit) async {
  emit(AuthLoading());
  try {
    final user = await authRepository.getCachedUser();
    if (user != null) {
      emit(AuthenticatedLogin(
        LoginModel(
          token: user.uid,
          userId: user.uid,
          hasCompletedOnboarding: user.hasCompletedOnboarding,
          user: user,
        ),
        hasCompletedOnboarding: user.hasCompletedOnboarding,
      ));

      // userBloc.add(FetchUserData()); // Fetch user data if authenticated
    } else {
      emit(AuthInitial()); // No user is logged in
    }
  } catch (e) {
    emit(AuthError('Failed to check auth status: ${e.toString()}'));
  }
});

    on<CompleteOnboardingEvent>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await authRepository.getCachedUser();
        if (user != null) {
          await authRepository.completeOnboarding(user.uid);
          emit(const AuthSuccess('Onboarding completed successfully'));
        } else {
          emit(const AuthError('User not found'));
        }
      } catch (e) {
        emit(AuthError('Failed to complete onboarding: ${e.toString()}'));
      }
    });

    on<LogoutEvent>((event, emit) async {
  emit(AuthLoading());
  try {
    await authRepository.clearUserCache(); // Clear cached user data
    userBloc.add(ResetUserState()); // Reset UserBloc state
    emit(AuthInitial()); // Reset to initial state after logout
  } catch (e) {
    emit(AuthError('Failed to logout: ${e.toString()}'));
  }
});
  }
}