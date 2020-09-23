import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:nfc_st25/nfc_st25.dart';
import 'package:nfc_st25/utils/nfc_st25_tag.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Test",
      home: ExamplePage(),
    );
  }
}

class ExamplePage extends StatefulWidget {
  @override
  _ExamplePage createState() => _ExamplePage();
}

class _ExamplePage extends State<ExamplePage> {
  String _platformVersion = 'Unknown';
  bool nfcAvailability = false;
  St25Tag lastTag;
  bool loading = false;
  Uint8List last_msg;
  String logs = "";
  MailBox mailBoxInfo;
  List<dynamic> commands = [
    [0, 1, 0],
    [0, 1, 1],
    [0, 1, 2],
  ];

  StreamSubscription<St25Tag> _subscription;

  // needed for snackbar
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    initPlatformState();
    NfcSt25.nfcAvailability.then((value) => {
          setState(() {
            nfcAvailability = value;
          })
        });
    startListen();
  }

  startListen() {
    _subscription = NfcSt25.startReading().listen((tag) {
      log("TAG FOUND: " + tag.uid);
      //showSnackBar("Tag found " + tag.uid, false);
      setState(() {
        lastTag = tag;
        mailBoxInfo = tag.mailBox;
      });
    }, onError: (e) => log(e.toString()));
  }

  clearLogs() {
    setState(() {
      logs = "";
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await NfcSt25.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  void log(String s) {
    print(s);
    setState(() {
      logs += s + '\n\n';
    });
  }

  Future<void> readMailBoxMsg() async {
    int cnt = 0;
    Uint8List msg;
    while (cnt < 5) {
      try {
        log("Read try #" + cnt.toString());
        if (cnt > 0) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
        msg = await NfcSt25.readMailbox;
        last_msg = msg;
        log("READ MSG (" + msg.length.toString() + ") : " + msg.toString());
        break;
      } catch (e) {
        log("failed read  -> " + e.toString());
        cnt++;
      }
    }

    setState(() {
      last_msg = msg;
    });
  }

  Future<void> resetMailBox() async {
    try {
      await NfcSt25.resetMailBox();
      log("SUCCESSFUL RESET MAILBOX");
    } catch (e) {
      log("Error reset mailbox" + e.toString());
      //showSnackBar("failed to reset mailbox -> " + e.toString(), true);
    }
  }

  Future<void> getMailBoxInfo() async {
    MailBox mailbox;
    try {
      mailbox = await NfcSt25.getMailBoxInfo();
      //showSnackBar("SUCCESSFUL RESET MAILBOX", false);
      log("GET MAILBOX INFO :\n" + mailbox.toString());
      setState(() {
        mailBoxInfo = mailbox;
      });
    } catch (e) {
      setState(() {
        mailBoxInfo = null;
      });
      log("ERRRRORRR get mailbox info" + e.toString());
      //showSnackBar("failed to reset mailbox -> " + e.toString(), true);
    }
  }

  Future<void> writeMailBoxMsg(List<int> data) async {
    Uint8List msg = Uint8List.fromList(data);
    try {
      await NfcSt25.writeMailBoxByte(msg);
      log("SUCCESSFUL SENT " + msg.toString());
    } catch (e) {
      log("failed to write mailbox -> " + e.toString());
    }
  }

  showSnackBar(String text, bool error) {
    final snackBar = SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.red : null,
      action: SnackBarAction(
        label: 'Ok',
        onPressed: () {
          // Some code to undo the change.
        },
      ),
    );

    _scaffoldKey.currentState.showSnackBar(snackBar);
  }

  Widget _tapCard() {
    return Container(
      padding: EdgeInsets.all(16),
      child: nfcAvailability
          ? Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Expanded(
                      child: Card(
                          child: Container(
                              height: 300,
                              padding: EdgeInsets.all(8),
                              child: Stack(children: [
                                Positioned(
                                    top: 0,
                                    left: 0,
                                    child: Text(
                                      "Please tap a tag !",
                                      style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold),
                                    )),
                                Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Icon(
                                      Icons.nfc,
                                      size: 128,
                                      color: Colors.black38,
                                    ))
                              ]))))
                ])
          : Text("Nfc unavailable."),
    );
  }

  Widget _myAppBar() {
    if (lastTag == null)
      return AppBar(
        title: const Text('ST25 nfc plugin example'),
      );

    return AppBar(
      title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lastTag.name),
            Text(lastTag.uid,
                style: TextStyle(color: Colors.white, fontSize: 14.0))
          ]),
      actions: [
        IconButton(icon: Icon(Icons.cancel), onPressed: () => invalidateAll())
      ],
    );
  }

  invalidateAll() {
    log("INVALIDATE DATA");
    setState(() {
      lastTag = null;
      logs = "";
      mailBoxInfo = null;
    });
  }

  void showWriteDialog() {
    // flutter defined function
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text("Select command to send"),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              children: commands
                  .map((e) => RaisedButton(
                        onPressed: () {
                          writeMailBoxMsg(e);
                          Navigator.of(context).pop();
                        },
                        child: Text(e.toString()),
                      ))
                  .toList()),
          actions: <Widget>[
            // usually buttons at the bottom of the dialog
            new FlatButton(
              child: new Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      key: _scaffoldKey,
      appBar: _myAppBar(),
      body: lastTag == null
          ? _tapCard()
          : Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Description: " + lastTag.description),
                    Text("Memory size: " + lastTag.memorySize.toString()),
                    SizedBox(height: 25),
                    Text("MAILBOX INFO"),
                    Container(
                      child: Text(mailBoxInfo.toString()),
                      color: Colors.grey,
                    ),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RaisedButton(
                            child: Text("MAILBOX INFO"),
                            onPressed: () => getMailBoxInfo(),
                          ),
                          RaisedButton(
                            child: Text("RESET MAILBOX"),
                            onPressed: () => resetMailBox(),
                          ),
                        ]),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RaisedButton(
                              child: Text("READ MAILBOX"),
                              onPressed: () => readMailBoxMsg()
                              /* lastTag.mailBox.mailboxEnabled == false
                                    ? null
                                    : readMailBoxMsg(), */
                              ),
                          RaisedButton(
                              child: Text("WRITE MAILBOX"),
                              onPressed: () =>
                                  lastTag.mailBox.mailboxEnabled == false
                                      ? null
                                      : showWriteDialog() //writeMailBoxMsg(),
                              ),
                        ]),
                    SizedBox(height: 25),
                    Row(
                      children: [
                        Text("LOGS"),
                        IconButton(
                          onPressed: () => clearLogs(),
                          icon: Icon(Icons.clear),
                        )
                      ],
                    ),
                    Container(
                        height: 300,
                        color: Colors.grey,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Text(logs),
                        )),
                  ],
                ),
              ),
            ),
    ));
  }
}
