import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mystore/firebaseService/FirebaseService.dart';
import 'package:mystore/models/User.dart';
import 'package:mystore/profile/components/profile_menu.dart';
import 'package:mystore/profile/components/profile_pic.dart';
import 'package:mystore/utils/firebase.dart';

import '../../SizeConfig.dart';
import '../../constants.dart';
import 'edit_profile.dart';

class Body extends StatefulWidget {
  final profileId;

  const Body({Key key, this.profileId}) : super(key: key);
  @override
  _BodyState createState() => _BodyState();
}

class _BodyState extends State<Body> {
  final auth = FirebaseService();
  User user;
  bool isLoading = false;
  int postCount = 0;
  int followersCount = 0;
  int followingCount = 0;
  bool isToggle = true;
  bool isFollowing = false;
  UserModel users;
  UserModel user1;
  final DateTime timestamp = DateTime.now();
  ScrollController controller = ScrollController();

  currentUserId() {
    return firebaseAuth.currentUser?.uid;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            floating: false,
            toolbarHeight: 4.0,
            collapsedHeight: 6.0,
            expandedHeight: SizeConfig.screenHeight,
            flexibleSpace: FlexibleSpaceBar(
              background: StreamBuilder(
                stream: usersRef.doc(widget.profileId).snapshots(),
                builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                  if (snapshot.hasData) {
                    user1 = UserModel.fromJson(snapshot.data.data());
                    return displayUserInfo();
                  }
                  return Container();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildText(String text) => Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 24, color: Colors.white),
        ),
      );

  buildCount(String label, int count) {
    return Column(
      children: <Widget>[
        Text(
          count.toString(),
          style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w900,
              fontFamily: 'Ubuntu-Regular'),
        ),
        SizedBox(height: 3.0),
        Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              fontFamily: 'Ubuntu-Regular'),
        )
      ],
    );
  }

  buildProfileButton(user) {
    //if isMe then display "edit profile"
    bool isMe = widget.profileId == firebaseAuth.currentUser.uid;
    if (isMe) {
      return FlatButton(
        child: Text(
          "Change Bio =>",
          style: TextStyle(color: white),
        ),
        onPressed: () {
          /*
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingScreen(
                  users: user1,
                ),
              ));*/
        },
      );
      //if you are already following the user then "unfollow"
    } else if (isFollowing) {
      return buildButton(
        text: "Unfollow",
        function: handleUnfollow,
      );
      //if you are not following the user then "follow"
    } else if (!isFollowing) {
      return buildButton(
        text: "Follow",
        function: handleFollow,
      );
    }
  }

  handleUnfollow() async {
    DocumentSnapshot doc = await usersRef.doc(currentUserId()).get();
    users = UserModel.fromJson(doc.data());
    setState(() {
      isFollowing = false;
    });
    //remove follower
    followersRef
        .doc(widget.profileId)
        .collection('userFollowers')
        .doc(currentUserId())
        .get()
        .then((doc) {
      if (doc.exists) {
        doc.reference.delete();
      }
    });
    //remove following
    followingRef
        .doc(currentUserId())
        .collection('userFollowing')
        .doc(widget.profileId)
        .get()
        .then((doc) {
      if (doc.exists) {
        doc.reference.delete();
      }
    });
    //remove from notifications feeds
    notificationRef
        .doc(widget.profileId)
        .collection('notifications')
        .doc(currentUserId())
        .get()
        .then((doc) {
      if (doc.exists) {
        doc.reference.delete();
      }
    });
  }

  handleFollow() async {
    DocumentSnapshot doc = await usersRef.doc(currentUserId()).get();
    users = UserModel.fromJson(doc.data());
    setState(() {
      isFollowing = true;
    });
    //updates the followers collection of the followed user
    followersRef
        .doc(widget.profileId)
        .collection('userFollowers')
        .doc(currentUserId())
        .set({});
    //updates the following collection of the currentUser
    followingRef
        .doc(currentUserId())
        .collection('userFollowing')
        .doc(widget.profileId)
        .set({});
    //update the notification feeds
    notificationRef
        .doc(widget.profileId)
        .collection('notifications')
        .doc(currentUserId())
        .set({
      "type": "follow",
      "ownerId": widget.profileId,
      "username": users.username,
      "userId": users.id,
      "userDp": users.photoUrl,
      "timestamp": timestamp,
    });
  }

  buildButton({String text, Function function}) {
    return Center(
      child: GestureDetector(
        onTap: function,
        child: Container(
          height: 40.0,
          width: 200.0,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5.0),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Colors.white,
                Colors.white,
              ],
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }

  Widget displayUserInfo() {
    return Container(
      padding: EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 40),
          StreamBuilder(
            stream: usersRef.doc(widget.profileId).snapshots(),
            builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
              if (snapshot.hasData) {
                UserModel user = UserModel.fromJson(snapshot.data.data());
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(width: 20.0),
                    ProfilePic(
                      image: firebaseAuth.currentUser.uid == user.id
                          ? auth.getProfileImage()
                          : user.photoUrl,
                    ),
                    SizedBox(width: 10.0),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 5),
                        Text("${user.username ?? 'Anonymous'}",
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.black,
                              fontFamily: "SFProDisplay-Bold",
                              fontWeight: FontWeight.bold,
                            )),
                        SizedBox(height: 5),
                        Text("${user.country.isEmpty ? '' : user.country}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                              fontFamily: "SFProDisplay-Light",
                              fontWeight: FontWeight.normal,
                            )),
                      ],
                    ),
                  ],
                );
              }
              return Container();
            },
          ),
          SizedBox(height: 20),
          ProfileMenu(
            text: "Edit Profile",
            icon: "assets/icons/User Icon.svg",
            press: () => {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditProfile(
                    user: user1,
                  ),
                ),
              )
            },
          ),
          ProfileMenu(
            text: "My orders",
            icon: "assets/icons/Shop Icon.svg",
            press: () {},
          ),
          ProfileMenu(
            text: "Purchasing History",
            icon: "assets/icons/Parcel.svg",
            press: () {},
          ),
          ProfileMenu(
            text: "Recently viewed",
            icon: "assets/icons/Question mark.svg",
            press: () {},
          ),
          ProfileMenu(
            text: "To be reviewed",
            icon: "assets/icons/Plus Icon.svg",
            press: () {},
          ),
          ProfileMenu(
            text: "Unpaid Orders",
            icon: "assets/icons/Bill Icon.svg",
            press: () {},
          ),
        ],
      ),
    );
  }
}
