import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:keyboard_visibility/keyboard_visibility.dart';

import 'package:ortus/models/chat/message.dart';
import 'package:ortus/models/chat/message_user.dart';
import 'package:ortus/redux/app/app_state.dart';
import 'package:ortus/redux/chat/chat_actions.dart';
import 'package:ortus/screens/chats/chat_room/chat_room.dart';
import 'package:ortus/screens/chats/chat_room/message_triangle.dart';
import 'package:ortus/ui/custom-app-bar.dart';

class ChatRoomScreen extends StatefulWidget {
  static const routeName = '/chat-list/chat-room';
  final String roomId;

  const ChatRoomScreen({Key key, @required this.roomId}) : super(key: key);

  @override
  _ChatRoomScreenState createState() => _ChatRoomScreenState(roomId);
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final String _roomId;
  final ScrollController _scrollController = new ScrollController();
  bool isShowSuffixIcons = true;

  _ChatRoomScreenState(this._roomId);

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.position.maxScrollExtent == _scrollController.offset) {
        final store = StoreProvider.of<AppState>(context);
        bool fetchingMessages = store.state.hangarState.fetching[ReqeustRoomMessages.fetchingLabel] == true;
        int messagesLength = store.state.chatState.roomMessages[_roomId].messages.length;
        int totalMessages = store.state.chatState.roomMessages[_roomId].total;

        if (!fetchingMessages && messagesLength < totalMessages) {
          store.dispatch(ReqeustRoomMessages(
            roomId: _roomId,
            token: store.state.chatState.user.token,
            userId: store.state.chatState.user.userId,
            offset: messagesLength,
          ));
        }
      }
    });

    KeyboardVisibilityNotification().addNewListener(
      onChange: (bool visible) {
        setState(() {
          isShowSuffixIcons = !visible && _messageController.text.length == 0;
        });
      },
    );
  }

  void _sendMessage(String opponentName) {
    if (_messageController.text != '') {
      var store = StoreProvider.of<AppState>(context);
      store.dispatch(SendMessage(
        opponentName: opponentName,
        roomId: _roomId,
        text: _messageController.text,
        token: store.state.chatState.user.token,
        userId: store.state.chatState.user.userId,
      ));
      _messageController.text = '';
    }
  }

  _choseImage(ImageSource source) async {
    final pickedFile = await ImagePicker().getImage(source: source, imageQuality: 50);

    if (pickedFile != null) {
      File file = File(pickedFile.path);

      final store = StoreProvider.of<AppState>(context);
      final String token = store.state.chatState.user.token;
      final String userId = store.state.chatState.user.userId;

      store.dispatch(SendFile(
        userId: userId,
        token: token,
        roomId: _roomId,
        file: file,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return new StoreConnector<AppState, ChatRoom>(
        onDispose: (store) {
          store.dispatch(RequestMarkRoomReed(
            roomId: _roomId,
            token: store.state.chatState.user.token,
            userId: store.state.chatState.user.userId,
          ));
        },
        converter: (store) => ChatRoom(
          messages: store.state.chatState.roomMessages.containsKey(_roomId)
              ? store.state.chatState.roomMessages[_roomId].messages
              : [],
          total: store.state.chatState.roomMessages.containsKey(_roomId)
              ? store.state.chatState.roomMessages[_roomId].total
              : 0,
          user: store.state.chatState.user,
          lastMessage: store.state.chatState.rooms[_roomId].lastMessage,
          opponentName: store.state.chatState.user.helpRoomId == _roomId
              ? store.state.chatState.user.helpRoomLogin
              : store.state.chatState.roomsNames[_roomId]?.opponentName,
          chatInfo: store.state.chatState.roomsNames[_roomId],
          isHelpChat: _roomId == store.state.chatState.user.helpRoomId,
        ),
        onInit: (store) {
          final store = StoreProvider.of<AppState>(context);
          final String token = store.state.chatState.user.token;
          final String userId = store.state.chatState.user.userId;
          store.dispatch(ReqeustRoomMessages(
            roomId: _roomId,
            token: token,
            userId: userId,
          ));
          store.dispatch(RequestMarkRoomReed(
            roomId: _roomId,
            token: token,
            userId: userId,
          ));
          if (store.state.chatState.roomsNames[_roomId] == null) {
            List<String> roomIds = [];
            store.state.chatState.rooms.forEach((roomId, room) => roomIds.add(roomId));
            store.dispatch(RequestRoomsInfo(roomIds));
          } else if (_roomId != store.state.chatState.user.helpRoomId) {
            store.dispatch(RequestRoomInfo(
              roomId: _roomId,
              token: store.state.chatState.user.token,
              userId: store.state.chatState.user.userId,
            ));
          }
        },
        onWillChange: (prevProps, props) {
          if (prevProps.lastMessage != props.lastMessage) {
            _scrollController.animateTo(
              _scrollController.position.minScrollExtent,
              duration: new Duration(
                milliseconds: 500,
              ),
              curve: Curves.ease,
            );
          }
          if (prevProps.chatInfo == null && props.chatInfo != null) {
            var store = StoreProvider.of<AppState>(context);
            store.dispatch(RequestRoomInfo(
              roomId: _roomId,
              token: store.state.chatState.user.token,
              userId: store.state.chatState.user.userId,
            ));
          }
        },
        builder: (context, ChatRoom props) {
          var vw = MediaQuery.of(context).size.width / 100;
          final inputBorder = OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: new BorderRadius.all(Radius.circular(7.65 * vw))
          );

          final DateTime now = DateTime.now();
          String roomIconUrl = !props.isHelpChat && props.chatInfo != null && props.chatInfo.companyPhotoUrl != null
              ? props.chatInfo.companyPhotoUrl
              : '';
          List<Message> messages = props.messages;
          // Приветственное сообщение
          if (messages.isEmpty) {
            messages = [
              Message(
                id: '',
                fileUrl: '',
                message: props.isHelpChat
                    ? 'Привет, я Ортус - твой личный помощник. Обращайся ко мне, буду рад помочь ${String.fromCharCode(9995)}'
                    : 'Приветствуем в чате компании. Будем рады помочь Вам',
                roomId: _roomId,
                date: DateTime.now().toLocal(),
                user: new MessageUser(
                  id: '',
                  name: props.opponentName,
                ),
              )
            ];
          }

          return Scaffold(
              appBar: CustomAppBar(
                title: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        height: kToolbarHeight,
                        padding: EdgeInsets.only(right: vw * 1),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SvgPicture.asset(
                              'assets/arrow-back-white.svg',
                              width: vw * 3,
                            ),
                            Container(
                              padding: EdgeInsets.only(left: vw * 2.2),
                              child: Text(
                                'Назад',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: vw * 3.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 3.9 * vw),
                      child: Row(
                        children: [
                          SizedBox(
                            height: 9.7 * vw,
                            width: 9.7 * vw,
                            child: ClipOval(
                              child: Container(
                                  color: const Color(0xff5B57C7),
                                  child: props.isHelpChat
                                      ? Image.asset('assets/chat/ortus.png')
                                      : (roomIconUrl == ''
                                      ? SvgPicture.asset('assets/chat/dude.svg')
                                      : Image.network(roomIconUrl)
                                  )
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(left: 2.2 * vw),
                            child: Container(
                              width: 55 * vw,
                              child: Text(
                                props.isHelpChat
                                    ? 'Ортус'
                                    : (props.chatInfo != null ? props.chatInfo.companyName : ''),
                                overflow: TextOverflow.fade,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 5 * vw,
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
                automaticallyImplyLeading: false,
                appBarContainerColor: const Color(0xffEFEBE6),
              ),
              backgroundColor: const Color(0xffEFEBE6),
              body: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
                        child: ListView.builder(
                          reverse: true,
                          controller: _scrollController,
                          itemBuilder: (context, index) {
                            Message message = messages[index];
                            Message nextMessage;
                            if (messages.asMap().containsKey(index + 1)) {
                              nextMessage = messages[index + 1];
                            }

                            String date;

                            if (nextMessage == null || (nextMessage != null && DateFormat('D').format(message.date) != DateFormat('D').format(nextMessage.date))) {
                              if (DateFormat('D').format(now) == DateFormat('D').format(message.date)) {
                                date = 'Сегодня';
                              } else if (int.parse(DateFormat('D').format(now)) - 1 == int.parse(DateFormat('D').format(message.date))) {
                                date = 'Вчера';
                              } else {
                                date = DateFormat('dd MMMM yyyy Г.').format(message.date);
                              }
                            }
                            bool isDrawTriangle = date != null || nextMessage == null || (nextMessage != null && message.user.id != nextMessage.user.id);

                            return Column(
                              children: [
                                if (date != null)
                                  Padding(
                                    padding: EdgeInsets.only(
                                        top: 3.2 * vw,
                                        bottom: 3.6 * vw
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                          borderRadius: BorderRadius.all(Radius.circular(1.7 * vw)),
                                          color: const Color(0xffD6EAF7),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xffDBD7D3),
                                              offset: Offset(0, 0.28 * vw),
                                            )
                                          ]
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(1.9 * vw),
                                        child: Text(
                                          date.toUpperCase(),
                                          style: TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: 3.6 * vw,
                                            color: const Color(0xff747474),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: (nextMessage != null && message.user.id == nextMessage.user.id) ? 0.84 * vw : 2.4 * vw,
                                    left: 4.6 * vw,
                                    right: message.user.id == props.user.userId && !isDrawTriangle ? 4.6 * vw : 2.7 * vw,
                                  ),
                                  child: Stack(
                                    overflow: Overflow.visible,
                                    children: [
                                      Row(
                                          mainAxisAlignment: message.user.id == props.user.userId ? MainAxisAlignment.end : MainAxisAlignment.start,
                                          children: [
                                            if (message.user.id == props.user.userId)
                                              SizedBox(width: 20 * vw,),
                                            Flexible(
                                              child: Row(
                                                mainAxisAlignment: message.user.id == props.user.userId ? MainAxisAlignment.end : MainAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  Flexible(
                                                    child: Container(
                                                        padding: EdgeInsets.all(2.2 * vw),
                                                        decoration: BoxDecoration(
                                                            color: message.user.id == props.user.userId
                                                                ? const Color(0xffE1FFC8)
                                                                : Colors.white,
                                                            borderRadius: BorderRadius.only(
                                                              bottomLeft: Radius.circular(1.4 * vw),
                                                              bottomRight: Radius.circular(1.4 * vw),
                                                              topLeft: Radius.circular(isDrawTriangle && message.user.id != props.user.userId ? 0 : 1.4 * vw),
                                                              topRight: Radius.circular(isDrawTriangle && message.user.id == props.user.userId ? 0 : 1.4 * vw),
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: const Color(0xffDBD7D3),
                                                                offset: Offset(0, 0.28 * vw),
                                                              )
                                                            ]
                                                        ),
                                                        child: Stack(
                                                          children: <Widget>[
                                                            Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: <Widget>[
                                                                Flexible(
                                                                    child: Container(
                                                                        child: Column(
                                                                          mainAxisSize: MainAxisSize.min,
                                                                          crossAxisAlignment: CrossAxisAlignment.end,
                                                                          children: <Widget>[
                                                                            if (message.fileUrl.length == 0)
                                                                              RichText(
                                                                                  text: TextSpan(
                                                                                      text: message.message,
                                                                                      style: TextStyle(
                                                                                        color: const Color(0xff102008),
                                                                                        fontSize: 4.4 * vw,
                                                                                        fontFamily: 'Roboto',
                                                                                        height: 1.3,
                                                                                      ),
                                                                                      children: [
                                                                                        TextSpan(
                                                                                            text: DateFormat('HH:mm').format(message.date),
                                                                                            style: TextStyle(color: Colors.transparent)
                                                                                        ),
                                                                                      ]
                                                                                  )
                                                                              ),
                                                                            if (message.fileUrl.length > 0)
                                                                              Image.network(
                                                                                message.fileUrl,
                                                                                loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent loadingProgress) {
                                                                                  return loadingProgress == null
                                                                                      ? child
                                                                                      : Center(child: CircularProgressIndicator(),
                                                                                  );
                                                                                },
                                                                              ),
                                                                            if (message.fileUrl.length > 0)
                                                                              SizedBox(
                                                                                height: 5 * vw,
                                                                              )
                                                                          ],
                                                                        )
                                                                    )
                                                                ),
                                                              ],
                                                            ),
                                                            Positioned(
                                                              bottom: 0,
                                                              right: 0,
                                                              child: Container(
                                                                child: Text(
                                                                  DateFormat('HH:mm').format(message.date),
                                                                  textAlign: TextAlign.end,
                                                                  style: TextStyle(
                                                                    color: const Color(0xff9C9E9C),
                                                                    fontSize: 3.3 * vw,
                                                                    height: 1,
                                                                    fontFamily: 'Roboto',
                                                                  ),
                                                                ),
                                                              ),
                                                            )
                                                          ],
                                                        )
                                                    ),
                                                  ),
                                                  if (isDrawTriangle && message.user.id == props.user.userId)
                                                    CustomPaint(
                                                        size: Size(2.2 * vw, 2.8 * vw),
                                                        painter: MessageTriangle(
                                                          color: const Color(0xffE1FFC8),
                                                          side: TriangleSide.right,
                                                        )
                                                    )
                                                ],
                                              ),
                                            ),
                                            if (message.user.id != props.user.userId)
                                              SizedBox(width: 20 * vw,),
                                          ]
                                      ),
                                      if (isDrawTriangle && message.user.id != props.user.userId)
                                        Positioned(
                                          left: -2.2 * vw,
                                          top: 0,
                                          child: CustomPaint(
                                              size: Size(2.2 * vw, 2.8 * vw),
                                              painter: MessageTriangle(
                                                color: Colors.white,
                                                side: TriangleSide.left,
                                              )
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                          itemCount: messages.length,
                        ),
                      ),
                    ),
                    Container(
                      width: 100 * vw,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 2.8 * vw,
                          bottom: 2 * vw,
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                left: 1.1 * vw,
                              ),
                              child: Container(
                                width: 82.8 * vw,
                                decoration: BoxDecoration(
                                    borderRadius: new BorderRadius.all(
                                        Radius.circular(7.65 * vw)
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xffDBD7D3),
                                        offset: Offset(0, 0.28 * vw),
                                      )
                                    ]
                                ),
                                child: Stack(
                                  children: [
                                    TextField(
                                      keyboardType: TextInputType.multiline,
                                      maxLines: 5,
                                      minLines: 1,
                                      controller: _messageController,
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 5 * vw,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Введите текст',
                                        hintStyle: TextStyle(color: const Color(0xFFC3C2C3)),
                                        contentPadding: EdgeInsets.only(
                                          left: 4.17 * vw,
                                        ),
                                        fillColor: Colors.white,
                                        filled: true,
                                        enabledBorder: inputBorder,
                                        focusedBorder: inputBorder,
                                      ),
                                    ),
                                    if (isShowSuffixIcons)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 21.7 * vw,
                                          child: Row(
                                            children: <Widget>[
                                              GestureDetector(
                                                behavior: HitTestBehavior.opaque,
                                                onTap: () => _choseImage(ImageSource.gallery),
                                                child: Container(
                                                  height: 12.5 * vw,
                                                  width: 10.85 * vw,
                                                  alignment: Alignment.centerLeft,
                                                  child: SvgPicture.asset(
                                                    'assets/chat/clip.svg',
                                                    width: 5.8 * vw,
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                behavior: HitTestBehavior.opaque,
                                                onTap: () => _choseImage(ImageSource.camera),
                                                child: Container(
                                                  height: 12.5 * vw,
                                                  width: 10.85 * vw,
                                                  alignment: Alignment.centerLeft,
                                                  child: SvgPicture.asset(
                                                    'assets/chat/camera.svg',
                                                    width: 6.1 * vw,
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(
                                left: 1.7 * vw,
                              ),
                              child: GestureDetector(
                                onTap: () => _sendMessage(props.opponentName),
                                child: ClipOval(
                                  child: Container(
                                    width: 13.05 * vw,
                                    height: 13.05 * vw,
                                    color: const Color(0xff6B67DF),
                                    child: SvgPicture.asset(
                                      'assets/chat/send.svg',
                                      width: 13.05 * vw,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
          );
        }
    );
  }
}
