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
        final user = await authRepository.login(event.email, event.password);
        emit(AuthenticatedLogin(user));
      } catch (e) {
        print('Error: ${e.toString()}'); // Add this

        emit(AuthError('Login failed: ${e.toString()}'));
      }
    });
    // Handle the CompleteOnboardingEvent
    on<CompleteOnboardingEvent>((event, emit) async {
      emit(AuthLoading());
      try {
        await authRepository.completeOnboarding();
        emit(const AuthSuccess('Onboarding completed successfully'));
      } catch (e) {
        emit(AuthError('Failed to complete onboarding: ${e.toString()}'));
      }
    });
  }
}
