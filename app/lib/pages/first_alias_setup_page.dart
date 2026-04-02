import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class FirstAliasSetupPage extends StatefulWidget {
  const FirstAliasSetupPage({super.key});

  @override
  State<FirstAliasSetupPage> createState() => _FirstAliasSetupPageState();
}

class _FirstAliasSetupPageState extends State<FirstAliasSetupPage> {
  late final TextEditingController _controller;
  bool _didLoadInitialAlias = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadInitialAlias) {
      return;
    }

    _didLoadInitialAlias = true;
    final alias = context.ref.read(settingsProvider).alias;
    _controller.text = alias;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final alias = _controller.text.trim();
    if (alias.isEmpty || _saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await context.ref.notifier(settingsProvider).setAlias(alias);
      if (!mounted) return;
      await context.ref.read(persistenceProvider).setAliasSetupCompleted(true);
      if (!mounted) return;
      await context.pushRoot(
        () => const HomePage(
          initialTab: HomeTab.receive,
          appStart: true,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.device_hub_rounded, color: Color(0xFF8FA9FF)),
                  const SizedBox(width: 8),
                  Text(
                    t.appName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8FA9FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const Icon(Icons.radar_rounded, size: 58, color: Color(0xFF8FA9FF)),
              const SizedBox(height: 22),
              const Text(
                'Set Up Your Device',
                style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, height: 1.05),
              ),
              const SizedBox(height: 14),
              Text(
                'Choose a name that other devices will see when you are nearby.',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.grey.shade400,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                t.settingsTab.network.alias.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 0.8,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Enter device name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This name is visible to local Wi-Fi users.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Get Started',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
