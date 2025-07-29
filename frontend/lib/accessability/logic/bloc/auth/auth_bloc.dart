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
import 'package:flutter/foundation.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final UserRepository userRepository;
  final UserBloc userBloc;
  final AuthService authService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthBloc({
    required this.authRepository,
    required this.userRepository,
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
    on<ForgotPasswordEvent>(_onForgotPasswordEvent);
    on<ChangePasswordEvent>(_onChangePasswordEvent);
    on<DeleteAccountEvent>(_onDeleteAccountEvent);
    on<ResetAuthState>((event, emit) => emit(AuthInitial()));
  }

  Future<void> _onLoginEvent(LoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingLogin());
    debugPrint('AuthBloc: Starting login process for ${event.email}');

    try {
      final loginModel =
          await authRepository.login(event.email, event.password);
      final user = authService.getCurrentUser();

      if (user != null && !user.emailVerified) {
        emit(const AuthError(
          'Please verify your email before logging in. Check your inbox.',
        ));
        return;
      }

      await authService.saveFCMToken(loginModel.userId);
      final userDoc =
          await _firestore.collection('Users').doc(loginModel.userId).get();

      emit(AuthenticatedLogin(
        loginModel,
        hasCompletedOnboarding:
            userDoc.data()?['hasCompletedOnboarding'] ?? false,
      ));
      userBloc.add(FetchUserData());
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_getUserFriendlyErrorMessage(e)));
    } catch (e) {
      emit(AuthError('An unexpected error occurred. Please try again.'));
    }
  }

  String _getUserFriendlyErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      // Firebase Auth Errors
      case 'invalid-credential':
      case 'wrong-password':
        return 'The email or password is incorrect.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'No internet connection. Check your network.';

      // Custom Errors (from AuthRepository)
      case 'user-data-missing':
        return 'Account exists but data is corrupted. Contact support.';
      case 'email-not-verified':
        return 'Please verify your email first. Check your inbox.';

      // Default
      default:
        return e.message ?? 'Login failed. Please try again.';
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
        return 'The email or password is incorrect';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'invalid-email':
        return 'Please enter a valid email address';
      default:
        return 'Login failed. Please try again.';
    }
  }

  Future<void> _onRegisterEvent(
    RegisterEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      // Attempt registration; may throw FirebaseAuthException
      final userModel = await authRepository.register(
        event.signUpModel,
        event.profilePicture,
      );

      // If we reach here, registration succeeded
      emit(RegistrationSuccess());
    } on FirebaseAuthException catch (e) {
      // First, try to map well‑known Firebase codes to friendly messages
      String? friendly = _mapFirebaseRegistrationError(e);

      // If we didn’t have a mapping, fallback to the raw message
      final errorMessage =
          friendly ?? e.message ?? 'Registration failed. Please try again.';

      emit(AuthError(errorMessage));
    } catch (e) {
      // Any other exception (wrapped as FirebaseAuthException in repo,
      // or completely different) is shown directly:
      emit(AuthError(e.toString()));
    }
  }

  String? _mapFirebaseRegistrationError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please use a different email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'operation-not-allowed':
        return 'Registration is currently disabled. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return null; // no special mapping for this code
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
        final userDoc =
            await _firestore.collection('Users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data()?['biometricEnabled'] == true) {
          emit(AuthenticatedLogin(
            LoginModel(
              token: user.uid,
              userId: user.uid,
              hasCompletedOnboarding:
                  userDoc.data()?['hasCompletedOnboarding'] ?? false,
              user: UserModel.fromJson(userDoc.data()!),
            ),
            hasCompletedOnboarding:
                userDoc.data()?['hasCompletedOnboarding'] ?? false,
          ));
          userBloc.add(FetchUserData());
        } else {
          emit(const AuthError(
              'Biometric login is not enabled for this account'));
        }
      } else {
        emit(const AuthError('Please login with email and password first'));
      }
    } catch (e) {
      emit(const AuthError('Biometric authentication failed'));
    }
  }

  Future<void> _onCheckAuthStatus(
      CheckAuthStatus event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await userRepository.getCachedUser();
      if (user != null) {
        // Verify the user still exists in Firebase
        final userDoc =
            await _firestore.collection('Users').doc(user.uid).get();
        if (userDoc.exists) {
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
          // User doc doesn't exist anymore - treat as logged out
          await authRepository.logout();
          emit(AuthInitial());
        }
      } else {
        emit(AuthInitial());
      }
    } catch (e) {
      emit(const AuthError('Failed to check authentication status'));
    }
  }

  Future<void> _onCompleteOnboardingEvent(
    CompleteOnboardingEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await userRepository.getCachedUser();
      if (user != null) {
        await authRepository.completeOnboarding(user.uid);

        // Fetch fresh data from Firestore
        final updatedUser = await userRepository.fetchUserData(user.uid);
        if (updatedUser != null) {
          emit(AuthenticatedLogin(
            LoginModel(
              token: updatedUser.uid,
              userId: updatedUser.uid,
              hasCompletedOnboarding: true,
              user: updatedUser,
            ),
            hasCompletedOnboarding: true,
          ));
          emit(const AuthSuccess('Onboarding completed successfully'));
        } else {
          emit(const AuthError('Failed to update user data'));
        }
      } else {
        emit(const AuthError('User not found'));
      }
    } catch (e) {
      emit(const AuthError('Failed to complete onboarding'));
    }
  }

  Future<void> _onLogoutEvent(
      LogoutEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await authRepository.logout();
      emit(AuthInitial());
    } catch (e) {
      debugPrint('Login error caught: $e');
      String errorMessage = e is FirebaseAuthException
          ? _mapFirebaseAuthError(e)
          : 'Login failed. Please try again';
      debugPrint('Emitting AuthError with message: $errorMessage');
      emit(AuthError(errorMessage));
    }
  }

  Future<void> _onCheckEmailVerification(
    CheckEmailVerification event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final user = authService.getCurrentUser();
      if (user != null) {
        await user.reload();
        if (user.emailVerified) {
          emit(EmailVerified());
        } else {
          emit(const AuthError('Email not verified yet'));
        }
      }
    } catch (e) {
      emit(const AuthError('Failed to check email verification status'));
    }
  }

  Future<void> _onForgotPasswordEvent(
    ForgotPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await authService.sendPasswordResetEmail(event.email);
      emit(ForgotPasswordSuccess(
        'Password reset instructions sent to ${event.email}',
      ));
    } on FirebaseAuthException catch (e) {
      final errorMessage = _mapForgotPasswordError(e);
      emit(ForgotPasswordFailure(errorMessage));
    } catch (e) {
      emit(const ForgotPasswordFailure('Failed to send reset email'));
    }
  }

  String _mapForgotPasswordError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Failed to send password reset email';
    }
  }

  String _mapChangePasswordError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential': // ← add this line
        return 'Current password is incorrect.';
      case 'weak-password':
        return 'New password is too weak.';
      case 'requires-recent-login':
        return 'Please log in again before changing your password.';
      default:
        debugPrint('Unhandled changePassword error code: ${e.code}');
        return 'Failed to change password. Please try again.';
    }
  }

  Future<void> _onChangePasswordEvent(
    ChangePasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await authRepository.changePassword(
        event.currentPassword,
        event.newPassword,
      );
      emit(const AuthSuccess('Password changed successfully.'));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapChangePasswordError(e)));
    } catch (_) {
      emit(const AuthError('Failed to change password.'));
    }
  }

  Future<void> _onDeleteAccountEvent(
      DeleteAccountEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await authRepository.deleteAccount();
      emit(const AuthSuccess('Account deleted successfully'));
    } on FirebaseAuthException catch (e) {
      final errorMessage = _mapDeleteAccountError(e);
      emit(AuthError(errorMessage));
    } catch (e) {
      emit(const AuthError('Failed to delete account'));
    }
  }

  String _mapDeleteAccountError(FirebaseAuthException e) {
    switch (e.code) {
      case 'requires-recent-login':
        return 'Please login again before deleting your account';
      default:
        return 'Failed to delete account';
    }
  }
}
