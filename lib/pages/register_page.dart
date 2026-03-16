import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  List<Map<String, dynamic>> _companies = [];
  int? _selectedCompanyId;
  bool _loadingCompanies = true;

  static const _roles = ['admin', 'staff', 'user'];
  String _selectedRole = 'user';

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  Future<void> _fetchCompanies() async {
    final response = await apiRequest(
      endpoint: '/api/accounts/companies/',
      method: HttpMethod.get,
      showError: true,
      context: context,
    );
    if (response != null && response is List) {
      setState(() {
        _companies = response.cast<Map<String, dynamic>>();
        _loadingCompanies = false;
      });
    } else {
      setState(() => _loadingCompanies = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      final body = {
        "phone_number": _phoneController.text.trim(),
        "first_name": _firstNameController.text.trim(),
        "last_name": _lastNameController.text.trim(),
        "email": _emailController.text.trim(),
        "role": _selectedRole,
        "company": _selectedCompanyId,
        "password": _passwordController.text,
      };

      final response = await apiRequest(
        endpoint: '/api/accounts/register/',
        method: HttpMethod.post,
        body: body,
        showError: true,
        context: context,
      );

      if (response != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Center(child: Text('Бүртгэл амжилттай'))),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Icon(
                    Icons.fingerprint,
                    size: 42,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Шинэ хэрэглэгч бүртгэх',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // First name
                TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Нэр',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Нэрээ оруулна уу' : null,
                ),
                const SizedBox(height: 16),

                // Last name
                TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Овог',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Овог оруулна уу' : null,
                ),
                const SizedBox(height: 16),

                // Phone number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Утасны дугаар',
                    hintText: '9999-9999',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Утасны дугаараа оруулна уу'
                      : null,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Имэйл',
                    hintText: 'user@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Имэйл оруулна уу';
                    }
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Зөв имэйл оруулна уу';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Company dropdown
                _loadingCompanies
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<int>(
                        value: _selectedCompanyId,
                        decoration: const InputDecoration(
                          labelText: 'Байгууллага',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                        items: _companies.map((c) {
                          return DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(c['name'] as String),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() => _selectedCompanyId = v);
                        },
                        validator: (v) =>
                            v == null ? 'Байгууллага сонгоно уу' : null,
                      ),
                const SizedBox(height: 16),

                // Role dropdown
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Эрх',
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                  ),
                  items: _roles.map((role) {
                    return DropdownMenuItem<String>(
                      value: role,
                      child: Text(role[0].toUpperCase() + role.substring(1)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedRole = v);
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Нууц үг',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Нууц үгээ оруулна уу';
                    if (v.length < 6) return 'Хамгийн багадаа 6 тэмдэгт';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Submit
                FilledButton(
                  onPressed: _register,
                  child: const Text('Бүртгүүлэх'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
