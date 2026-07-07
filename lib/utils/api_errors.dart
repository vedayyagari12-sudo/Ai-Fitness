import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'snackbar.dart';

/// Maps API failures to user-facing snackbars. Never surfaces raw errors.
/// On 401 the session is invalid — sign out so the auth stream returns
/// the user to the login screen.
Future<void> showApiError(BuildContext context, {int? statusCode}) async {
  if (statusCode == 401) {
    AppSnackbar.error(context, 'Session expired — please sign in again');
    await Supabase.instance.client.auth.signOut();
    return;
  }
  if (statusCode == 429) {
    AppSnackbar.info(context, 'Daily limit reached, resets at midnight');
    return;
  }
  if (statusCode != null && statusCode >= 500) {
    AppSnackbar.error(context, 'Something went wrong — try again');
    return;
  }
  AppSnackbar.error(context, 'Connection lost — check your internet');
}
