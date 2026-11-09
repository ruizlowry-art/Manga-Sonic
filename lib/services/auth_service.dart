import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Authentication service for managing Supabase auth state
/// 
/// Provides sign-up, sign-in, sign-out, and session management
/// with local persistence and automatic token refresh.
class AuthService extends ChangeNotifier {
  final SupabaseClient _client;
  
  User? _currentUser;
  bool _isInitialized = false;
  String? _authError;
  AuthState _authState = AuthState.unknown;

  AuthService._(this._client) {
    _initAuthListener();
    _restoreSession();
  }

  /// Singleton instance
  static AuthService? _instance;
  
  /// Get the singleton instance, initializing if needed
  static AuthService get instance {
    _instance ??= AuthService._(Supabase.instance.client);
    return _instance!;
  }

  /// Initialize the Supabase client and auth service
  /// Call this once during app startup
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.projectUrl,
      anonKey: SupabaseConfig.anonKey,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true,
        persistSession: true,
      ),
    );
    // Give time for session to restore from storage
    await Future.delayed(const Duration(milliseconds: 500));
    _instance = AuthService._(Supabase.instance.client);
  }

  /// Current authenticated user (null if not signed in)
  User? get currentUser => _currentUser;

  /// Whether a user is currently signed in
  bool get isSignedIn => _currentUser != null;

  /// Current authentication state
  AuthState get authState => _authState;

  /// Any authentication error that occurred
  String? get authError => _authError;

  /// Whether the auth service has been initialized
  bool get isInitialized => _isInitialized;

  /// User's email (if signed in)
  String? get userEmail => _currentUser?.email;

  /// User's ID (if signed in)
  String? get userId => _currentUser?.id;

  /// Initialize auth state listener and restore session
  void _initAuthListener() {
    _client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      
      _currentUser = session?.user;
      _updateAuthState(event);
      notifyListeners();
    });
  }

  /// Update auth state based on auth event
  void _updateAuthState(AuthChangeEvent event) {
    switch (event) {
      case AuthChangeEvent.signedIn:
        _authState = AuthState.signedIn;
        _authError = null;
        break;
      case AuthChangeEvent.signedOut:
        _authState = AuthState.signedOut;
        _currentUser = null;
        _authError = null;
        break;
      case AuthChangeEvent.tokenRefreshed:
        _authState = AuthState.signedIn;
        break;
      case AuthChangeEvent.userUpdated:
        _authState = AuthState.signedIn;
        break;
      case AuthChangeEvent.passwordRecovery:
        _authState = AuthState.passwordRecovery;
        break;
      default:
        _authState = _currentUser != null ? AuthState.signedIn : AuthState.signedOut;
    }
  }

  /// Restore session from local storage
  Future<void> _restoreSession() async {
    try {
      // First check current session
      final session = _client.auth.currentSession;
      if (session != null) {
        _currentUser = session.user;
        _authState = AuthState.signedIn;
        debugPrint('AuthService: Session restored for user ${session.user.email}');
      } else {
        // Try to recover session from storage
        debugPrint('AuthService: No current session, checking for stored session...');
        _authState = AuthState.signedOut;
      }
    } catch (e) {
      _authState = AuthState.error;
      _authError = 'Failed to restore session: $e';
      debugPrint('AuthService: Error restoring session: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Ensure the Supabase client has the current session set
  /// This helps with RLS policies on database operations
  void ensureSession() {
    final session = _client.auth.currentSession;
    if (session != null && _currentUser == null) {
      _currentUser = session.user;
      _authState = AuthState.signedIn;
      notifyListeners();
    }
  }

  /// Sign up with email and password
  /// 
  /// Returns true if successful, false if error.
  /// If email confirmation is disabled in Supabase, user is signed in immediately.
  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    _authError = null;
    _authState = AuthState.loading;
    notifyListeners();

    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: kIsWeb ? null : 'io.supabase.flutter://login-callback/',
      );

      if (response.user != null) {
        _currentUser = response.user;
        _authState = response.session != null ? AuthState.signedIn : AuthState.needsEmailConfirmation;
        notifyListeners();
        return true;
      }
      
      _authState = AuthState.error;
      _authError = 'Sign up failed: No user returned';
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _authState = AuthState.error;
      _authError = _mapAuthError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _authState = AuthState.error;
      _authError = 'Unexpected error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Sign in with email and password
  /// 
  /// Returns true if successful, false if error.
  /// If email confirmation is disabled in Supabase, user is signed in immediately.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _authError = null;
    _authState = AuthState.loading;
    notifyListeners();

    try {
      debugPrint('AuthService: Attempting sign in for $email');
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      debugPrint('AuthService: Sign in response - user: ${response.user?.email}, session: ${response.session != null}');

      if (response.user != null) {
        _currentUser = response.user;
        // Check if email is confirmed
        if (response.session != null) {
          _authState = AuthState.signedIn;
        } else {
          _authState = AuthState.needsEmailConfirmation;
        }
        notifyListeners();
        return true;
      }
      
      _authState = AuthState.error;
      _authError = 'Sign in failed: No user returned';
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      debugPrint('AuthService: AuthException during sign in: ${e.code} - ${e.message}');
      _authState = AuthState.error;
      _authError = _mapAuthError(e);
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('AuthService: Unexpected error during sign in: $e');
      _authState = AuthState.error;
      _authError = 'Unexpected error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    _authError = null;
    try {
      await _client.auth.signOut();
      _currentUser = null;
      _authState = AuthState.signedOut;
    } catch (e) {
      _authError = 'Sign out failed: $e';
      _authState = AuthState.error;
    }
    notifyListeners();
  }

  /// Reset password - sends reset email
  Future<bool> resetPassword(String email) async {
    _authError = null;
    try {
      await _client.auth.resetPasswordForEmail(email);
      return true;
    } on AuthException catch (e) {
      _authError = _mapAuthError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _authError = 'Unexpected error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update user password (requires current session)
  Future<bool> updatePassword(String newPassword) async {
    _authError = null;
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } on AuthException catch (e) {
      _authError = _mapAuthError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _authError = 'Unexpected error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Clear any auth error
  void clearError() {
    _authError = null;
    notifyListeners();
  }

  /// Resend email confirmation
  Future<bool> resendConfirmationEmail(String email) async {
    _authError = null;
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      return true;
    } on AuthException catch (e) {
      _authError = _mapAuthError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _authError = 'Unexpected error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Map Supabase AuthException to user-friendly message
  String _mapAuthError(AuthException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'Invalid email or password';
      case 'email_not_confirmed':
        return 'Please confirm your email before signing in';
      case 'email_already_exists':
        return 'An account with this email already exists';
      case 'weak_password':
        return 'Password is too weak (minimum 6 characters)';
      case 'user_not_found':
        return 'No account found with this email';
      case 'too_many_requests':
        return 'Too many requests. Please try again later';
      case 'invalid_email':
        return 'Invalid email address';
      default:
        return e.message;
    }
  }
}

/// Authentication state enum
enum AuthState {
  unknown,
  loading,
  signedIn,
  signedOut,
  needsEmailConfirmation,
  passwordRecovery,
  error,
}