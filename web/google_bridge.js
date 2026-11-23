window.planifyGoogleCode = function(clientId, calendar) {
  return new Promise((resolve,reject) => {
    if (!window.google?.accounts?.oauth2) {reject(new Error('Google could not load. Check your connection and retry.'));return;}
    google.accounts.oauth2.initCodeClient({client_id:clientId,
      scope:'openid email profile'+(calendar?' https://www.googleapis.com/auth/calendar.events':''),
      ux_mode:'popup',select_account:true,
      callback: r => r.code ? resolve(r.code) : reject(new Error(r.error || 'Google authorization was declined.')),
      error_callback: e => reject(new Error(e.type || 'Google popup was cancelled.'))
    }).requestCode();
  });
};
