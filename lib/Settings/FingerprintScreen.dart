import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
class FingerprintScreen extends StatefulWidget {
  const FingerprintScreen({super.key});

  @override
  State<FingerprintScreen> createState() => _FingerprintScreenState();
}

class _FingerprintScreenState extends State<FingerprintScreen> {

  bool enabled = false;

  @override
  void initState() {
    super.initState();
    loadSetting();
  }

  Future<void> loadSetting() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      enabled = prefs.getBool("fingerprint_enabled") ?? false;
    });
  }

  Future<void> enableFingerprint(bool value) async {
    final auth = LocalAuthentication();

    final canAuthenticate =
        await auth.canCheckBiometrics ||
            await auth.isDeviceSupported();

    if (!canAuthenticate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Fingerprint not available"),
        ),
      );
      return;
    }

    try {
      final success = await auth.authenticate(
        localizedReason: value
            ? "Verify fingerprint to enable login"
            : "Verify fingerprint to disable login",
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!success) return;

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool("fingerprint_enabled", value);

      setState(() {
        enabled = value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? "Fingerprint enabled successfully."
                : "Fingerprint disabled successfully.",
          ),
        ),
      );
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Authentication failed"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Fingerprint"),
      ),
      body: ListTile(
        leading: const Icon(Icons.fingerprint),
        title: const Text("Fingerprint Login"),
        subtitle: const Text(
          "Use fingerprint to unlock app",
        ),
        trailing: Switch(
          value: enabled,
          onChanged: (value) {
            enableFingerprint(value);
          },
        ),
      ),
    );
  }
}