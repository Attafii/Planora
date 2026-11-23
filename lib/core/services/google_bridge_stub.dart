import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void>? _ready;
Future<String> googleCode(String clientId, bool calendar) async {
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    throw UnsupportedError(
      'Google sign-in is supported on Android, iOS and web.',
    );
  }
  const ios = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  if (defaultTargetPlatform == TargetPlatform.iOS && ios.isEmpty) {
    throw StateError(
      'Google iOS OAuth client and URL scheme must be configured before signing in.',
    );
  }
  final google = GoogleSignIn.instance;
  await (_ready ??= google.initialize(
    clientId: ios.isEmpty ? null : ios,
    serverClientId: clientId,
  ));
  final account = await google.authenticate();
  if (!calendar) {
    final token = account.authentication.idToken;
    if (token == null) {
      throw StateError('Google did not return an identity token.');
    }
    return 'idtoken:$token';
  }
  final auth = await account.authorizationClient.authorizeServer([
    'openid',
    'email',
    'profile',
    'https://www.googleapis.com/auth/calendar.events',
  ]);
  if (auth == null) {
    throw StateError(
      'Google did not return a server authorization code. Reconnect Google and try again.',
    );
  }
  return 'native:${auth.serverAuthCode}';
}
