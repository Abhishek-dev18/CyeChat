
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

class SessionModel extends ChangeNotifier {
  SessionModel({String? initialName}) : displayName = initialName {
    _generateIdentity();
  }

  String? displayName;
  SimpleKeyPair? _identityKey; // X25519 key
  SimplePublicKey? _identityPub;

  // Current session key for symmetric encryption
  SecretKey? _sessionKey;

  List<Message> messages = [];

  Future<void> _generateIdentity() async {
    final algorithm = X25519();
    _identityKey = await algorithm.newKeyPair();
    _identityPub = await _identityKey!.extractPublicKey();
  }

  String get publicKeyBase64 => base64Encode(_identityPub!.bytes);

  Future<void> startSessionWithPeerPubKey(String peerPubKeyB64) async {
    final algorithm = X25519();
    final peerPub = SimplePublicKey(base64Decode(peerPubKeyB64), type: KeyPairType.x25519);
    final shared = await algorithm.sharedSecretKey(keyPair: _identityKey!, remotePublicKey: peerPub);
    // Derive a symmetric key (use HKDF)
    final hkdf = Hkdf(hmac: Hmac.sha256());
    _sessionKey = await hkdf.deriveKey(secretKey: shared, info: utf8.encode("threads-p2p-chat"), outputLength: 32);
    notifyListeners();
  }

  bool get hasSession => _sessionKey != null;

  Future<EncryptedPayload> encrypt(String plaintext) async {
    final algo = Chacha20.poly1305Aead();
    final nonce = algo.newNonce();
    final secretBox = await algo.encrypt(utf8.encode(plaintext), secretKey: _sessionKey!, nonce: nonce);
    return EncryptedPayload(
      nonceB64: base64Encode(secretBox.nonce),
      cipherB64: base64Encode(secretBox.cipherText),
      macB64: base64Encode(secretBox.mac.bytes),
      sender: displayName ?? 'me',
      ts: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<String> decrypt(EncryptedPayload p) async {
    final algo = Chacha20.poly1305Aead();
    final box = SecretBox(
      base64Decode(p.cipherB64),
      nonce: base64Decode(p.nonceB64),
      mac: Mac(base64Decode(p.macB64)),
    );
    final clear = await algo.decrypt(box, secretKey: _sessionKey!);
    return utf8.decode(clear);
  }

  void addMessage(Message m) {
    messages.add(m);
    notifyListeners();
  }
}

class EncryptedPayload {
  final String nonceB64;
  final String cipherB64;
  final String macB64;
  final String sender;
  final int ts;
  EncryptedPayload({required this.nonceB64, required this.cipherB64, required this.macB64, required this.sender, required this.ts});

  Map<String, dynamic> toJson() => {
    "nonce": nonceB64,
    "cipher": cipherB64,
    "mac": macB64,
    "sender": sender,
    "ts": ts,
  };

  static EncryptedPayload fromJson(Map<String, dynamic> j) => EncryptedPayload(
    nonceB64: j["nonce"],
    cipherB64: j["cipher"],
    macB64: j["mac"],
    sender: j["sender"] ?? "peer",
    ts: j["ts"] ?? 0,
  );
}

class Message {
  final String text;
  final String from;
  final int ts;
  final bool outgoing;
  Message({required this.text, required this.from, required this.ts, required this.outgoing});
}
