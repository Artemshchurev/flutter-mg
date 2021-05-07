import 'dart:convert';

import 'package:ortus/utils/http_utils.dart';

class AuthApi {
  auth({data, dispatch}) async {
    return await api('/client/login', {'method': 'POST', 'body': jsonEncode(data)}, dispatch);
  }

  registration({data, dispatch}) async {
    return await api('/client/registration', {'method': 'POST', 'body': jsonEncode(data)}, dispatch);
  }

  registrationConfirm({data, dispatch}) async {
    return await api('/client/registration/confirm', {'method': 'POST', 'body': jsonEncode(data)}, dispatch);
  }

  postDevice({token, data, dispatch}) async {
    return await api('/v3/client/devices', data, dispatch, token: token);
  }

  updateActivity({token, data, dispatch}) async {
    return await api('/v3/client/devices/update-activity', data, dispatch, token: token);
  }

  fetchLogout({url, data, dispatch}) async {
    return await api(url, data, dispatch);
  }

  fetchDeleteDevice({onesignalId, token, data, dispatch}) async {
    return await api('/v3/client/devices/$onesignalId', data, dispatch, token: token);
  }

  getCountInformation(dispatch) async {
    return await api('/v3/client/information', {}, dispatch);
  }

  restorePasswordByAuth(dispatch) async {
    return await api('/client/password/restore-by-auth', {'method': 'POST'}, dispatch);
  }

  restorePasswordByPhone({data, dispatch}) async {
    return await api('/client/password/restore', {'method': 'POST', 'body': jsonEncode(data)}, dispatch);
  }

  confirmPassword({data, dispatch}) async {
    return await api('/client/password/confirm', {'method': 'POST', 'body': jsonEncode(data)}, dispatch);
  }
}
