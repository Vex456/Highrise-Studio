import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/studio_theme.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  final ApiService api;
  final StorageService storage;

  const LoginScreen({
    super.key,
    required this.api,
    required this.storage,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _urlController = TextEditingController();
  final _pwdController = TextEditingController();
  final _nameController = TextEditingController(text: 'My Wispbyte Server');

  bool _isLoading = false;
  bool _isTesting = false;
  int? _pingMs;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  void _loadSaved() {
    final savedUrl = widget.storage.getServerUrl();
    final savedPwd = widget.storage.getAdminPassword();
    if (savedUrl.isNotEmpty) {
      _urlController.text = savedUrl;
    } else {
      _urlController.text = 'http://';
    }
    if (savedPwd.isNotEmpty) {
      _pwdController.text = savedPwd;
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _errorMessage = null;
      _pingMs = null;
    });

    try {
      final ping = await widget.api.pingServer(
        _urlController.text.trim(),
        _pwdController.text.trim(),
      );
      setState(() {
        _pingMs = ping;
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isTesting = false;
      });
    }
  }

  Future<void> _handleConnect() async {
    final url = _urlController.text.trim();
    final pwd = _pwdController.text.trim();

    if (url.isEmpty || pwd.isEmpty) {
      setState(() {
        _errorMessage = 'Please provide both server URL and admin password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ok = await widget.api.login(url, pwd);
      if (ok) {
        // Save profile
        final profile = ServerProfile(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim().isEmpty ? 'Wispbyte Server' : _nameController.text.trim(),
          url: url,
          password: pwd,
        );
        await widget.storage.saveProfile(profile);

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MainNavigationScreen(
              api: widget.api,
              storage: widget.storage,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Authentication failed. Check your password.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: ${e.toString().replaceFirst('Exception: ', '')}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.storage.getProfiles();

    return Scaffold(
      backgroundColor: StudioTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo & Header
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: StudioTheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: StudioTheme.accent.withOpacity(0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: StudioTheme.accent.withOpacity(0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: const Icon(Icons.hub_rounded, size: 36, color: StudioTheme.accent),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "HIGHRISE STUDIO",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: StudioTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Complete Fleet, Audio & 3D Room Management",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: StudioTheme.textSecondary),
                  ),
                  const SizedBox(height: 32),

                  // Saved Profiles Quick Selector
                  if (profiles.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: StudioTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: StudioTheme.cardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_done_rounded, size: 18, color: StudioTheme.accent),
                          const SizedBox(width: 10),
                          const Text("Saved Server: ", style: TextStyle(fontSize: 12, color: StudioTheme.textMuted)),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<ServerProfile>(
                                dropdownColor: StudioTheme.card,
                                value: profiles.firstWhere(
                                  (p) => p.url == _urlController.text.trim(),
                                  orElse: () => profiles.first,
                                ),
                                items: profiles.map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    p.name,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                )).toList(),
                                onChanged: (p) {
                                  if (p != null) {
                                    setState(() {
                                      _urlController.text = p.url;
                                      _pwdController.text = p.password;
                                      _nameController.text = p.name;
                                      _pingMs = null;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Connection Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: StudioTheme.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: StudioTheme.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "SERVER CONNECTION",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: StudioTheme.accent,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Server URL
                        const Text("Wispbyte Server URL / IP:Port", style: TextStyle(fontSize: 12, color: StudioTheme.textSecondary)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _urlController,
                          keyboardType: TextInputType.url,
                          style: const TextStyle(fontSize: 14, color: Colors.white),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.dns_rounded, size: 18, color: StudioTheme.textMuted),
                            hintText: "http://s1.wispbyte.com:25565",
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Admin Password
                        const Text("Admin Dashboard Password", style: TextStyle(fontSize: 12, color: StudioTheme.textSecondary)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _pwdController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(fontSize: 14, color: Colors.white),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_rounded, size: 18, color: StudioTheme.textMuted),
                            hintText: "Enter master admin password",
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                size: 18,
                                color: StudioTheme.textMuted,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Ping Test & Status Row
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isTesting ? null : _testConnection,
                              icon: _isTesting
                                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.network_ping_rounded, size: 16),
                              label: const Text("Ping Test", style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: StudioTheme.textSecondary,
                                side: const BorderSide(color: StudioTheme.cardBorder),
                              ),
                            ),
                            const Spacer(),
                            if (_pingMs != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: StudioTheme.online.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: StudioTheme.online.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.circle, size: 7, color: StudioTheme.online),
                                    const SizedBox(width: 6),
                                    Text(
                                      "${_pingMs}ms · Online",
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: StudioTheme.online),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Error Banner
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: StudioTheme.offline.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: StudioTheme.offline.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 16, color: StudioTheme.offline),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(fontSize: 12, color: StudioTheme.offline),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Connect Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleConnect,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login_rounded, size: 18),
                              SizedBox(width: 8),
                              Text("CONNECT TO STUDIO", style: TextStyle(letterSpacing: 0.8)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
