import 'package:attendance_fe_app/main.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _loading = false;

  Future<Position?> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Байршлын үйлчилгээ идэвхгүй байна')),
        );
      }
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Байршлын зөвшөөрөл олгоогүй')),
          );
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Байршлын зөвшөөрөл бүрмөсөн хаагдсан')),
        );
      }
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _attendanceAction(String action) async {
    setState(() => _loading = true);

    final position = await _getLocation();
    if (position == null) {
      setState(() => _loading = false);
      return;
    }

    final body = {
      "action": action,
      "latitude": position.latitude,
      "longitude": position.longitude,
    };

    final response = await apiRequest(
      endpoint: '/api/attendance/action/',
      method: HttpMethod.post,
      body: body,
      useToken: true,
      showError: true,
      context: context,
    );

    setState(() => _loading = false);

    if (response != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(
            child: Text(
              action == 'checkin' ? 'Амжилттай ирлээ!' : 'Амжилттай явлаа!',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ирц'),
        actions: [
          IconButton(
            icon: Icon(
              ThemeController.themeMode.value == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              ThemeController.toggleTheme();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                child: Text(""),
              ),
              const Spacer(),
              // const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Гарах', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('token');
                  await prefs.remove('refresh');
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Ирц бүртгэл',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: _loading ? null : () => _attendanceAction('checkin'),
                icon: const Icon(Icons.login),
                label: const Text('Ирсэн'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed:
                    _loading ? null : () => _attendanceAction('checkout'),
                icon: const Icon(Icons.logout),
                label: const Text('Явсан'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
              if (_loading) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
