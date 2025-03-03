import 'package:AccessAbility/accessability/data/model/login_model.dart';
import 'package:AccessAbility/accessability/data/model/user_model.dart';
import 'package:AccessAbility/accessability/data/repositories/auth_repository.dart';
import 'package:AccessAbility/accessability/data/repositories/user_repository.dart';
import 'package:AccessAbility/accessability/firebaseServices/auth/auth_service.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_state.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_event.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final UserRepository userRepository; // Add UserRepository
  final UserBloc userBloc;
  final AuthService authService;
   final FirebaseFirestore _firestore = FirebaseFirestore.instance; 
  

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
    on<CheckEmailVerification>(_onCheckEmailVerification);
    on<LoginWithBiometricEvent>(_onLoginWithBiometricEvent);
  }

 Future<void> _onLoginEvent(LoginEvent event, Emitter<AuthState> emit) async {
  emit(AuthLoading());
  try {
    final loginModel = await authRepository.login(event.email, event.password);
    final user = authService.getCurrentUser(); // Use authService to get the current user

    if (user != null && !user.emailVerified) {
      emit(AuthError('Please verify your email before logging in'));
      return;
    }

    await authService.saveFCMToken(loginModel.userId);
    emit(AuthenticatedLogin(
      loginModel,
      hasCompletedOnboarding: loginModel.hasCompletedOnboarding,
    ));
    userBloc.add(FetchUserData());
  } catch (e) {
    emit(AuthError('Login failed: ${e.toString()}'));
  }
}
  // Handle RegisterEvent
  Future<void> _onRegisterEvent(
      RegisterEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
       final userModel = await authRepository.register(
        event.signUpModel,
        event.profilePicture,
      );
      emit(RegistrationSuccess());
    } catch (e) {
      emit(AuthError('Registration failed: ${e.toString()}'));
    }
  }

   Future<void> _onLoginWithBiometricEvent(
    LoginWithBiometricEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = authService.getCurrentUser();
      if (user != null) {
        final userDoc = await _firestore.collection('Users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data()?['biometricEnabled'] == true) {
          emit(AuthenticatedLogin(
            LoginModel(
              token: user.uid,
              userId: user.uid,
              hasCompletedOnboarding: userDoc.data()?['hasCompletedOnboarding'] ?? false,
              user: UserModel.fromJson(userDoc.data()!),
            ),
            hasCompletedOnboarding: userDoc.data()?['hasCompletedOnboarding'] ?? false,
          ));
          userBloc.add(FetchUserData());
        } else {
          emit(AuthError('Biometric login not enabled'));
        }
      } else {
        emit(AuthError('User not found'));
      }
    } catch (e) {
      emit(AuthError('Failed to login with biometrics: ${e.toString()}'));
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
    final user = await userRepository.getCachedUser();
    if (user != null) {
      await authRepository.completeOnboarding(user.uid);

      // Fetch the updated user data
      final updatedUser = await userRepository.fetchUserData(user.uid);
      if (updatedUser != null) {
        // Cache the updated user data
        userRepository.cacheUserData(updatedUser);

        emit(AuthenticatedLogin(
          LoginModel(
            token: updatedUser.uid,
            userId: updatedUser.uid,
            hasCompletedOnboarding: updatedUser.hasCompletedOnboarding,
            user: updatedUser,
          ),
          hasCompletedOnboarding: updatedUser.hasCompletedOnboarding,
        ));

        emit(const AuthSuccess('Onboarding completed successfully'));
      } else {
        emit(const AuthError('Failed to fetch updated user data'));
      }
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
      emit(AuthInitial()); // Reset to initial state after logout
    } catch (e) {
      emit(AuthError('Failed to logout: ${e.toString()}'));
    }
  }

 Future<void> _onCheckEmailVerification(
  CheckEmailVerification event,
  Emitter<AuthState> emit,
) async {
  final user = authService.getCurrentUser(); // Use authService to get the current user
  if (user != null) {
    await user.reload();
    if (user.emailVerified) {
      emit(EmailVerified());
    } else {
      emit(AuthError('Email not verified'));
    }
  }
}
}
