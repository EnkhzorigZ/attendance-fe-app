import 'package:attendance_fe_app/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _loading = false;
  String _statusText = "Та ирцээ бүртгүүлнэ үү";
  String? _lastCheckIn;
  Position? _position;
  Map<String, dynamic>? _profileData;
  BitmapDescriptor? _companyIcon;

  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadLastCheckIn();
    _loadCompanyIcon();
  }

  Future<void> _loadCompanyIcon() async {
    _companyIcon = await getResizedBitmap('assets/company.png', 100);
    setState(() {});
  }

  Future<BitmapDescriptor> getResizedBitmap(String path, int size) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: size,
      targetHeight: size,
    );
    final frame = await codec.getNextFrame();
    final byteData =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    final resizedBytes = byteData!.buffer.asUint8List();
    // ignore: deprecated_member_use
    return BitmapDescriptor.fromBytes(resizedBytes);
  }

  Future<void> _loadProfile() async {
    final res = await apiRequest(
      endpoint: '/api/accounts/profile/',
      method: HttpMethod.get,
      useToken: true,
      context: context,
    );
    if (res != null) {
      setState(() {
        _profileData = res;
      });
    }
  }

  /// 🔐 BIOMETRIC
  Future<bool> _authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Ирц бүртгэхийн тулд баталгаажуулна уу',
        options: const AuthenticationOptions(biometricOnly: true),
      );
    } catch (e) {
      return false;
    }
  }

  /// 📍 LOCATION
  Future<Position?> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showMessage("Байршлын үйлчилгээ идэвхгүй");
      return null;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMessage("Байршлын зөвшөөрөл шаардлагатай");
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  /// 🏠 ADDRESS
  Future<String> _getAddress(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      final p = placemarks.first;

      return "${p.street}, ${p.locality}";
    } catch (e) {
      return "Хаяг олдсонгүй";
    }
  }

  /// 💾 LAST CHECKIN
  Future<void> _saveCheckIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      "last_checkin",
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> _loadLastCheckIn() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastCheckIn = prefs.getString("last_checkin");
    });
  }

  /// 🚀 MAIN ACTION
  Future<void> _attendanceAction(String action) async {
    setState(() => _loading = true);

    /// 1. BIOMETRIC
    final isAuth = await _authenticate();
    if (!isAuth) {
      _showMessage("Баталгаажуулалт амжилтгүй");
      setState(() => _loading = false);
      return;
    }

    /// 2. LOCATION
    setState(() => _statusText = "Байршил авч байна...");
    final pos = await _getLocation();
    if (pos == null) {
      setState(() => _loading = false);
      return;
    }

    /// 3. ADDRESS
    final addr = await _getAddress(pos.latitude, pos.longitude);

    setState(() {
      _position = pos;
      _statusText = addr;
    });

    /// 4. API CALL
    final res = await apiRequest(
      endpoint: '/api/attendance/action/',
      method: HttpMethod.post,
      body: {
        "action": action,
        "latitude": pos.latitude,
        "longitude": pos.longitude,
      },
      useToken: true,
      context: context,
      showError: true,
    );

    setState(() => _loading = false);

    if (res != null) {
      final msg = action == 'checkin'
          ? 'Амжилттай бүртгэгдлээ.!'
          : 'Амжилттай бүртгэгдлээ.!';

      if (action == 'checkin') {
        await _saveCheckIn();
        _loadLastCheckIn();
      }

      _showMessage(msg);
      setState(() => _statusText = msg);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadProfile(), _loadLastCheckIn()]);
  }

  /// UI HELPERS
  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Widget _map() {
    final company = _profileData?['company'];
    final companyLat = company?['latitude'] as double?;
    final companyLng = company?['longitude'] as double?;

    if (companyLat == null || companyLng == null) return const SizedBox();

    final companyPos = LatLng(companyLat, companyLng);
    final markers = <Marker>{
      Marker(
        markerId: MarkerId("company"),
        position: companyPos,
        infoWindow: InfoWindow(title: company?['name'] ?? 'Компани'),
        icon: _companyIcon!,
      ),
    };

    if (_position != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("me"),
          position: LatLng(_position!.latitude, _position!.longitude),
          infoWindow: const InfoWindow(title: 'Миний байршил'),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 300,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: companyPos,
            zoom: 16,
          ),
          markers: markers,
          zoomControlsEnabled: false,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
      ),
    );
  }

  Widget _btn(String text, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: FilledButton.icon(
        onPressed: _loading ? null : onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          text,
          style: TextStyle(color: Colors.white),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: Colors.transparent,
        title: Text(
          '${_profileData?['last_name'] ?? ''} ${_profileData?['first_name'] ?? ''}',
          style: theme.textTheme.titleMedium,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              ThemeController.themeMode.value == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: ThemeController.toggleTheme,
          )
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Theme(
                data: Theme.of(context).copyWith(
                  dividerTheme: const DividerThemeData(
                    color: Colors.transparent,
                  ),
                ),
                child: DrawerHeader(
                  decoration: BoxDecoration(
                    color: Colors.transparent, // removes default color
                    border: Border.all(
                      color: Colors.transparent, // ensures no border
                      width: 0,
                    ),
                  ),
                  margin: EdgeInsets.zero, // removes any default margin
                  padding: EdgeInsets.symmetric(horizontal: 16), // optional:
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            "${_profileData?['last_name'] ?? ''} ${_profileData?['first_name'] ?? ''}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          if (_profileData?['is_approved'] == true)
                            Icon(
                              Icons.verified,
                              color: Colors.greenAccent,
                              size: 20,
                            ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        "📞 ${_profileData?['phone_number'] ?? ''}",
                        style: TextStyle(),
                      ),
                      Text(
                        "✉️ ${_profileData?['email'] ?? ''}",
                        style: TextStyle(),
                      ),
                      Text(
                        "🏢 ${_profileData?['company']?['name'] ?? ''}",
                        style: TextStyle(),
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text("Түүх"),
                onTap: () {
                  Navigator.pushNamed(context, "/history");
                },
              ),
              const Spacer(),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                child: FilledButton.icon(
                  icon: const Icon(Icons.logout),
                  label: Text("Гарах"),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('token');
                    await prefs.remove('refresh');

                    Navigator.pushNamedAndRemoveUntil(
                        context, "/login", (_) => false);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: _refresh,
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                /// CARD
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.access_time,
                          size: 60, color: theme.colorScheme.primary),
                      const SizedBox(height: 10),
                      Text("Ирц бүртгэл", style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(_statusText, textAlign: TextAlign.center),
                      if (_lastCheckIn != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "Сүүлд: ${DateTime.parse(_lastCheckIn!).toLocal().toString().substring(0, 16)}",
                            style: const TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// MAP
                _map(),

                const SizedBox(height: 20),

                /// BUTTONS
                _btn("Ирсэн", Icons.login, theme.colorScheme.primary,
                    () => _attendanceAction("checkin")),

                const SizedBox(height: 10),

                _btn("Явсан", Icons.logout, theme.colorScheme.error,
                    () => _attendanceAction("checkout")),

                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
