import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:mystore/Inbox/components/conversation_view_model.dart';
import 'package:mystore/components/indicators.dart';
import 'package:mystore/constants.dart';
import 'package:mystore/firebaseService/FirebaseService.dart';
import 'package:mystore/models/User.dart';
import 'package:mystore/models/enum/message_type.dart';
import 'package:mystore/models/new_message_system.dart';
import 'package:mystore/profile/components/user_view_model.dart';
import 'package:mystore/utils/firebase.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'chat_bubble.dart';

class Conversation extends StatefulWidget {
  final String userId;
  final String chatId;

  const Conversation({@required this.userId, @required this.chatId});

  @override
  _ConversationState createState() => _ConversationState();
}

class _ConversationState extends State<Conversation> {
  FocusNode focusNode = FocusNode();
  ScrollController scrollController = ScrollController();
  TextEditingController messageController = TextEditingController();
  bool isFirst = false;
  String chatId;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(() {
      focusNode.unfocus();
    });
    if (widget.chatId == 'newChat') {
      isFirst = true;
    }
    chatId = widget.chatId;

    messageController.addListener(() {
      if (focusNode.hasFocus && messageController.text.isNotEmpty) {
        setTyping(true);
      } else if (!focusNode.hasFocus ||
          (focusNode.hasFocus && messageController.text.isEmpty)) {
        setTyping(false);
      }
    });
  }

  setTyping(typing) {
    UserViewModel viewModel = Provider.of<UserViewModel>(context);
    viewModel.setUser();
    var user = Provider.of<UserViewModel>(context, listen: true).user;
    Provider.of<ConversationViewModel>(context, listen: false)
        .setUserTyping(widget.chatId, user, typing);
  }

  @override
  Widget build(BuildContext context) {
    UserViewModel viewModel = Provider.of<UserViewModel>(context);
    viewModel.setUser();
    var user = Provider.of<UserViewModel>(context, listen: true).user;
    return Consumer<ConversationViewModel>(
        builder: (BuildContext context, viewModel, Widget child) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        key: viewModel.scaffoldKey,
        appBar: AppBar(
          leading: GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Icon(
                CupertinoIcons.back,
                color: Colors.black,
              )),
          elevation: 4.0,
          titleSpacing: 0,
          title: buildUserName(),
        ),
        body: Container(
          decoration: new BoxDecoration(
            gradient: new LinearGradient(
                colors: [
                  Colors.white,
                  Colors.red[900],
                ],
                begin: const FractionalOffset(0.3, 0.4),
                end: const FractionalOffset(0.5, 1.0),
                stops: [0.0, 1.0],
                tileMode: TileMode.clamp),
          ),
          height: MediaQuery.of(context).size.height,
          child: Column(
            children: [
              Flexible(
                child: StreamBuilder(
                  stream: messageListStream(chatId),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      List messages = snapshot.data.documents;
                      if (widget.chatId != 'newChat') {
                        viewModel.setReadCount(
                            widget.chatId, user, messages.length);
                      }
                      return ListView.builder(
                        controller: scrollController,
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        itemCount: messages.length,
                        reverse: true,
                        itemBuilder: (BuildContext context, int index) {
                          Message message = Message.fromJson(
                              messages.reversed.toList()[index].data());
                          return ChatBubble(
                              message: '${message.content}',
                              time: message?.time,
                              isMe: message?.senderUid == user?.uid,
                              type: message?.type);
                        },
                      );
                    } else {
                      return Center(child: circularProgress(context));
                    }
                  },
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: BottomAppBar(
                  color: Colors.red[700],
                  elevation: 12.0,
                  child: Container(
                    constraints: BoxConstraints(maxHeight: 120.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            CupertinoIcons.photo_on_rectangle,
                            color: white,
                          ),
                          onPressed: () => showPhotoOptions(viewModel, user),
                        ),
                        Flexible(
                          child: TextField(
                            controller: messageController,
                            focusNode: focusNode,
                            style: TextStyle(
                              fontSize: 16.0,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.all(10.0),
                              enabledBorder: InputBorder.none,
                              border: InputBorder.none,
                              hintText: "Type your message",
                              hintStyle: TextStyle(
                                color: white,
                              ),
                            ),
                            maxLines: null,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Feather.send,
                            color: white,
                          ),
                          onPressed: () {
                            if (messageController.text.isNotEmpty) {
                              sendMessage(viewModel, user);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      );
    });
  }

  _buildOnlineText(
    var user,
    bool typing,
  ) {
    if (user.isOnline) {
      if (typing) {
        return "typing...";
      } else {
        return "online";
      }
    } else {
      return 'last seen ${timeago.format(user.lastSeen.toDate())}';
    }
  }

  buildUserName() {
    return StreamBuilder(
      stream: usersRef.doc('${widget.userId}').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          DocumentSnapshot documentSnapshot = snapshot.data;
          UserModel user = UserModel.fromJson(documentSnapshot.data());
          return InkWell(
            child: Row(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(left: 10.0, right: 10.0),
                  child: Hero(
                    tag: user.email,
                    child: CircleAvatar(
                      radius: 25.0,
                      backgroundImage: NetworkImage(
                          firebaseAuth.currentUser.photoURL ??
                              FirebaseService().getProfileImage()),
                    ),
                  ),
                ),
                SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${user.username}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.0,
                        ),
                      ),
                      SizedBox(height: 5.0),
                      StreamBuilder(
                        stream: chatRef.doc('${widget.chatId}').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            DocumentSnapshot snap = snapshot.data;
                            Map data = snap.data() ?? {};
                            Map usersTyping = data['typing'] ?? {};
                            return Text(
                              _buildOnlineText(
                                user,
                                usersTyping[widget.userId] ?? false,
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 11,
                              ),
                            );
                          } else {
                            return SizedBox();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ), /*
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      profileUID: user.id,
                    ),
                  ));
            },*/
          );
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  showPhotoOptions(ConversationViewModel viewModel, var user) {
    showModalBottomSheet(
      backgroundColor: Colors.redAccent,
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(10.0),
        ),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: Text(
                "Camera",
                style: TextStyle(color: white),
              ),
              onTap: () {
                sendMessage(viewModel, user, imageType: 0, isImage: true);
              },
            ),
            ListTile(
              title: Text(
                "Gallery",
                style: TextStyle(color: white),
              ),
              onTap: () {
                sendMessage(viewModel, user, imageType: 1, isImage: true);
              },
            ),
          ],
        );
      },
    );
  }

  sendMessage(ConversationViewModel viewModel, var user,
      {bool isImage = false, int imageType}) async {
    String msg;
    if (isImage) {
      msg = await viewModel.pickImage(
        source: imageType,
        context: context,
        chatId: widget.chatId,
      );
    } else {
      msg = messageController.text.trim();
      messageController.clear();
    }

    Message message = Message(
      content: '$msg',
      senderUid: user?.uid,
      type: isImage ? MessageType.IMAGE : MessageType.TEXT,
      time: Timestamp.now(),
    );

    if (msg.isNotEmpty) {
      if (isFirst) {
        print("FIRST");
        String id = await viewModel.sendFirstMessage(widget.userId, message);
        setState(() {
          isFirst = false;
          chatId = id;
        });
      } else {
        viewModel.sendMessage(
          widget.chatId,
          message,
        );
      }
    }
  }

  Stream<QuerySnapshot> messageListStream(String documentId) {
    return chatRef
        .doc(documentId)
        .collection('messages')
        .orderBy('time')
        .snapshots();
  }
}
