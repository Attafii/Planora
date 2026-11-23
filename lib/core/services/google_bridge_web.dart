import 'dart:js_interop';

@JS('planifyGoogleCode')
external JSPromise<JSString> _code(JSString clientId, JSBoolean calendar);
Future<String> googleCode(String clientId, bool calendar) async =>
    (await _code(clientId.toJS, calendar.toJS).toDart).toDart;
