import 'package:bloc/bloc.dart';
import 'package:Accessability/accessability/data/model/login_model.dart';
import 'package:Accessability/accessability/data/repositories/auth_repository.dart';
import 'package:Accessability/accessability/data/repositories/user_repository.dart';
import 'package:Accessability/accessability/firebaseServices/auth/auth_service.dart';
import 'package:Accessability/accessability/logic/bloc/auth/auth_event.dart';
import 'package:Accessability/accessability/logic/bloc/auth/auth_state.dart';
import 'package:Accessability/accessability/logic/bloc/user/user_bloc.dart';
import 'package:Accessability/accessability/logic/bloc/user/user_event.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final UserRepository userRepository; // Add UserRepository
  final UserBloc userBloc;
  final AuthService authService;

  AuthBloc({
    required this.authRepository,
    required this.userRepository, // Inject UserRepository
    required this.userBloc,
    required this.authService,
  }) : super(AuthInitial()) {
    on<LoginEvent>(_onLoginEvent);
    on<RegisterEvent>(_onRegisterEvent);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<CompleteOnboardingEvent>(_onCompleteOnboardingEvent);
    on<LogoutEvent>(_onLogoutEvent);
  }

  // Handle LoginEvent
  Future<void> _onLoginEvent(LoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final loginModel =
          await authRepository.login(event.email, event.password);
      await authService.saveFCMToken(loginModel.userId); // Save FCM token
      emit(AuthenticatedLogin(
        loginModel,
        hasCompletedOnboarding: loginModel.hasCompletedOnboarding,
      ));
      userBloc.add(FetchUserData()); // Fetch user data after login
    } catch (e) {
      emit(AuthError('Login failed: ${e.toString()}'));
    }
  }

  // Handle RegisterEvent
  Future<void> _onRegisterEvent(
      RegisterEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      emit(RegistrationSuccess());
    } catch (e) {
      emit(AuthError('Registration failed: ${e.toString()}'));
    }
  }

  // Handle CheckAuthStatus
  Future<void> _onCheckAuthStatus(
      CheckAuthStatus event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await userRepository.getCachedUser(); // Use UserRepository
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
      } else {
        emit(AuthInitial()); // No user is logged in
      }
    } catch (e) {
      emit(AuthError('Failed to check auth status: ${e.toString()}'));
    }
  }

  // Handle CompleteOnboardingEvent
  Future<void> _onCompleteOnboardingEvent(
    CompleteOnboardingEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await userRepository.getCachedUser(); // Use UserRepository
      if (user != null) {
        await authRepository.completeOnboarding(user.uid);
        emit(const AuthSuccess('Onboarding completed successfully'));
      } else {
        emit(const AuthError('User not found'));
      }
    } catch (e) {
      emit(AuthError('Failed to complete onboarding: ${e.toString()}'));
    }
  }

  // Handle LogoutEvent
  Future<void> _onLogoutEvent(
      LogoutEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await authRepository.logout(); // Clear cached user data
      userBloc.add(ResetUserState()); // Reset UserBloc state
      emit(AuthInitial()); // Reset to initial state after logout
    } catch (e) {
      emit(AuthError('Failed to logout: ${e.toString()}'));
    }
  }
}
