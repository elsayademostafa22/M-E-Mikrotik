import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => NetworkProvider()..loadSettings(),
      child: const NetworkAdminApp(),
    ),
  );
}

class NetworkAdminApp extends StatelessWidget {
  const NetworkAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إدارة الشبكة المحلية',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// ==================== Model ====================
class NetworkUser {
  final String name;
  final String ip;
  final String mac;

  NetworkUser({
    required this.name,
    required this.ip,
    required this.mac,
  });

  factory NetworkUser.fromJson(Map<String, dynamic> json) {
    return NetworkUser(
      name: json['name'] ?? 'بدون اسم',
      ip: json['ip'] ?? '0.0.0.0',
      mac: json['mac'] ?? '00:00:00:00:00:00',
    );
  }
}

// ==================== Provider ====================
class NetworkProvider extends ChangeNotifier {
  String _serverIp = '192.168.1.100';
  String _serverPort = '3000';
  bool _isConnected = false;
  List<NetworkUser> _users = [];
  bool _isLoading = false;

  String get baseUrl => 'http://$_serverIp:$_serverPort/api';
  String get serverIp => _serverIp;
  String get serverPort => _serverPort;
  bool get isConnected => _isConnected;
  List<NetworkUser> get users => _users;
  bool get isLoading => _isLoading;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _serverIp = prefs.getString('server_ip') ?? '192.168.1.100';
    _serverPort = prefs.getString('server_port') ?? '3000';
    notifyListeners();
    checkConnection();
  }

  Future<void> saveSettings(String ip, String port) async {
    _serverIp = ip;
    _serverPort = port;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', ip);
    await prefs.setString('server_port', port);
    notifyListeners();
    checkConnection();
  }

  Future<bool> checkConnection() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/status'))
          .timeout(const Duration(seconds: 3));
      _isConnected = (res.statusCode == 200);
    } catch (_) {
      _isConnected = false;
    }
    notifyListeners();
    return _isConnected;
  }

  Future<void> fetchUsers() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await http.get(Uri.parse('$baseUrl/users'));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body)['data'] ?? [];
        _users = data.map((json) => NetworkUser.fromJson(json)).toList();
      }
    } catch (_) {
      _users = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> disconnectUser(String username) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/users/disconnect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      );
      if (res.statusCode == 200) {
        fetchUsers();
        return true;
      }
    } catch (_) {}
    return false;
  }
}

// ==================== Navigation ====================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    UsersScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl,
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'الرئيسية'),
            NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'المستخدمين'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'الإعدادات'),
          ],
        ),
      ),
    );
  }
}

// ==================== Dashboard Screen ====================
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NetworkProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم المحلية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.checkConnection(),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              color: provider.isConnected
                  ? Colors.green.withOpacity(0.15)
                  : Colors.red.withOpacity(0.15),
              child: ListTile(
                leading: Icon(
                  provider.isConnected ? Icons.wifi : Icons.wifi_off,
                  color: provider.isConnected ? Colors.green : Colors.red,
                  size: 32,
                ),
                title: Text(
                  provider.isConnected ? 'متصل بالسيرفر' : 'غير متصل بالسيرفر',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('IP: ${provider.serverIp}:${provider.serverPort}'),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildMetricCard(
                    title: 'المستخدمين النشطين',
                    value: provider.users.length.toString(),
                    icon: Icons.supervised_user_circle,
                    color: Colors.blue,
                  ),
                  _buildMetricCard(
                    title: 'عنوان Gateway',
                    value: '192.168.1.1',
                    icon: Icons.router,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ==================== Users Screen ====================
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<NetworkProvider>(context, listen: false).fetchUsers());
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NetworkProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المستخدمين المتصلين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchUsers(),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.users.isEmpty
              ? const Center(child: Text('لا يوجد مستخدمين حالياً أو السيرفر غير متصل'))
              : ListView.builder(
                  itemCount: provider.users.length,
                  itemBuilder: (ctx, i) {
                    final user = provider.users[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(user.name),
                        subtitle: Text('IP: ${user.ip} | MAC: ${user.mac}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.block, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('تأكيد القطع'),
                                content: Text('هل تريد فصل الخدمة عن ${user.name}؟'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('إلغاء'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('قطع', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await provider.disconnectUser(user.name);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ==================== Settings Screen ====================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ipController;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<NetworkProvider>(context, listen: false);
    _ipController = TextEditingController(text: provider.serverIp);
    _portController = TextEditingController(text: provider.serverPort);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NetworkProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الاتصال')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'عنوان الخادم المحلي (Local Server):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'عنوان الـ IP الخادم المحلي',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer),
              ),
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'البورت (Port)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('حفظ واختبار الاتصال'),
                onPressed: () async {
                  await provider.saveSettings(
                    _ipController.text.trim(),
                    _portController.text.trim(),
                  );
                  final success = await provider.checkConnection();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'تم الاتصال بنجاح بالخادم المحلي!'
                              : 'فشل الاتصال! تأكد من صحة IP والبورت.',
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
