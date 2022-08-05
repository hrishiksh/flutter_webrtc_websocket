import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

void main() {
  runApp(
    const MaterialApp(
      home: Homepage(),
    ),
  );
}

class Homepage extends StatefulWidget {
  const Homepage({Key? key}) : super(key: key);

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final RTCVideoRenderer localVideo = RTCVideoRenderer();
  final RTCVideoRenderer remoteVideo = RTCVideoRenderer();
  late final MediaStream localStream;
  late final WebSocketChannel channel;
  MediaStream? remoteStream;
  RTCPeerConnection? peerConnection;

  // Connecting with websocket Server
  void connectToServer() {
    try {
      channel = WebSocketChannel.connect(Uri.parse("ws://localhost:8080"));

      // Listening to the socket event as a stream
      channel.stream.listen(
        (message) async {
          // Decoding message
          Map<String, dynamic> decoded = jsonDecode(message);

          // If the client receive an offer
          if (decoded["event"] == "offer") {
            // Set the offer SDP to remote description
            await peerConnection?.setRemoteDescription(
              RTCSessionDescription(
                decoded["data"]["sdp"],
                decoded["data"]["type"],
              ),
            );

            // Create an answer
            RTCSessionDescription answer = await peerConnection!.createAnswer();

            // Set the answer as an local description
            await peerConnection!.setLocalDescription(answer);

            // Send the answer to the other peer
            channel.sink.add(
              jsonEncode(
                {
                  "event": "answer",
                  "data": answer.toMap(),
                },
              ),
            );
          }
          // If client receive an Ice candidate from the peer
          else if (decoded["event"] == "ice") {
            // It add to the RTC peer connection
            peerConnection?.addCandidate(RTCIceCandidate(
                decoded["data"]["candidate"],
                decoded["data"]["sdpMid"],
                decoded["data"]["sdpMLineIndex"]));
          }
          // If Client recive an reply of their offer as answer

          else if (decoded["event"] == "answer") {
            await peerConnection?.setRemoteDescription(RTCSessionDescription(
                decoded["data"]["sdp"], decoded["data"]["type"]));
          }
          // If no condition fulfilled? printout the message
          else {
            print(decoded);
          }
        },
      );
    } catch (e) {
      throw "ERROR $e";
    }
  }

  // STUN server configuration
  Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302'
        ]
      }
    ]
  };

  // This must be done as soon as app loads
  void initialization() async {
    // Getting video feed from the user camera
    localStream = await navigator.mediaDevices
        .getUserMedia({'video': true, 'audio': false});

    // Set the local video to display
    localVideo.srcObject = localStream;
    // Initializing the peer connecion
    peerConnection = await createPeerConnection(configuration);
    setState(() {});
    // Adding the local media to peer connection
    // When connection establish, it send to the remote peer
    localStream.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream);
    });
  }

  void makeCall() async {
    // Creating a offer for remote peer
    RTCSessionDescription offer = await peerConnection!.createOffer();

    // Setting own SDP as local description
    await peerConnection?.setLocalDescription(offer);

    // Sending the offer
    channel.sink.add(
      jsonEncode(
        {"event": "offer", "data": offer.toMap()},
      ),
    );
  }

  // Help to debug our code
  void registerPeerConnectionListeners() {
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE gathering state changed: $state');
    };

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      channel.sink.add(
        jsonEncode({"event": "ice", "data": candidate.toMap()}),
      );
    };

    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state change: $state');
    };

    peerConnection?.onSignalingState = (RTCSignalingState state) {
      print('Signaling state change: $state');
    };

    peerConnection?.onTrack = ((tracks) {
      tracks.streams[0].getTracks().forEach((track) {
        remoteStream?.addTrack(track);
      });
    });

    // When stream is added from the remote peer
    peerConnection?.onAddStream = (MediaStream stream) {
      remoteVideo.srcObject = stream;
      setState(() {});
    };
  }

  @override
  void initState() {
    connectToServer();
    localVideo.initialize();
    remoteVideo.initialize();
    initialization();
    super.initState();
  }

  @override
  void dispose() {
    peerConnection?.close();
    localVideo.dispose();
    remoteVideo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Flutter webrtc websocket"),
      ),
      body: Stack(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: RTCVideoView(
              remoteVideo,
              mirror: false,
            ),
          ),
          Positioned(
            right: 10,
            child: SizedBox(
              height: 200,
              width: 200,
              child: RTCVideoView(
                localVideo,
                mirror: true,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            backgroundColor: Colors.amberAccent,
            onPressed: () => registerPeerConnectionListeners(),
            child: const Icon(Icons.settings_applications_rounded),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            backgroundColor: Colors.green,
            onPressed: () => {makeCall()},
            child: const Icon(Icons.call_outlined),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            backgroundColor: Colors.redAccent,
            onPressed: () {
              channel.sink.add(
                jsonEncode(
                  {
                    "event": "msg",
                    "data": "Hi this is an offer",
                  },
                ),
              );
            },
            child: const Icon(
              Icons.call_end_outlined,
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
