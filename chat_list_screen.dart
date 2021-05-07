import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:ortus/models/chat/chat_room.dart';

import 'package:ortus/redux/app/app_state.dart';
import 'package:ortus/redux/chat/chat_actions.dart';
import 'package:ortus/screens/chats/chat_list.dart';
import 'package:ortus/ui/chat/room_item.dart';
import 'package:ortus/ui/custom-app-bar.dart';

class ChatListScreen extends StatelessWidget {
  static const routeName = '/chat-list';

  void _requestChatData(context) {
    var store = StoreProvider.of<AppState>(context);
    String token = store.state.chatState.user.token;
    String userId = store.state.chatState.user.userId;
    String helpRoomId = store.state.chatState.user.helpRoomId;
    store.dispatch(GetSubscriptions(token, userId));
    store.dispatch(RequestRooms(token: token, userId: userId, helpRoomId: helpRoomId));
    store.dispatch(InitChatSocket(store.state.chatState.user.token));
  }

  void _requestRoomsInfo(context) {
    var store = StoreProvider.of<AppState>(context);
    List<String> roomIds = [];
    store.state.chatState.rooms.forEach((roomId, room) => roomIds.add(roomId));
    store.dispatch(RequestRoomsInfo(roomIds));
  }

  @override
  Widget build(BuildContext context) {
    return new StoreConnector<AppState, ChatList>(converter: (store) {
      return new ChatList(
        chatRooms: store.state.chatState.rooms,
        roomsNames: store.state.chatState.roomsNames,
        chatUser: store.state.chatState.user,
        unreadMessagesCount: store.state.chatState.unreadMessagesCount,
      );
    },
        onInit: (store) {
          if (store.state.chatState.user == null) {
            store.dispatch(GetChatUser());
          } else {
            if (store.state.chatState.rooms.length > 0) {
              _requestRoomsInfo(context);
            } else {
              _requestChatData(context);
            }
          }
        },
        onWillChange: (prevProps, props) {
          if (prevProps.chatUser == null && props.chatUser != null) {
            _requestChatData(context);
          }
          if (prevProps.chatRooms.length == 0 && props.chatRooms.length > 0) {
            _requestRoomsInfo(context);
          }
        },
        builder: (BuildContext context, ChatList props) {
          List<ChatRoom> rooms = props.chatRooms.entries.map((entry) => ChatRoom(
            id: entry.value.id,
            lastMessage: entry.value.lastMessage,
            name: entry.value.name,
            updateAt: entry.value.updateAt,
          ))
              .where(
                  (room) => StoreProvider.of<AppState>(context).state.chatState.user != null
                  && (room.id == StoreProvider.of<AppState>(context).state.chatState.user.helpRoomId || room.lastMessage != null)
          )
              .toList();

          rooms.sort((a,b) => b.lastMessage.date.compareTo(a.lastMessage.date));

          final vw = MediaQuery.of(context).size.width / 100;

          return Scaffold(
            appBar: CustomAppBar(
              title: Text('ЧАТЫ', style: TextStyle(fontSize: vw * 3.9, fontWeight: FontWeight.w600)),
              leading: SquidBackButton(),
            ),
            backgroundColor: Colors.white,
            body: ListView.builder(
              itemBuilder: (context, index) {
                String roomId = rooms[index].id;

                return RoomItem(
                  room: rooms[index],
                  chatUser: props.chatUser,
                  roomInfo: props.roomsNames[roomId] ?? null,
                  unreadMessagesCount: props.unreadMessagesCount[roomId] ?? 0,
                );
              },
              itemCount: rooms.isNotEmpty ? rooms.length : 0,
            ),
          );
        });
  }
}
