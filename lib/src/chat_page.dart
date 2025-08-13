
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'session.dart';
import 'signaling.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final controller = TextEditingController();
  final P2PSignaler signaler = P2PSignaler();

  String? _localOffer;
  String? _peerAnswer;
  String? _peerOffer;
  String? _myAnswer;

  bool _connected = false;

  @override
  void initState() {
    super.initState();
    signaler.init(onText: _onIncomingText);
  }

  @override
  void dispose() {
    signaler.dispose();
    super.dispose();
  }

  Future<void> _onIncomingText(String raw) async {
    final s = context.read<SessionModel>();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map.containsKey("nonce") && map.containsKey("cipher")) {
        final payload = EncryptedPayload.fromJson(map);
        final clear = await s.decrypt(payload);
        s.addMessage(Message(text: clear, from: payload.sender, ts: payload.ts, outgoing: false));
      }
    } catch (_) {
      // ignore non-json texts
    }
  }

  Future<void> _hostStart() async {
    final s = context.read<SessionModel>();
    final offer = await signaler.createOfferAndDataChannel(onText: _onIncomingText);
    setState(() => _localOffer = offer);
    // Provide our public key alongside SDP
  }

  Future<void> _hostAcceptAnswer(String jsonAnswerPlusKey) async {
    final s = context.read<SessionModel>();
    final obj = jsonDecode(jsonAnswerPlusKey);
    final answer = obj["sdp"];
    final peerPub = obj["pubKey"];
    await s.startSessionWithPeerPubKey(peerPub);
    await signaler.setRemoteDescriptionFromJson(answer);
    setState(() => _connected = true);
  }

  Future<void> _joinWithOffer(String jsonOfferPlusKey) async {
    final s = context.read<SessionModel>();
    final obj = jsonDecode(jsonOfferPlusKey);
    final offer = obj["sdp"];
    final peerPub = obj["pubKey"];
    await s.startSessionWithPeerPubKey(peerPub);
    await signaler.setRemoteDescriptionFromJson(offer);
    final answer = await signaler.createAnswer();
    _myAnswer = jsonEncode({"sdp": answer, "pubKey": s.publicKeyBase64});
    setState(() {});
  }

  Future<void> _send() async {
    final s = context.read<SessionModel>();
    final text = controller.text.trim();
    if (text.isEmpty || !s.hasSession) return;
    final payload = await s.encrypt(text);
    final jsonMsg = jsonEncode(payload.toJson());
    signaler.send(jsonMsg);
    s.addMessage(Message(text: text, from: s.displayName ?? "me", ts: DateTime.now().millisecondsSinceEpoch, outgoing: true));
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionModel>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text("Threads-style P2P", style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: "Host",
            onPressed: _hostStart,
            icon: const Icon(Icons.cast),
          ),
          IconButton(
            tooltip: "Join",
            onPressed: () => _showJoinDialog(),
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_localOffer != null && !_connected)
            _OfferShareCard(
              title: "Share this QR to connect",
              data: jsonEncode({"sdp": _localOffer, "pubKey": s.publicKeyBase64}),
              onPasteInput: (val) async {
                await _hostAcceptAnswer(val);
              },
              pasteHint: "Paste ANSWER JSON here to complete",
            ),
          if (_myAnswer != null && !_connected)
            _OfferShareCard(
              title: "Send this back to host",
              data: _myAnswer!,
              onPasteInput: (_) {},
              pasteHint: "Share this QR/text with the host",
            ),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: s.messages.length,
              itemBuilder: (context, idx) {
                final m = s.messages[s.messages.length - 1 - idx];
                return _Bubble(message: m);
              },
            ),
          ),
          _Composer(controller: controller, onSend: _send),
        ],
      ),
    );
  }

  Future<void> _showJoinDialog() async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101010),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final input = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16, top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Join a chat", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text("Scan host QR or paste JSON offer below."),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: MobileScanner(
                  onDetect: (capture) {
                    for (final code in capture.barcodes) {
                      if (code.rawValue != null) {
                        input.text = code.rawValue!;
                        break;
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: input,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Paste host OFFER JSON here",
                  filled: true,
                  fillColor: const Color(0xFF151515),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await _joinWithOffer(input.text.trim());
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text("Generate Answer"),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _OfferShareCard extends StatelessWidget {
  final String title;
  final String data;
  final void Function(String) onPasteInput;
  final String pasteHint;

  const _OfferShareCard({required this.title, required this.data, required this.onPasteInput, required this.pasteHint});

  @override
  Widget build(BuildContext context) {
    final input = TextEditingController();
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Center(child: QrImageView(data: data, size: 180)),
          const SizedBox(height: 8),
          SelectableText(data, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),
          TextField(
            controller: input,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: pasteHint,
              filled: true,
              fillColor: const Color(0xFF151515),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              ElevatedButton(
                onPressed: () => onPasteInput(input.text.trim()),
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text("Apply"),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final align = message.outgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = message.outgoing ? const Color(0xFF1F1F1F) : const Color(0xFF141414);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: message.outgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: align,
                children: [
                  Text(message.text),
                  const SizedBox(height: 2),
                  Text(
                    message.from,
                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF202020), width: 0.5)),
          color: Color(0xFF0D0D0D),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: "Message",
                  filled: true,
                  fillColor: const Color(0xFF151515),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: const CircleAvatar(
                radius: 22,
                child: Icon(Icons.send),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
