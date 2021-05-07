import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ortus/models/chat/message.dart';
import 'package:ortus/models/chat/message_user.dart';
import 'package:ortus/redux/chat/chat_actions.dart';
import 'package:ortus/utils/http_utils.dart';
import 'package:web_socket_channel/io.dart';

class ChatApi {
  getChatUser(dispatch) async {
    return await api('/v4/clients/chat/user', {'method': 'GET'}, dispatch);
  }

  getSubscriptions(dispatch, userId, token) async {
    return await chatApi('/api/v1/subscriptions.get', {'method': 'GET'}, userId, token, dispatch);
  }

  getRooms(dispatch, userId, token) async {
    return await chatApi('/api/v1/rooms.get', {'method': 'GET'}, userId, token, dispatch);
  }

  getRoomsInfo(dispatch, List<String> roomIds) async {
    final uri = new Uri(path: '/v4/clients/chat/rooms-info/', queryParameters: {
      'roomsIds': roomIds.join(','),
    });
    return await api(uri.toString(), {'method': 'GET'}, dispatch);
  }

  getRoomMessages(dispatch, String roomId, int limit, int offset, userId, token) async {
    final uri = new Uri(path: '/api/v1/im.messages', queryParameters: {
      'roomId': roomId,
      'offset': offset.toString(),
      'count': limit.toString()
    });
    return await chatApi(uri.toString(), {'method': 'GET'}, userId, token, dispatch);
  }

  sendMessage(dispatch, String roomId, String opponentName, String text, String userId, String token) async {
    Map<String,String> data = {
      'roomId': roomId,
      'channel': '@$opponentName',
      'text': text,
    };

    return await chatApi('/api/v1/chat.postMessage', {'method': 'POST', 'body': jsonEncode(data)}, userId, token, dispatch);
  }

  getRoomInfo(dispatch, String roomId, String userId, String token) async {
    final uri = new Uri(path: '/api/v1/rooms.info', queryParameters: {
      'roomId': roomId,
    });

    return await chatApi(uri.toString(), {'method': 'GET'}, userId, token, dispatch);
  }

  markRoomAsReed(dispatch, String roomId, String userId, String token) async {
    return await chatApi('/api/v1/subscriptions.read', {'method': 'POST', 'body': jsonEncode({'rid': roomId})}, userId, token, dispatch);
  }

  getCompanyChat(dispatch, int companyId) async {
    return await api('/v4/clients/chat/company-chat/$companyId', {'method': 'GET'}, dispatch);
  }

  createChatWithCompany(dispatch, int ownerId, int companyId, String userId, String token) async {
    return await api('/v4/clients/chat/create-chat/$companyId', {
      'method': 'POST',
      'body': jsonEncode({
        'token': token,
        'chatUserId': userId,
        'ownerId': ownerId,
      }),
    }, dispatch);
  }

  sendFile(dispatch, String roomId, String userId, String token, File file) async {
    return await chatApi('/api/v1/rooms.upload/$roomId', {
      'method': 'POST',
    }, userId, token, dispatch, isFileUpload: true, file: file);
  }

  chatSocketInit(dispatch, String token) async {
    const streamRoomMessages = 'stream-room-messages';

    WebSocket.connect(DotEnv().env['APP_CHAT_API_WS_PATH']).then((ws) {
      var channel = IOWebSocketChannel(ws);

      channel.sink.add(jsonEncode({
        'msg': 'connect',
        'version': '1',
        'support': ['1'],
      }));

      channel.sink.add(jsonEncode({
        'msg': 'method',
        'method': 'login',
        'id': 'connect',
        'params': [
          {'resume': token},
        ],
      }));

      channel.sink.add(jsonEncode({
        'msg': 'sub',
        'id': 'help_subscribe',
        'name': streamRoomMessages,
        'params': ['__my_messages__', true],
      }));

      channel.sink.add(jsonEncode({
        'msg': 'method',
        'method': 'subscriptions/get',
        'id': 'read_subscribe',
        'params': [],
      }));

      channel.stream.listen((event) {
        Map<String, dynamic> message = jsonDecode(event);
        if (message['msg'] == 'ping') {
          channel.sink.add(jsonEncode({'msg': 'pong'}));
        }

        if (message['collection'] == streamRoomMessages && message['msg'] == 'changed') {
          Map<String,dynamic> result =
          message['fields'] != null && message['fields']['args'] != null && message['fields']['args'].length > 0 && message['fields']['args'][0].length > 0
              ? message['fields']['args'][0][0]
              : null;
          if (result != null) {
            Message message = new Message(
              id: result['_id'],
              fileUrl: result['file'] != null ? Uri.encodeFull('${DotEnv().env['APP_CHAT_API_PATH']}/file-upload/${result['file']['_id']}/${result['file']['name']}') : '',
              message: result['msg'],
              roomId: result['rid'],
              date: DateTime.fromMillisecondsSinceEpoch(result['ts']['\$date']).toLocal(),
              user: new MessageUser(
                id: result['u']['_id'],
                name: result['u']['username'],
              ),
            );

            dispatch(ReceivedMessage(message));
          }
        }
      });
    });
  }
}
