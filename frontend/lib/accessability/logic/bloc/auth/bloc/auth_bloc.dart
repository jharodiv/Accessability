import 'package:bloc/bloc.dart';
import 'package:frontend/accessability/data/repositories/auth_repository.dart';
import 'package:frontend/accessability/logic/bloc/auth/bloc/auth_event.dart';
import 'package:frontend/accessability/logic/bloc/auth/bloc/auth_state.dart';
import 'package:meta/meta.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc(this.authRepository) : super(AuthInitial()) {
    on<LoginEvent>((event, emit) async {
      emit(AuthLoading());
      try {
        final loginModel = await authRepository.login(event.email, event.password);
        emit(AuthenticatedLogin(loginModel));
      } catch (e) {
        emit(AuthError('Login failed: ${e.toString()}'));
      }
    });

    on<CompleteOnboardingEvent>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await authRepository.getCachedUser();
        if (user != null) {
          await authRepository.completeOnboarding(user.id);
          emit(const AuthSuccess('Onboarding completed successfully'));
        } else {
          emit(AuthError('User not found'));
        }
      } catch (e) {
        emit(AuthError('Failed to complete onboarding: ${e.toString()}'));
      }
    });
  }
}