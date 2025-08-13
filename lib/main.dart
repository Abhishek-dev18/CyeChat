
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/chat_page.dart';
import 'src/session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final displayName = prefs.getString('display_name');
  runApp(MyApp(initialName: displayName));
}

class MyApp extends StatelessWidget {
  final String? initialName;
  const MyApp({super.key, this.initialName});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.white,
        brightness: Brightness.dark,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 16, height: 1.4),
      ),
    );

    return ChangeNotifierProvider(
      create: (_) => SessionModel(initialName: initialName),
      child: MaterialApp(
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: const EntryGate(),
      ),
    );
  }
}

class EntryGate extends StatefulWidget {
  const EntryGate({super.key});

  @override
  State<EntryGate> createState() => _EntryGateState();
}

class _EntryGateState extends State<EntryGate> {
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = context.read<SessionModel>();
    controller.text = s.displayName ?? '';
  }

  Future<void> _save() async {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('display_name', name);
    context.read<SessionModel>().setDisplayName(name);
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ChatPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionModel>();
    final hasName = (s.displayName ?? '').isNotEmpty;
    return hasName ? const ChatPage() : _buildOnboarding();
  }

  Widget _buildOnboarding() {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text("Welcome", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const Text("Pick a display name. This shows up on messages you send.", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: "e.g., abhishek",
                filled: true,
                fillColor: const Color(0xFF151515),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
