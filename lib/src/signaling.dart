
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class P2PSignaler {
  RTCPeerConnection? _pc;
  RTCDataChannel? _dc;

  final _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:global.stun.twilio.com:3478?transport=udp'}
    ]
  };

  Future<void> init({required void Function(String) onText}) async {
    _pc = await createPeerConnection(_config);

    _pc!.onIceCandidate = (c) {
      // ICE candidates get baked into SDP strings returned by createOffer/Answer with trickle=false by default on mobile
    };

    _pc!.onDataChannel = (channel) {
      _dc = channel;
      _dc!.onMessage = (msg) {
        onText(msg.text);
      };
    };
  }

  Future<String> createOfferAndDataChannel({required void Function(String) onText}) async {
    _dc = await _pc!.createDataChannel('chat', RTCDataChannelInit()..ordered = true);
    _dc!.onMessage = (msg) => onText(msg.text);
    final offer = await _pc!.createOffer({'offerToReceiveAudio': false, 'offerToReceiveVideo': false});
    await _pc!.setLocalDescription(offer);
    return jsonEncode(offer.toMap());
  }

  Future<void> setRemoteDescriptionFromJson(String sdpJson) async {
    final m = jsonDecode(sdpJson);
    final desc = RTCSessionDescription(m["sdp"], m["type"]);
    await _pc!.setRemoteDescription(desc);
  }

  Future<String> createAnswer() async {
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    return jsonEncode(answer.toMap());
  }

  void send(String text) {
    _dc?.send(RTCDataChannelMessage(text));
  }

  void dispose() {
    _dc?.close();
    _pc?.close();
  }
}
