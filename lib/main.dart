import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TuristarApp());
}

class TuristarApp extends StatelessWidget {
  const TuristarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turistar Viagens Premium',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: TuristarColors.page,
        colorScheme: ColorScheme.fromSeed(
          seedColor: TuristarColors.navy,
          primary: TuristarColors.navy,
          secondary: TuristarColors.orange,
        ),
        fontFamily: 'Arial',
      ),
      home: const TuristarLandingPage(),
    );
  }
}

class TuristarColors {
  static const navy = Color(0xFF002B66);
  static const navyDark = Color(0xFF001D46);
  static const navyDeep = Color(0xFF00142F);
  static const orange = Color(0xFFF6A313);
  static const orangeDark = Color(0xFFD48600);
  static const page = Color(0xFFF8FAFE);
  static const text = Color(0xFF092A5E);
  static const muted = Color(0xFF62728B);
  static const line = Color(0xFFE2E8F3);
  static const green = Color(0xFF1DBE72);
}

enum TravelService { flights, hotels, cars, packages }

extension TravelServiceInfo on TravelService {
  String get label {
    switch (this) {
      case TravelService.flights:
        return 'Passagens Aereas';
      case TravelService.hotels:
        return 'Hospedagem';
      case TravelService.cars:
        return 'Aluguel de Carros';
      case TravelService.packages:
        return 'Pacotes';
    }
  }

  String get shortLabel {
    switch (this) {
      case TravelService.flights:
        return 'Voos';
      case TravelService.hotels:
        return 'Hoteis';
      case TravelService.cars:
        return 'Carros';
      case TravelService.packages:
        return 'Pacotes';
    }
  }

  String get actionLabel {
    switch (this) {
      case TravelService.flights:
        return 'Buscar Voos';
      case TravelService.hotels:
        return 'Buscar Hoteis';
      case TravelService.cars:
        return 'Alugar Carro';
      case TravelService.packages:
        return 'Buscar Pacotes';
    }
  }

  IconData get icon {
    switch (this) {
      case TravelService.flights:
        return Icons.flight_takeoff;
      case TravelService.hotels:
        return Icons.apartment;
      case TravelService.cars:
        return Icons.directions_car;
      case TravelService.packages:
        return Icons.luggage;
    }
  }
}

class SearchRequest {
  const SearchRequest({
    required this.service,
    required this.origin,
    required this.destination,
    required this.departureDate,
    required this.returnDate,
    required this.travelers,
  });

  final TravelService service;
  final String origin;
  final String destination;
  final String departureDate;
  final String returnDate;
  final String travelers;
}

class SearchResultItem {
  const SearchResultItem({
    this.id,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.price,
    required this.badge,
    required this.icon,
    this.fromApi = false,
  });

  final String? id;
  final String title;
  final String subtitle;
  final String details;
  final String price;
  final String badge;
  final IconData icon;
  final bool fromApi;
}

class TuristarLandingPage extends StatefulWidget {
  const TuristarLandingPage({super.key});

  @override
  State<TuristarLandingPage> createState() => _TuristarLandingPageState();
}

class _TuristarLandingPageState extends State<TuristarLandingPage> {
  TravelService selectedService = TravelService.flights;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            TopNavigation(onServiceSelected: _selectService),
            HeroSection(
              selectedService: selectedService,
              onServiceChanged: _selectService,
              onSearch: _openResults,
            ),
            ServicesSection(onServiceSelected: _openResultsForService),
            const WhyChooseSection(),
            CallToActionSection(onSearch: () => _openResultsForService(selectedService)),
            const FooterSection(),
          ],
        ),
      ),
    );
  }

  void _selectService(TravelService service) {
    setState(() => selectedService = service);
  }

  void _openResults(SearchRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultsPage(request: request)),
    );
  }

  void _openResultsForService(TravelService service) {
    _selectService(service);
    _openResults(defaultRequest(service));
  }
}

SearchRequest defaultRequest(TravelService service) {
  return SearchRequest(
    service: service,
    origin: service == TravelService.hotels ? 'Sao Paulo' : 'GRU',
    destination: service == TravelService.cars ? 'Miami Airport' : 'Miami',
    departureDate: '20 de Junho, 2024',
    returnDate: '27 de Junho, 2024',
    travelers: service == TravelService.cars ? '1 carro, automatico' : '1 passageiro, Economica',
  );
}

class LocationResolver {
  const LocationResolver._();

  static const Map<String, String> _aliases = {
    'SAO PAULO': 'GRU',
    'SP': 'GRU',
    'GRU': 'GRU',
    'GUARULHOS': 'GRU',
    'CONGONHAS': 'CGH',
    'CGH': 'CGH',
    'VIRACOPOS': 'VCP',
    'CAMPINAS': 'VCP',
    'VCP': 'VCP',
    'RIO': 'GIG',
    'RIO DE JANEIRO': 'GIG',
    'GIG': 'GIG',
    'GALEAO': 'GIG',
    'SANTOS DUMONT': 'SDU',
    'SDU': 'SDU',
    'BRASILIA': 'BSB',
    'BSB': 'BSB',
    'SALVADOR': 'SSA',
    'SSA': 'SSA',
    'RECIFE': 'REC',
    'REC': 'REC',
    'MIAMI': 'MIA',
    'MIA': 'MIA',
    'ORLANDO': 'MCO',
    'MCO': 'MCO',
    'LISBOA': 'LIS',
    'LISBON': 'LIS',
    'LIS': 'LIS',
    'PARIS': 'CDG',
    'CDG': 'CDG',
    'BUENOS AIRES': 'EZE',
    'EZE': 'EZE',
  };

  static String codeFor(String value, {String fallback = 'GRU'}) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return fallback;
    if (_aliases.containsKey(normalized)) return _aliases[normalized]!;
    final exactCode = RegExp(r'^[A-Z]{3}$').firstMatch(normalized);
    if (exactCode != null) return exactCode.group(0)!;
    final embeddedCode = RegExp(r'\b[A-Z]{3}\b').firstMatch(normalized);
    if (embeddedCode != null) return embeddedCode.group(0)!;
    return normalized.substring(0, normalized.length.clamp(0, 3).toInt()).padRight(3, 'X');
  }

  static String labelFor(String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return 'Origem';
    if (_aliases.containsKey(normalized)) return '${_titleCase(value)} (${_aliases[normalized]})';
    return value.trim();
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll('\u00C1', 'A')
        .replaceAll('\u00C0', 'A')
        .replaceAll('\u00C2', 'A')
        .replaceAll('\u00C3', 'A')
        .replaceAll('\u00C9', 'E')
        .replaceAll('\u00CA', 'E')
        .replaceAll('\u00CD', 'I')
        .replaceAll('\u00D3', 'O')
        .replaceAll('\u00D4', 'O')
        .replaceAll('\u00D5', 'O')
        .replaceAll('\u00DA', 'U')
        .replaceAll('\u00C7', 'C');
  }

  static String _titleCase(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part.length == 1 ? part.toUpperCase() : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }
}

class Responsive {
  static bool isMobile(BuildContext context) => MediaQuery.sizeOf(context).width < 720;
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 720 && width < 1040;
  }

  static double maxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 720) return width;
    if (width < 1040) return 920;
    return 1180;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return EdgeInsets.symmetric(horizontal: isMobile(context) ? 16 : 24);
  }
}

class LayoutShell extends StatelessWidget {
  const LayoutShell({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
        child: Padding(
          padding: padding ?? Responsive.pagePadding(context),
          child: child,
        ),
      ),
    );
  }
}

class TopNavigation extends StatelessWidget {
  const TopNavigation({super.key, required this.onServiceSelected});

  final ValueChanged<TravelService> onServiceSelected;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 940;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: TuristarColors.orange, width: 2)),
      ),
      child: LayoutShell(
        padding: Responsive.pagePadding(context),
        child: SizedBox(
          height: compact ? 70 : 78,
          child: Row(
            children: [
              const BrandLogo(),
              if (!compact) ...[
                const SizedBox(width: 54),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      NavLink(label: 'Passagens', onTap: () => onServiceSelected(TravelService.flights)),
                      NavLink(label: 'Hospedagens', onTap: () => onServiceSelected(TravelService.hotels)),
                      NavLink(label: 'Aluguel de Carros', onTap: () => onServiceSelected(TravelService.cars)),
                      NavLink(label: 'Pacotes', onTap: () => onServiceSelected(TravelService.packages)),
                      const NavLink(label: 'Servicos'),
                      const NavLink(label: 'Empresa'),
                    ],
                  ),
                ),
                HeaderAction(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Minhas Reservas',
                  onTap: () => openReservationsPage(context),
                ),
                const SizedBox(width: 22),
                const HeaderAction(icon: Icons.help_outline, label: 'Ajuda'),
                const SizedBox(width: 22),
                HeaderAction(
                  icon: Icons.person_outline,
                  label: 'Entrar',
                  onTap: () => openLoginPage(context),
                ),
              ] else
                const Spacer(),
              const SizedBox(width: 18),
              InkWell(
                onTap: () => openLoginPage(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    border: Border.all(color: TuristarColors.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu, size: 20, color: TuristarColors.navy),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return TuristarLogo(
      onDark: onDark,
      markSize: mobile ? 38 : 44,
      titleSize: mobile ? 18 : 22,
      taglineSize: mobile ? 8 : 10,
    );
  }
}

class TuristarLogo extends StatelessWidget {
  const TuristarLogo({
    super.key,
    this.onDark = false,
    this.markSize = 44,
    this.titleSize = 22,
    this.taglineSize = 10,
  });

  final bool onDark;
  final double markSize;
  final double titleSize;
  final double taglineSize;

  @override
  Widget build(BuildContext context) {
    final blue = onDark ? Colors.white : TuristarColors.navy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TuristarLogoMark(size: markSize),
        SizedBox(width: markSize * 0.18),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w900,
                  height: 0.92,
                  letterSpacing: -0.8,
                ),
                children: [
                  const TextSpan(text: 'TURISTAR', style: TextStyle(color: TuristarColors.orange)),
                  TextSpan(text: ' VIAGENS', style: TextStyle(color: blue)),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'SEUS SONHOS COMECAM AQUI',
              style: TextStyle(
                color: onDark ? Colors.white70 : TuristarColors.navy,
                fontSize: taglineSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.1,
                height: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TuristarLogoMark extends StatelessWidget {
  const TuristarLogoMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.square(size), painter: TuristarGlobePainter()),
          Transform.rotate(
            angle: -0.45,
            child: Icon(
              Icons.flight,
              color: TuristarColors.orange,
              size: size * 0.68,
            ),
          ),
        ],
      ),
    );
  }
}

class TuristarGlobePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final orangePaint = Paint()
      ..color = TuristarColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round;
    final bluePaint = Paint()
      ..color = TuristarColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.40;
    final circleRect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(circleRect, 0.60, 4.95, false, orangePaint);
    canvas.drawArc(circleRect, -0.20, 0.55, false, bluePaint);
    canvas.drawLine(Offset(size.width * 0.16, size.height * 0.45), Offset(size.width * 0.70, size.height * 0.45), orangePaint);
    canvas.drawLine(Offset(size.width * 0.20, size.height * 0.65), Offset(size.width * 0.56, size.height * 0.65), orangePaint);
    canvas.drawArc(Rect.fromLTWH(size.width * 0.27, size.height * 0.10, size.width * 0.46, size.height * 0.80), -1.40, 2.65, false, orangePaint);
    canvas.drawArc(Rect.fromLTWH(size.width * 0.27, size.height * 0.10, size.width * 0.46, size.height * 0.80), 1.80, 1.95, false, orangePaint);
    canvas.drawLine(Offset(size.width * 0.49, size.height * 0.12), Offset(size.width * 0.49, size.height * 0.84), orangePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NavLink extends StatelessWidget {
  const NavLink({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        child: Text(
          label,
          style: const TextStyle(
            color: TuristarColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: TuristarColors.navy, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: TuristarColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void openLoginPage(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const LoginPage()),
  );
}

void openReservationsPage(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const MyReservationsPage()),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool createAccount = false;
  bool rememberMe = true;
  bool obscurePassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return Scaffold(
      body: Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              TuristarColors.navyDeep,
              TuristarColors.navy,
              Color(0xFFB87312),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutShell(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: mobile ? 18 : 42),
              child: mobile
                  ? Column(
                      children: [
                        const LoginBrandPanel(),
                        const SizedBox(height: 18),
                        _buildLoginCard(context),
                      ],
                    )
                  : Row(
                      children: [
                        const Expanded(child: LoginBrandPanel()),
                        const SizedBox(width: 42),
                        SizedBox(width: 440, child: _buildLoginCard(context)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Responsive.isMobile(context) ? 20 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 26,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: TuristarColors.navy),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: TuristarColors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Area do cliente',
                    style: TextStyle(color: TuristarColors.orangeDark, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              createAccount ? 'Criar sua conta' : 'Entrar na Turistar',
              style: const TextStyle(
                color: TuristarColors.navy,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              createAccount
                  ? 'Cadastre-se para acompanhar reservas, ofertas e suporte.'
                  : 'Acesse suas reservas, favoritos e ofertas exclusivas.',
              style: const TextStyle(color: TuristarColors.muted, height: 1.4),
            ),
            const SizedBox(height: 22),
            LoginModeSwitch(
              createAccount: createAccount,
              onChanged: (value) => setState(() => createAccount = value),
            ),
            const SizedBox(height: 22),
            if (createAccount) ...[
              LoginTextField(
                controller: nameController,
                label: 'Nome completo',
                icon: Icons.person_outline,
                validator: _required,
              ),
              const SizedBox(height: 14),
              LoginTextField(
                controller: phoneController,
                label: 'Telefone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: _required,
              ),
              const SizedBox(height: 14),
            ],
            LoginTextField(
              controller: emailController,
              label: 'E-mail',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: _emailValidator,
            ),
            const SizedBox(height: 14),
            LoginTextField(
              controller: passwordController,
              label: 'Senha',
              icon: Icons.lock_outline,
              obscureText: obscurePassword,
              validator: _required,
              suffix: IconButton(
                onPressed: () => setState(() => obscurePassword = !obscurePassword),
                icon: Icon(
                  obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: TuristarColors.muted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: rememberMe,
                  activeColor: TuristarColors.orange,
                  onChanged: (value) => setState(() => rememberMe = value ?? true),
                ),
                const Expanded(
                  child: Text('Manter conectado', style: TextStyle(color: TuristarColors.muted)),
                ),
                TextButton(
                  onPressed: () => _showPendingAuthMessage('Recuperacao de senha'),
                  child: const Text('Esqueci a senha'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TuristarColors.orange,
                  foregroundColor: TuristarColors.navyDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  createAccount ? 'Criar Conta' : 'Entrar',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Expanded(child: Divider(color: TuristarColors.line)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('ou continue com', style: TextStyle(color: TuristarColors.muted)),
                ),
                Expanded(child: Divider(color: TuristarColors.line)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPendingAuthMessage('Login Google'),
                    icon: const Icon(Icons.g_mobiledata, size: 26),
                    label: const Text('Google'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPendingAuthMessage('Login corporativo'),
                    icon: const Icon(Icons.business_center_outlined, size: 19),
                    label: const Text('Empresa'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: () => setState(() => createAccount = !createAccount),
                child: Text(
                  createAccount ? 'Ja tenho conta. Entrar' : 'Ainda nao tenho conta. Criar cadastro',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatorio';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    if (!value!.contains('@')) {
      return 'Informe um e-mail valido';
    }
    return null;
  }

  void _submit() {
    if (formKey.currentState?.validate() != true) {
      return;
    }
    _goToSearchHome();
  }

  void _goToSearchHome() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(createAccount ? 'Cadastro realizado com sucesso.' : 'Login realizado com sucesso.'),
        backgroundColor: TuristarColors.navy,
      ),
    );

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TuristarLandingPage()),
    );
  }

  void _showPendingAuthMessage(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action pronto para conectar com autenticacao real.'),
        backgroundColor: TuristarColors.navy,
      ),
    );
  }
}

class LoginBrandPanel extends StatelessWidget {
  const LoginBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const BrandLogoOnDark(),
        SizedBox(height: mobile ? 24 : 42),
        Text(
          'Sua viagem comecando em um login simples.',
          style: TextStyle(
            color: Colors.white,
            fontSize: mobile ? 34 : 48,
            fontWeight: FontWeight.w900,
            height: 1.05,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Entre para acompanhar reservas, receber ofertas personalizadas e falar com nosso suporte 24/7.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.82),
            fontSize: mobile ? 15 : 18,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            LoginBenefit(icon: Icons.confirmation_number_outlined, label: 'Reservas em um lugar'),
            LoginBenefit(icon: Icons.local_offer_outlined, label: 'Ofertas exclusivas'),
            LoginBenefit(icon: Icons.support_agent, label: 'Suporte premium'),
          ],
        ),
      ],
    );
  }
}

class BrandLogoOnDark extends StatelessWidget {
  const BrandLogoOnDark({super.key});

  @override
  Widget build(BuildContext context) {
    return const TuristarLogo(
      onDark: true,
      markSize: 72,
      titleSize: 30,
      taglineSize: 11,
    );
  }
}

class LoginBenefit extends StatelessWidget {
  const LoginBenefit({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: TuristarColors.orange, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class LoginModeSwitch extends StatelessWidget {
  const LoginModeSwitch({
    super.key,
    required this.createAccount,
    required this.onChanged,
  });

  final bool createAccount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: TuristarColors.page,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: LoginModeButton(
              label: 'Entrar',
              selected: !createAccount,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: LoginModeButton(
              label: 'Cadastrar',
              selected: createAccount,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginModeButton extends StatelessWidget {
  const LoginModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? TuristarColors.navy : TuristarColors.muted,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class LoginTextField extends StatelessWidget {
  const LoginTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: TuristarColors.orange),
        suffixIcon: suffix,
        filled: true,
        fillColor: TuristarColors.page,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TuristarColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TuristarColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TuristarColors.orange, width: 2),
        ),
      ),
    );
  }
}

class HeroSection extends StatelessWidget {
  const HeroSection({
    super.key,
    required this.selectedService,
    required this.onServiceChanged,
    required this.onSearch,
  });

  final TravelService selectedService;
  final ValueChanged<TravelService> onServiceChanged;
  final ValueChanged<SearchRequest> onSearch;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final tablet = Responsive.isTablet(context);
    final titleSize = mobile ? 34.0 : (tablet ? 42.0 : 52.0);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TuristarColors.navyDeep,
            TuristarColors.navy,
            Color(0xFF063D88),
            Color(0xFFB87312),
          ],
          stops: [0, 0.38, 0.68, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: HeroSkyPainter())),
          if (!mobile)
            Positioned(
              right: tablet ? -54 : 34,
              top: tablet ? 120 : 78,
              child: Transform.rotate(
                angle: -0.26,
                child: Icon(
                  Icons.airplanemode_active,
                  size: tablet ? 250 : 360,
                  color: Colors.white.withOpacity(0.78),
                ),
              ),
            ),
          LayoutShell(
            child: Padding(
              padding: EdgeInsets.only(top: mobile ? 34 : 56, bottom: mobile ? 24 : 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: mobile ? double.infinity : 670),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleSize,
                              height: 1.08,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                            ),
                            children: const [
                              TextSpan(text: 'Explore o '),
                              TextSpan(text: 'Mundo', style: TextStyle(color: TuristarColors.orange)),
                              TextSpan(text: ' com\n'),
                              TextSpan(text: 'Confianca', style: TextStyle(color: TuristarColors.orange)),
                              TextSpan(text: ' e Seguranca'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'As melhores opcoes de viagens para voce e sua familia. Voos, hoteis, carros e pacotes com atendimento completo.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: mobile ? 15 : 18,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: mobile ? 26 : 34),
                  SearchHeroCard(
                    selectedService: selectedService,
                    onServiceChanged: onServiceChanged,
                    onSearch: onSearch,
                  ),
                  SizedBox(height: mobile ? 20 : 26),
                  const HeroStats(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroSkyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final orangePaint = Paint()..color = TuristarColors.orange.withOpacity(0.18);
    final whitePaint = Paint()..color = Colors.white.withOpacity(0.08);
    canvas.drawCircle(Offset(size.width * 0.86, size.height * 0.17), 170, orangePaint);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.08), 80, whitePaint);
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.45), 140, whitePaint);

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..strokeWidth = 1;
    for (var i = 0; i < 9; i++) {
      final y = size.height * (0.16 + i * 0.08);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 80), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SearchHeroCard extends StatefulWidget {
  const SearchHeroCard({
    super.key,
    required this.selectedService,
    required this.onServiceChanged,
    required this.onSearch,
  });

  final TravelService selectedService;
  final ValueChanged<TravelService> onServiceChanged;
  final ValueChanged<SearchRequest> onSearch;

  @override
  State<SearchHeroCard> createState() => _SearchHeroCardState();
}

class _SearchHeroCardState extends State<SearchHeroCard> {
  late final TextEditingController originController;
  late final TextEditingController destinationController;
  late final TextEditingController departureController;
  late final TextEditingController returnController;
  late final TextEditingController travelersController;
  int tripType = 0;
  int adults = 1;
  int children = 0;
  int cars = 1;

  @override
  void initState() {
    super.initState();
    final request = defaultRequest(widget.selectedService);
    originController = TextEditingController(text: request.origin);
    destinationController = TextEditingController(text: request.destination);
    departureController = TextEditingController(text: request.departureDate);
    returnController = TextEditingController(text: request.returnDate);
    travelersController = TextEditingController(text: request.travelers);
  }

  @override
  void didUpdateWidget(covariant SearchHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedService != widget.selectedService) {
      final request = defaultRequest(widget.selectedService);
      originController.text = request.origin;
      destinationController.text = request.destination;
      travelersController.text = request.travelers;
      adults = 1;
      children = 0;
      cars = 1;
    }
  }

  @override
  void dispose() {
    originController.dispose();
    destinationController.dispose();
    departureController.dispose();
    returnController.dispose();
    travelersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return Container(
      padding: EdgeInsets.all(mobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(mobile ? 16 : 10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ServiceTabs(
            selectedService: widget.selectedService,
            onServiceChanged: widget.onServiceChanged,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => openReservationsPage(context),
              icon: const Icon(Icons.confirmation_number_outlined, size: 18),
              label: const Text('Minhas Reservas'),
            ),
          ),
          const SizedBox(height: 20),
          TripTypeSelector(
            service: widget.selectedService,
            selectedIndex: tripType,
            onChanged: (value) => setState(() => tripType = value),
          ),
          const SizedBox(height: 20),
          ResponsiveFields(
            children: [
              SearchTextField(
                controller: originController,
                label: _originLabel(widget.selectedService),
                hint: _originHint(widget.selectedService),
                icon: Icons.trip_origin,
              ),
              SearchTextField(
                controller: destinationController,
                label: _destinationLabel(widget.selectedService),
                hint: _destinationHint(widget.selectedService),
                icon: widget.selectedService.icon,
              ),
              SearchTextField(
                controller: departureController,
                label: _departureLabel(widget.selectedService),
                hint: 'Data inicial',
                icon: Icons.calendar_today,
                readOnly: true,
                onTap: () => _pickDate(departureController),
              ),
              SearchTextField(
                controller: returnController,
                label: _returnLabel(widget.selectedService),
                hint: 'Data final',
                icon: Icons.calendar_month,
                readOnly: true,
                onTap: () => _pickDate(returnController),
              ),
              SearchTextField(
                controller: travelersController,
                label: _travelersLabel(widget.selectedService),
                hint: 'Quantidade',
                icon: Icons.keyboard_arrow_down,
                readOnly: true,
                onTap: _pickTravelers,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: TuristarColors.orange,
                foregroundColor: TuristarColors.navyDark,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                widget.selectedService.actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    widget.onSearch(
      SearchRequest(
        service: widget.selectedService,
        origin: originController.text.trim().isEmpty ? defaultRequest(widget.selectedService).origin : originController.text.trim(),
        destination: destinationController.text.trim().isEmpty ? defaultRequest(widget.selectedService).destination : destinationController.text.trim(),
        departureDate: departureController.text.trim(),
        returnDate: returnController.text.trim(),
        travelers: travelersController.text.trim(),
      ),
    );
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _parseIsoDate(controller.text) ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      helpText: 'Selecione a data',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: TuristarColors.navy,
                  secondary: TuristarColors.orange,
                ),
          ),
          child: child!,
        );
      },
    );

    if (selected != null) {
      setState(() => controller.text = _formatIsoDate(selected));
    }
  }

  Future<void> _pickTravelers() async {
    var nextAdults = adults;
    var nextChildren = children;
    var nextCars = cars;
    final isCarSearch = widget.selectedService == TravelService.cars;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCarSearch ? 'Selecionar carros' : 'Selecionar passageiros',
                    style: const TextStyle(color: TuristarColors.navy, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 18),
                  if (isCarSearch)
                    QuantityRow(
                      label: 'Carros',
                      subtitle: 'Quantidade de veiculos',
                      value: nextCars,
                      min: 1,
                      onChanged: (value) => setModalState(() => nextCars = value),
                    )
                  else ...[
                    QuantityRow(
                      label: 'Adultos',
                      subtitle: '12 anos ou mais',
                      value: nextAdults,
                      min: 1,
                      onChanged: (value) => setModalState(() => nextAdults = value),
                    ),
                    const Divider(),
                    QuantityRow(
                      label: 'Criancas',
                      subtitle: '2 a 11 anos',
                      value: nextChildren,
                      min: 0,
                      onChanged: (value) => setModalState(() => nextChildren = value),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: TuristarColors.navyDark),
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        adults = nextAdults;
        children = nextChildren;
        cars = nextCars;
        travelersController.text = isCarSearch
            ? '$cars carro${cars == 1 ? '' : 's'}, automatico'
            : '$adults adulto${adults == 1 ? '' : 's'}${children > 0 ? ', $children crianca${children == 1 ? '' : 's'}' : ''}, Economica';
      });
    }
  }

  DateTime? _parseIsoDate(String value) {
    return DateTime.tryParse(value.trim());
  }

  String _formatIsoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

String _originLabel(TravelService service) {
  switch (service) {
    case TravelService.flights:
      return 'De onde?';
    case TravelService.hotels:
      return 'Cidade';
    case TravelService.cars:
      return 'Retirada';
    case TravelService.packages:
      return 'Origem';
  }
}

String _destinationLabel(TravelService service) {
  switch (service) {
    case TravelService.flights:
      return 'Para onde?';
    case TravelService.hotels:
      return 'Hospedagem em';
    case TravelService.cars:
      return 'Devolucao';
    case TravelService.packages:
      return 'Destino';
  }
}

String _departureLabel(TravelService service) => service == TravelService.hotels ? 'Check-in' : 'Ida';
String _returnLabel(TravelService service) => service == TravelService.hotels ? 'Check-out' : 'Volta';
String _travelersLabel(TravelService service) => service == TravelService.cars ? 'Carro' : 'Passageiros';
String _originHint(TravelService service) => service == TravelService.hotels ? 'Cidade ou regiao' : 'Cidade ou aeroporto de origem';
String _destinationHint(TravelService service) => service == TravelService.cars ? 'Local de devolucao' : 'Cidade, hotel ou destino';

class ServiceTabs extends StatelessWidget {
  const ServiceTabs({
    super.key,
    required this.selectedService,
    required this.onServiceChanged,
  });

  final TravelService selectedService;
  final ValueChanged<TravelService> onServiceChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final service in TravelService.values)
          ChoiceChip(
            selected: selectedService == service,
            avatar: Icon(
              service.icon,
              size: 18,
              color: selectedService == service ? Colors.white : TuristarColors.navy,
            ),
            label: Text(service.shortLabel),
            labelStyle: TextStyle(
              color: selectedService == service ? Colors.white : TuristarColors.navy,
              fontWeight: FontWeight.w900,
            ),
            selectedColor: TuristarColors.navy,
            backgroundColor: TuristarColors.page,
            side: BorderSide(color: selectedService == service ? TuristarColors.navy : TuristarColors.line),
            onSelected: (_) => onServiceChanged(service),
          ),
      ],
    );
  }
}

class TripTypeSelector extends StatelessWidget {
  const TripTypeSelector({
    super.key,
    required this.service,
    required this.selectedIndex,
    required this.onChanged,
  });

  final TravelService service;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = _optionsFor(service);

    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: [
        for (var i = 0; i < options.length; i++)
          TripTypeTile(
            icon: options[i].icon,
            title: options[i].title,
            subtitle: options[i].subtitle,
            selected: selectedIndex == i,
            onTap: () => onChanged(i),
          ),
      ],
    );
  }

  List<TripTypeOption> _optionsFor(TravelService service) {
    switch (service) {
      case TravelService.flights:
        return const [
          TripTypeOption(Icons.sync_alt, 'Ida e Volta', 'Viagem completa'),
          TripTypeOption(Icons.flight_takeoff, 'So Ida', 'Somente ida'),
          TripTypeOption(Icons.travel_explore, 'Multidestino', 'Varios destinos'),
        ];
      case TravelService.hotels:
        return const [
          TripTypeOption(Icons.hotel, 'Hotel', 'Quartos e suites'),
          TripTypeOption(Icons.pool, 'Resort', 'Lazer completo'),
          TripTypeOption(Icons.home_work, 'Pousada', 'Estadias especiais'),
        ];
      case TravelService.cars:
        return const [
          TripTypeOption(Icons.directions_car, 'Economico', 'Menor preco'),
          TripTypeOption(Icons.car_rental, 'SUV', 'Mais conforto'),
          TripTypeOption(Icons.electric_car, 'Eletrico', 'Baixa emissao'),
        ];
      case TravelService.packages:
        return const [
          TripTypeOption(Icons.beach_access, 'Praia', 'Sol e descanso'),
          TripTypeOption(Icons.location_city, 'Urbano', 'Cidades icones'),
          TripTypeOption(Icons.family_restroom, 'Familia', 'Viagem completa'),
        ];
    }
  }
}

class TripTypeOption {
  const TripTypeOption(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
}

class TripTypeTile extends StatelessWidget {
  const TripTypeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minWidth: 190),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? TuristarColors.orange.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? TuristarColors.orange : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TuristarColors.orange, size: 23),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
                Text(subtitle, style: const TextStyle(color: TuristarColors.muted, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ResponsiveFields extends StatelessWidget {
  const ResponsiveFields({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 650 ? 1 : (width < 980 ? 2 : 3);
        final spacing = 14.0;
        final itemWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class SearchTextField extends StatelessWidget {
  const SearchTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: Icon(icon, color: TuristarColors.navy, size: 19),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TuristarColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TuristarColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TuristarColors.orange, width: 2),
        ),
      ),
    );
  }
}

class QuantityRow extends StatelessWidget {
  const QuantityRow({
    super.key,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
              Text(subtitle, style: const TextStyle(color: TuristarColors.muted, fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          onPressed: value <= min ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 38,
          child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        IconButton(
          onPressed: value >= 9 ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class HeroStats extends StatelessWidget {
  const HeroStats({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final stats = const [
      (Icons.travel_explore, '100+', 'Destinos', 'Ao redor do mundo'),
      (Icons.support_agent, '24/7', 'Suporte', 'Atendimento sempre'),
      (Icons.verified_user, 'Seguranca', 'Total', 'Seus dados protegidos'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: mobile ? 16 : 90,
          runSpacing: 18,
          children: [
            for (final stat in stats)
              SizedBox(
                width: mobile ? constraints.maxWidth : 245,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: TuristarColors.orange, width: 2),
                      ),
                      child: Icon(stat.$1, color: TuristarColors.orange),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stat.$2, style: const TextStyle(color: TuristarColors.orange, fontSize: 18, fontWeight: FontWeight.w900)),
                        Text(stat.$3, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        Text(stat.$4, style: TextStyle(color: Colors.white.withOpacity(0.74), fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class ServicesSection extends StatelessWidget {
  const ServicesSection({super.key, required this.onServiceSelected});

  final ValueChanged<TravelService> onServiceSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: Responsive.isMobile(context) ? 28 : 38),
      child: LayoutShell(
        child: Column(
          children: [
            const SectionHeading(title: 'Nossos Servicos', subtitle: 'Tudo que voce precisa para sua viagem em um so lugar'),
            const SizedBox(height: 28),
            ResponsiveCardGrid(
              minCardWidth: 240,
              children: [
                ServiceCard(service: TravelService.flights, onTap: () => onServiceSelected(TravelService.flights)),
                ServiceCard(service: TravelService.hotels, onTap: () => onServiceSelected(TravelService.hotels)),
                ServiceCard(service: TravelService.cars, onTap: () => onServiceSelected(TravelService.cars)),
                ServiceCard(service: TravelService.packages, onTap: () => onServiceSelected(TravelService.packages)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.minCardWidth = 260,
    this.spacing = 18,
  });

  final List<Widget> children;
  final double minCardWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = (width / minCardWidth).floor().clamp(1, 4).toInt();
        final itemWidth = (width - spacing * (count - 1)) / count;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service, required this.onTap});

  final TravelService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = _serviceCopy(service);
    return Container(
      height: 252,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TuristarColors.line),
        boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(color: data.background, shape: BoxShape.circle),
            child: Icon(service.icon, color: data.iconColor, size: 32),
          ),
          const SizedBox(height: 15),
          Text(service.label, textAlign: TextAlign.center, style: const TextStyle(color: TuristarColors.navy, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            data.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: TuristarColors.muted, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: TuristarColors.navy,
              side: const BorderSide(color: TuristarColors.navy),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: const Size(0, 40),
            ),
            child: Text(service.actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

ServiceCopy _serviceCopy(TravelService service) {
  switch (service) {
    case TravelService.flights:
      return const ServiceCopy(Color(0xFFEAF2FF), Color(0xFF4E8DFF), 'Milhares de rotas com as melhores companhias');
    case TravelService.hotels:
      return const ServiceCopy(Color(0xFFFFF2D8), Color(0xFFF6A313), 'Hoteis, pousadas e resorts com tarifas competitivas');
    case TravelService.cars:
      return const ServiceCopy(Color(0xFFE1F8EC), Color(0xFF1DBE72), 'Retire seu carro no aeroporto ou cidade de destino');
    case TravelService.packages:
      return const ServiceCopy(Color(0xFFF1E8FF), Color(0xFF7C3AED), 'Monte viagem completa com voo, hotel e experiencias');
  }
}

class ServiceCopy {
  const ServiceCopy(this.background, this.iconColor, this.description);

  final Color background;
  final Color iconColor;
  final String description;
}

class WhyChooseSection extends StatelessWidget {
  const WhyChooseSection({super.key});

  @override
  Widget build(BuildContext context) {
    final benefits = const [
      BenefitData(Icons.credit_card, 'Melhor Preco', 'Garantimos os melhores precos do mercado para sua viagem'),
      BenefitData(Icons.refresh, 'Protecao de Compra', 'Sua compra 100% protegida com garantia de reembolso'),
      BenefitData(Icons.verified_user, 'Confianca Comprovada', 'Mais de 100.000 clientes satisfeitos ao redor do mundo'),
      BenefitData(Icons.local_offer, 'Ofertas Exclusivas', 'Acesso a ofertas especiais e promocoes VIP'),
      BenefitData(Icons.public, 'Cobertura Global', 'Atendemos em mais de 100 paises e 1.000 destinos'),
      BenefitData(Icons.lock, 'Pagamento Seguro', 'Seus dados e pagamentos protegidos com criptografia'),
      BenefitData(Icons.support_agent, 'Suporte 24/7', 'Nossa equipe esta sempre disponivel para ajudar voce'),
      BenefitData(Icons.swap_calls, 'Flexibilidade Total', 'Altere ou cancele sua viagem com facilidade'),
    ];

    return Container(
      color: TuristarColors.page,
      padding: const EdgeInsets.only(top: 18, bottom: 28),
      child: LayoutShell(
        child: Column(
          children: [
            const SectionHeading(title: 'Por Que Escolher Turistar?', subtitle: 'Somos lideres em inovacao e atendimento no mercado de viagens'),
            const SizedBox(height: 18),
            ResponsiveCardGrid(
              minCardWidth: 430,
              spacing: 12,
              children: [
                for (final benefit in benefits) BenefitTile(benefit: benefit),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BenefitData {
  const BenefitData(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}

class BenefitTile extends StatelessWidget {
  const BenefitTile({super.key, required this.benefit});

  final BenefitData benefit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Row(
        children: [
          Icon(benefit.icon, color: TuristarColors.navy, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(benefit.title, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 13)),
                Text(benefit.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TuristarColors.muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CallToActionSection extends StatelessWidget {
  const CallToActionSection({super.key, required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return Container(
      color: TuristarColors.page,
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutShell(
        child: Container(
          padding: EdgeInsets.all(mobile ? 18 : 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [TuristarColors.navy, Color(0xFF2D3329), TuristarColors.orangeDark],
            ),
          ),
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CtaCopy(),
                    const SizedBox(height: 18),
                    SizedBox(width: double.infinity, child: CtaButton(onSearch: onSearch)),
                  ],
                )
              : Row(
                  children: [
                    const Expanded(child: CtaCopy()),
                    CtaButton(onSearch: onSearch),
                  ],
                ),
        ),
      ),
    );
  }
}

class CtaCopy extends StatelessWidget {
  const CtaCopy({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Row(
      children: [
        Container(
          width: mobile ? 58 : 74,
          height: mobile ? 58 : 74,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(Icons.flight_takeoff, color: TuristarColors.orange, size: mobile ? 32 : 42),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pronto para Comecar?', style: TextStyle(color: Colors.white, fontSize: mobile ? 21 : 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Encontre as melhores opcoes de viagem para seu proximo destino', style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

class CtaButton extends StatelessWidget {
  const CtaButton({super.key, required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Responsive.isMobile(context) ? double.infinity : 230,
      height: 58,
      child: ElevatedButton(
        onPressed: onSearch,
        style: ElevatedButton.styleFrom(
          backgroundColor: TuristarColors.navy,
          foregroundColor: Colors.white,
          side: const BorderSide(color: TuristarColors.orange, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          elevation: 8,
          shadowColor: TuristarColors.orange.withOpacity(0.45),
        ),
        child: const Text('Buscar Agora', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: TuristarColors.navy,
            fontSize: Responsive.isMobile(context) ? 23 : 27,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: TuristarColors.muted, fontSize: 13)),
      ],
    );
  }
}

class FooterSection extends StatelessWidget {
  const FooterSection({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 880;

    return Container(
      color: TuristarColors.navyDark,
      padding: const EdgeInsets.only(top: 34, bottom: 24),
      child: LayoutShell(
        child: Column(
          children: [
            compact
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FooterBrand(),
                      SizedBox(height: 26),
                      FooterLinks(),
                    ],
                  )
                : const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: FooterBrand()),
                      Expanded(flex: 5, child: FooterLinks()),
                    ],
                  ),
            const SizedBox(height: 28),
            Divider(color: Colors.white.withOpacity(0.12)),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '(c) 2024 Turistar Viagens e Turismo Ltda. Todos os direitos reservados.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                if (!compact) const PaymentBadges(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FooterBrand extends StatelessWidget {
  const FooterBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandLogo(onDark: true),
        const SizedBox(height: 18),
        const Text(
          'A Turistar e sua parceira de confianca para viagens inesqueciveis.',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        const SizedBox(height: 18),
        Row(
          children: const [
            SocialDot(label: 'f'),
            SocialDot(label: 'ig'),
            SocialDot(label: 'in'),
            SocialDot(label: 'x'),
            SocialDot(label: 'yt'),
          ],
        ),
      ],
    );
  }
}

class SocialDot extends StatelessWidget {
  const SocialDot({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

class FooterLinks extends StatelessWidget {
  const FooterLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 60,
      runSpacing: 24,
      children: const [
        FooterColumn(title: 'Servicos', items: ['Passagens Aereas', 'Hospedagens', 'Aluguel de Carros', 'Pacotes de Viagem', 'Seguros Viagem']),
        FooterColumn(title: 'Empresa', items: ['Sobre Nos', 'Trabalhe Conosco', 'Politica de Privacidade', 'Termos de Uso', 'Imprensa']),
        FooterColumn(title: 'Ajuda', items: ['Central de Ajuda', 'Fale Conosco', 'Perguntas Frequentes', 'Politica de Reembolso']),
        FooterContact(),
      ],
    );
  }
}

class FooterColumn extends StatelessWidget {
  const FooterColumn({super.key, required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Text(item, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class FooterContact extends StatelessWidget {
  const FooterContact({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Contato', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          SizedBox(height: 14),
          ContactLine(icon: Icons.phone, label: '(11) 4002-8922'),
          ContactLine(icon: Icons.mail, label: 'contato@turistar.com.br'),
          ContactLine(icon: Icons.access_time, label: 'Atendimento 24/7'),
        ],
      ),
    );
  }
}

class ContactLine extends StatelessWidget {
  const ContactLine({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: TuristarColors.orange, size: 16),
          const SizedBox(width: 10),
          Flexible(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }
}

class PaymentBadges extends StatelessWidget {
  const PaymentBadges({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        PaymentBadge(label: 'VISA'),
        PaymentBadge(label: 'MC'),
        PaymentBadge(label: 'elo'),
        PaymentBadge(label: 'pix'),
      ],
    );
  }
}

class PaymentBadge extends StatelessWidget {
  const PaymentBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key, required this.request});

  final SearchRequest request;

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  late final Future<SearchResultState> resultsFuture;

  @override
  void initState() {
    super.initState();
    resultsFuture = SearchRepository().search(widget.request);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: Text('${widget.request.service.shortLabel} encontrados'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: Responsive.isMobile(context) ? 18 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.request.origin} para ${widget.request.destination}',
                style: TextStyle(
                  color: TuristarColors.navy,
                  fontSize: Responsive.isMobile(context) ? 23 : 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${widget.request.departureDate} - ${widget.request.returnDate} - ${widget.request.travelers}',
                style: const TextStyle(color: TuristarColors.muted),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<SearchResultState>(
                  future: resultsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final state = snapshot.data ??
                        SearchResultState(
                          items: SearchCatalog.resultsFor(widget.request),
                          source: SearchResultSource.mock,
                          notice: 'Nao foi possivel carregar a API. Exibindo dados demonstrativos.',
                        );

                    return Column(
                      children: [
                        ResultSummary(state: state, service: widget.request.service),
                        const SizedBox(height: 18),
                        Expanded(
                          child: state.items.isEmpty
                              ? const EmptyResults()
                              : ListView.separated(
                                  itemCount: state.items.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                                  itemBuilder: (context, index) {
                                    final item = state.items[index];
                                    return SearchResultCard(
                                      item: item,
                                      onSelect: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => PassengerDetailsPage(
                                              request: widget.request,
                                              offer: item,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResultSummary extends StatelessWidget {
  const ResultSummary({super.key, required this.state, required this.service});

  final SearchResultState state;
  final TravelService service;

  @override
  Widget build(BuildContext context) {
    final usingApi = state.source == SearchResultSource.api;
    final message = state.notice ??
        (usingApi
            ? '${state.items.length} ofertas reais retornadas pelo provedor configurado.'
            : '${state.items.length} ofertas demonstrativas. Configure o backend para dados reais.');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Row(
        children: [
          Icon(service.icon, color: TuristarColors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyResults extends StatelessWidget {
  const EmptyResults({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Nenhum resultado encontrado. Ajuste a busca e tente novamente.'),
    );
  }
}

class SearchResultCard extends StatelessWidget {
  const SearchResultCard({super.key, required this.item, required this.onSelect});

  final SearchResultItem item;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Container(
      padding: EdgeInsets.all(mobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TuristarColors.line),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 14, offset: Offset(0, 8))],
      ),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ResultInfo(item: item),
                const SizedBox(height: 14),
                _ResultPrice(item: item, onSelect: onSelect),
              ],
            )
          : Row(
              children: [
                Expanded(child: _ResultInfo(item: item)),
                const SizedBox(width: 18),
                _ResultPrice(item: item, onSelect: onSelect),
              ],
            ),
    );
  }
}

class _ResultInfo extends StatelessWidget {
  const _ResultInfo({required this.item});

  final SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: TuristarColors.orange.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(item.icon, color: TuristarColors.orange),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: const TextStyle(color: TuristarColors.navy, fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(item.subtitle, style: const TextStyle(color: TuristarColors.muted)),
              const SizedBox(height: 5),
              Text(item.details, style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(item.badge, style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultPrice extends StatelessWidget {
  const _ResultPrice({required this.item, required this.onSelect});

  final SearchResultItem item;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: Responsive.isMobile(context) ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(item.price, style: const TextStyle(color: TuristarColors.orange, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: onSelect,
          style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: TuristarColors.navyDark),
          child: const Text('Selecionar'),
        ),
      ],
    );
  }
}

class PassengerInfo {
  const PassengerInfo({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.document,
    required this.birthDate,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String document;
  final String birthDate;

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'document': document,
      'birthDate': birthDate,
    };
  }
}

class BookingDraft {
  const BookingDraft({
    required this.request,
    required this.offer,
    required this.passenger,
    required this.fareRules,
  });

  final SearchRequest request;
  final SearchResultItem offer;
  final PassengerInfo passenger;
  final FareRules fareRules;
}

class FareRules {
  const FareRules({
    required this.summary,
    required this.penalty,
    required this.baggage,
    required this.refundable,
  });

  final String summary;
  final String penalty;
  final String baggage;
  final bool refundable;
}

class BookingConfirmation {
  const BookingConfirmation({
    required this.locator,
    required this.status,
    required this.provider,
    required this.createdAt,
  });

  final String locator;
  final String status;
  final String provider;
  final DateTime createdAt;
}

class ReservationHistoryItem {
  const ReservationHistoryItem({
    required this.locator,
    required this.route,
    required this.passenger,
    required this.date,
    required this.status,
    required this.price,
  });

  final String locator;
  final String route;
  final String passenger;
  final String date;
  final String status;
  final String price;
}

const reservationHistory = [
  ReservationHistoryItem(
    locator: 'TST482913',
    route: 'GRU - MIA',
    passenger: 'Daniel Rodrigues',
    date: '2026-06-20',
    status: 'RESERVED',
    price: 'R\$ 1.200',
  ),
  ReservationHistoryItem(
    locator: 'TST194820',
    route: 'VCP - LIS',
    passenger: 'Cliente Turistar',
    date: '2026-07-04',
    status: 'QUOTE',
    price: 'R\$ 3.490',
  ),
];

class MyReservationsPage extends StatelessWidget {
  const MyReservationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Minhas Reservas'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: ListView(
            children: [
              const BookingStepHeader(
                step: 'Area do cliente',
                title: 'Historico de reservas',
                subtitle: 'Consulte localizadores, acompanhe status e cancele reservas em homologacao.',
              ),
              const SizedBox(height: 18),
              for (final reservation in reservationHistory)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: ReservationHistoryCard(reservation: reservation),
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TuristarColors.orange.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TuristarColors.orange.withOpacity(0.35)),
                ),
                child: const Text(
                  'Quando conectarmos o banco SQL, este historico sera carregado por usuario autenticado.',
                  style: TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReservationHistoryCard extends StatelessWidget {
  const ReservationHistoryCard({super.key, required this.reservation});

  final ReservationHistoryItem reservation;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TuristarColors.line),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 14, offset: Offset(0, 8))],
      ),
      child: mobile ? _mobileContent() : _desktopContent(),
    );
  }

  Widget _desktopContent() {
    return Row(
      children: [
        _icon(),
        const SizedBox(width: 16),
        Expanded(child: _details()),
        const SizedBox(width: 16),
        _priceAndStatus(CrossAxisAlignment.end),
      ],
    );
  }

  Widget _mobileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _icon(),
        const SizedBox(height: 12),
        _details(),
        const SizedBox(height: 14),
        _priceAndStatus(CrossAxisAlignment.start),
      ],
    );
  }

  Widget _icon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: TuristarColors.orange.withOpacity(0.12), shape: BoxShape.circle),
      child: const Icon(Icons.confirmation_number_outlined, color: TuristarColors.orange),
    );
  }

  Widget _details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(reservation.locator, style: const TextStyle(color: TuristarColors.navy, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('${reservation.route} | ${reservation.date}', style: const TextStyle(color: TuristarColors.muted)),
        const SizedBox(height: 4),
        Text(reservation.passenger, style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _priceAndStatus(CrossAxisAlignment alignment) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(reservation.price, style: const TextStyle(color: TuristarColors.orange, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Chip(label: Text(reservation.status), backgroundColor: TuristarColors.page),
      ],
    );
  }
}

class PassengerDetailsPage extends StatefulWidget {
  const PassengerDetailsPage({
    super.key,
    required this.request,
    required this.offer,
  });

  final SearchRequest request;
  final SearchResultItem offer;

  @override
  State<PassengerDetailsPage> createState() => _PassengerDetailsPageState();
}

class _PassengerDetailsPageState extends State<PassengerDetailsPage> {
  final formKey = GlobalKey<FormState>();
  final firstNameController = TextEditingController(text: 'Daniel');
  final lastNameController = TextEditingController(text: 'Rodrigues');
  final emailController = TextEditingController(text: 'cliente@turistar.com.br');
  final phoneController = TextEditingController(text: '11999999999');
  final documentController = TextEditingController(text: '12345678900');
  final birthDateController = TextEditingController(text: '1990-01-01');
  late final Future<FareRules> rulesFuture;

  @override
  void initState() {
    super.initState();
    rulesFuture = BookingRepository().getFareRules(widget.offer);
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    documentController.dispose();
    birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Dados do passageiro'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: mobile ? 18 : 28),
          child: ListView(
            children: [
              BookingStepHeader(
                step: 'Etapa 2 de 4',
                title: 'Informe os dados para reservar',
                subtitle: 'Esses campos antecipam o checklist de homologacao Wooba.',
              ),
              const SizedBox(height: 18),
              OfferSummaryCard(offer: widget.offer),
              const SizedBox(height: 18),
              FutureBuilder<FareRules>(
                future: rulesFuture,
                builder: (context, snapshot) {
                  final rules = snapshot.data ?? BookingRepository.mockFareRules(widget.offer);
                  return FareRulesCard(rules: rules);
                },
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TuristarColors.line),
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Passageiro adulto', style: TextStyle(color: TuristarColors.navy, fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 16),
                      ResponsiveFields(
                        children: [
                          BookingTextField(controller: firstNameController, label: 'Nome', icon: Icons.person_outline),
                          BookingTextField(controller: lastNameController, label: 'Sobrenome', icon: Icons.person_outline),
                          BookingTextField(controller: emailController, label: 'E-mail', icon: Icons.mail_outline, keyboardType: TextInputType.emailAddress),
                          BookingTextField(controller: phoneController, label: 'Telefone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                          BookingTextField(controller: documentController, label: 'CPF ou documento', icon: Icons.badge_outlined),
                          BookingTextField(controller: birthDateController, label: 'Nascimento (YYYY-MM-DD)', icon: Icons.calendar_today),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _continueToReview,
                          style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: TuristarColors.navyDark),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Revisar reserva'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continueToReview() async {
    if (formKey.currentState?.validate() != true) return;

    final rules = await rulesFuture.catchError((_) => BookingRepository.mockFareRules(widget.offer));
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingReviewPage(
          draft: BookingDraft(
            request: widget.request,
            offer: widget.offer,
            passenger: PassengerInfo(
              firstName: firstNameController.text.trim(),
              lastName: lastNameController.text.trim(),
              email: emailController.text.trim(),
              phone: phoneController.text.trim(),
              document: documentController.text.trim(),
              birthDate: birthDateController.text.trim(),
            ),
            fareRules: rules,
          ),
        ),
      ),
    );
  }
}

class BookingReviewPage extends StatefulWidget {
  const BookingReviewPage({super.key, required this.draft});

  final BookingDraft draft;

  @override
  State<BookingReviewPage> createState() => _BookingReviewPageState();
}

class _BookingReviewPageState extends State<BookingReviewPage> {
  bool acceptedRules = true;
  bool creating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Revisar reserva'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: ListView(
            children: [
              const BookingStepHeader(
                step: 'Etapa 3 de 4',
                title: 'Revise antes de criar a reserva',
                subtitle: 'Na homologacao, esta etapa corresponde ao pre-booking/reserva.',
              ),
              const SizedBox(height: 18),
              OfferSummaryCard(offer: widget.draft.offer),
              const SizedBox(height: 18),
              PassengerSummaryCard(passenger: widget.draft.passenger),
              const SizedBox(height: 18),
              FareRulesCard(rules: widget.draft.fareRules),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: acceptedRules,
                activeColor: TuristarColors.orange,
                onChanged: creating ? null : (value) => setState(() => acceptedRules = value ?? false),
                title: const Text('Confirmo que revisei dados do passageiro e regras tarifarias.'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: acceptedRules && !creating ? _createBooking : null,
                style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: TuristarColors.navyDark),
                icon: creating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.confirmation_number_outlined),
                label: Text(creating ? 'Criando reserva...' : 'Criar reserva mock'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createBooking() async {
    setState(() => creating = true);
    final confirmation = await BookingRepository().createBooking(widget.draft);
    if (!mounted) return;
    setState(() => creating = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BookingConfirmationPage(
          draft: widget.draft,
          confirmation: confirmation,
        ),
      ),
    );
  }
}

class BookingConfirmationPage extends StatefulWidget {
  const BookingConfirmationPage({
    super.key,
    required this.draft,
    required this.confirmation,
  });

  final BookingDraft draft;
  final BookingConfirmation confirmation;

  @override
  State<BookingConfirmationPage> createState() => _BookingConfirmationPageState();
}

class _BookingConfirmationPageState extends State<BookingConfirmationPage> {
  bool cancelled = false;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final status = cancelled ? 'CANCELLED' : widget.confirmation.status;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Reserva criada'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: ListView(
            children: [
              BookingStepHeader(
                step: 'Etapa 4 de 4',
                title: 'Localizador ${widget.confirmation.locator}',
                subtitle: 'Status: $status | Provedor: ${widget.confirmation.provider}',
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TuristarColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(cancelled ? Icons.cancel_outlined : Icons.check_circle_outline, color: cancelled ? Colors.red : TuristarColors.green, size: 42),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            cancelled ? 'Reserva cancelada no fluxo mock' : 'Reserva mock criada com sucesso',
                            style: const TextStyle(color: TuristarColors.navy, fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    OfferSummaryCard(offer: widget.draft.offer),
                    const SizedBox(height: 18),
                    PassengerSummaryCard(passenger: widget.draft.passenger),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy ? null : _consultBooking,
                          icon: const Icon(Icons.search),
                          label: const Text('Consultar reserva'),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy || cancelled ? null : _cancelBooking,
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancelar reserva'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                          style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: TuristarColors.navyDark),
                          icon: const Icon(Icons.home_outlined),
                          label: const Text('Voltar para busca'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _consultBooking() async {
    setState(() => busy = true);
    final result = await BookingRepository().getBooking(widget.confirmation.locator);
    if (!mounted) return;
    setState(() => busy = false);
    _showMessage('Consulta mock: ${result.status} (${result.locator})');
  }

  Future<void> _cancelBooking() async {
    setState(() => busy = true);
    final result = await BookingRepository().cancelBooking(widget.confirmation.locator);
    if (!mounted) return;
    setState(() {
      busy = false;
      cancelled = result.status == 'CANCELLED';
    });
    _showMessage('Cancelamento mock confirmado: ${result.locator}');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: TuristarColors.navy),
    );
  }
}

class BookingStepHeader extends StatelessWidget {
  const BookingStepHeader({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final String step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(step, style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(color: TuristarColors.navy, fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: TuristarColors.muted)),
      ],
    );
  }
}

class OfferSummaryCard extends StatelessWidget {
  const OfferSummaryCard({super.key, required this.offer});

  final SearchResultItem offer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Row(
        children: [
          Icon(offer.icon, color: TuristarColors.orange, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.title, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 4),
                Text(offer.subtitle, style: const TextStyle(color: TuristarColors.muted)),
                const SizedBox(height: 4),
                Text(offer.details, style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Text(offer.price, style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w900, fontSize: 20)),
        ],
      ),
    );
  }
}

class FareRulesCard extends StatelessWidget {
  const FareRulesCard({super.key, required this.rules});

  final FareRules rules;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Regras tarifarias', style: TextStyle(color: TuristarColors.navy, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(rules.summary, style: const TextStyle(color: TuristarColors.text)),
          const SizedBox(height: 6),
          Text('Bagagem: ${rules.baggage}', style: const TextStyle(color: TuristarColors.muted)),
          const SizedBox(height: 6),
          Text('Penalidade: ${rules.penalty}', style: const TextStyle(color: TuristarColors.muted)),
          const SizedBox(height: 6),
          Text(rules.refundable ? 'Tarifa reembolsavel' : 'Tarifa nao reembolsavel', style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class PassengerSummaryCard extends StatelessWidget {
  const PassengerSummaryCard({super.key, required this.passenger});

  final PassengerInfo passenger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Passageiro', style: TextStyle(color: TuristarColors.navy, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text('${passenger.firstName} ${passenger.lastName}', style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w800)),
          Text(passenger.email, style: const TextStyle(color: TuristarColors.muted)),
          Text('Documento: ${passenger.document} | Nascimento: ${passenger.birthDate}', style: const TextStyle(color: TuristarColors.muted)),
        ],
      ),
    );
  }
}

class BookingTextField extends StatelessWidget {
  const BookingTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Campo obrigatorio';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: TuristarColors.orange),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class BookingRepository {
  BookingRepository({BookingGateway? gateway}) : gateway = gateway ?? const BookingGateway();

  final BookingGateway gateway;

  static FareRules mockFareRules(SearchResultItem offer) {
    return FareRules(
      summary: 'Regra mock para ${offer.title}. Confirmar politica final no retorno Wooba.',
      penalty: 'Alteracao/cancelamento sujeito a multa e diferenca tarifaria.',
      baggage: '1 bagagem de mao inclusa. Bagagem despachada conforme tarifa.',
      refundable: false,
    );
  }

  Future<FareRules> getFareRules(SearchResultItem offer) async {
    try {
      return await gateway.getFareRules(offer);
    } catch (_) {
      return mockFareRules(offer);
    }
  }

  Future<BookingConfirmation> createBooking(BookingDraft draft) async {
    try {
      return await gateway.createBooking(draft);
    } catch (_) {
      return BookingConfirmation(
        locator: 'TST${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        status: 'RESERVED',
        provider: 'mock',
        createdAt: DateTime.now(),
      );
    }
  }

  Future<BookingConfirmation> getBooking(String locator) async {
    try {
      return await gateway.getBooking(locator);
    } catch (_) {
      return BookingConfirmation(locator: locator, status: 'RESERVED', provider: 'mock', createdAt: DateTime.now());
    }
  }

  Future<BookingConfirmation> cancelBooking(String locator) async {
    try {
      return await gateway.cancelBooking(locator);
    } catch (_) {
      return BookingConfirmation(locator: locator, status: 'CANCELLED', provider: 'mock', createdAt: DateTime.now());
    }
  }
}

class BookingGateway {
  const BookingGateway({http.Client? client}) : _client = client;

  static const apiBaseUrl = String.fromEnvironment('TURISTAR_FLIGHTS_API_BASE_URL');
  final http.Client? _client;

  Future<FareRules> getFareRules(SearchResultItem offer) async {
    final decoded = await _get('flights/rules', {'offerId': offer.id ?? offer.title});
    return FareRules(
      summary: decoded['summary']?.toString() ?? 'Regras recebidas do provedor.',
      penalty: decoded['penalty']?.toString() ?? 'Consultar penalidade.',
      baggage: decoded['baggage']?.toString() ?? 'Consultar bagagem.',
      refundable: decoded['refundable'] == true,
    );
  }

  Future<BookingConfirmation> createBooking(BookingDraft draft) async {
    final decoded = await _post('bookings/create', {
      'offer': {
        'id': draft.offer.id,
        'title': draft.offer.title,
        'subtitle': draft.offer.subtitle,
        'price': draft.offer.price,
      },
      'passenger': draft.passenger.toJson(),
      'request': {
        'origin': draft.request.origin,
        'destination': draft.request.destination,
        'departureDate': draft.request.departureDate,
        'returnDate': draft.request.returnDate,
        'travelers': draft.request.travelers,
      },
    });
    return _confirmationFromJson(decoded);
  }

  Future<BookingConfirmation> getBooking(String locator) async {
    final decoded = await _get('bookings/get', {'locator': locator});
    return _confirmationFromJson(decoded);
  }

  Future<BookingConfirmation> cancelBooking(String locator) async {
    final decoded = await _post('bookings/cancel', {'locator': locator});
    return _confirmationFromJson(decoded);
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, String> queryParameters) async {
    final uri = _uri(path, queryParameters);
    final client = _client ?? http.Client();
    try {
      final response = await client.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 18));
      return _decode(response);
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> payload) async {
    final uri = _uri(path, const {});
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(uri, headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'}, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 18));
      return _decode(response);
    } finally {
      if (_client == null) client.close();
    }
  }

  Uri _uri(String path, Map<String, String> queryParameters) {
    if (apiBaseUrl.trim().isEmpty) throw const FormatException('TURISTAR_FLIGHTS_API_BASE_URL not configured');
    final base = Uri.parse(apiBaseUrl);
    final normalizedPath = base.path.endsWith('/') ? '${base.path}$path' : '${base.path}/$path';
    return base.replace(path: normalizedPath, queryParameters: queryParameters.isEmpty ? null : queryParameters);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Booking API returned HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Unexpected booking response');
    return decoded;
  }

  BookingConfirmation _confirmationFromJson(Map<String, dynamic> json) {
    return BookingConfirmation(
      locator: json['locator']?.toString() ?? json['localizador']?.toString() ?? 'TST0000',
      status: json['status']?.toString() ?? 'RESERVED',
      provider: json['provider']?.toString() ?? json['source']?.toString() ?? 'mock',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

enum SearchResultSource { mock, api }

class SearchResultState {
  const SearchResultState({
    required this.items,
    required this.source,
    this.notice,
  });

  final List<SearchResultItem> items;
  final SearchResultSource source;
  final String? notice;
}

class SearchRepository {
  SearchRepository({FlightOffersGateway? flightOffersGateway})
      : flightOffersGateway = flightOffersGateway ?? const FlightOffersGateway();

  final FlightOffersGateway flightOffersGateway;

  Future<SearchResultState> search(SearchRequest request) async {
    if (request.service != TravelService.flights) {
      return SearchResultState(
        items: SearchCatalog.resultsFor(request),
        source: SearchResultSource.mock,
        notice: 'Busca de ${request.service.shortLabel.toLowerCase()} ainda usa dados demonstrativos.',
      );
    }

    try {
      final apiItems = await flightOffersGateway.search(request);
      if (apiItems.isEmpty) {
        return SearchResultState(
          items: SearchCatalog.resultsFor(request),
          source: SearchResultSource.mock,
          notice: 'O provedor nao retornou ofertas para esta rota. Exibindo ofertas demonstrativas para continuar o teste.',
        );
      }

      return SearchResultState(
        items: apiItems,
        source: SearchResultSource.api,
      );
    } catch (error) {
      return SearchResultState(
        items: SearchCatalog.resultsFor(request),
        source: SearchResultSource.mock,
        notice: 'API do provedor indisponivel ou nao configurada. Exibindo dados demonstrativos.',
      );
    }
  }
}

class FlightOffersGateway {
  const FlightOffersGateway({http.Client? client}) : _client = client;

  static const apiBaseUrl = String.fromEnvironment('TURISTAR_FLIGHTS_API_BASE_URL');
  final http.Client? _client;

  Future<List<SearchResultItem>> search(SearchRequest request) async {
    if (apiBaseUrl.trim().isEmpty) {
      throw const FormatException('TURISTAR_FLIGHTS_API_BASE_URL not configured');
    }

    final client = _client ?? http.Client();
    final uri = _searchUri(request);

    try {
      final response = await client.get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 18));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Flight API returned HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected flight API response');
      }

      return FlightOffersParser.parse(decoded);
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Uri _searchUri(SearchRequest request) {
    final base = Uri.parse(apiBaseUrl);
    final path = base.path.endsWith('/')
        ? '${base.path}flights/search'
        : '${base.path}/flights/search';

    return base.replace(
      path: path,
      queryParameters: {
        'originLocationCode': _iataCode(request.origin),
        'destinationLocationCode': _iataCode(request.destination),
        'departureDate': _dateToIso(request.departureDate),
        if (request.returnDate.trim().isNotEmpty) 'returnDate': _dateToIso(request.returnDate),
        'adults': _adults(request.travelers).toString(),
        'currencyCode': 'BRL',
        'max': '10',
      },
    );
  }

  String _iataCode(String value) {
    return LocationResolver.codeFor(value);
  }

  int _adults(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return int.tryParse(match?.group(0) ?? '')?.clamp(1, 9).toInt() ?? 1;
  }

  String _dateToIso(String value) {
    final trimmed = value.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      return trimmed;
    }

    final match = RegExp(r'(\d{1,2})\s+de\s+([A-Za-z]+),?\s+(\d{4})', caseSensitive: false).firstMatch(trimmed);
    if (match == null) {
      return DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T').first;
    }

    final day = match.group(1)!.padLeft(2, '0');
    final month = _monthNumber(match.group(2)!);
    final year = match.group(3)!;
    return '$year-$month-$day';
  }

  String _monthNumber(String monthName) {
    final months = {
      'janeiro': '01',
      'fevereiro': '02',
      'marco': '03',
      'abril': '04',
      'maio': '05',
      'junho': '06',
      'julho': '07',
      'agosto': '08',
      'setembro': '09',
      'outubro': '10',
      'novembro': '11',
      'dezembro': '12',
    };
    return months[monthName.toLowerCase()] ?? '06';
  }
}

class FlightOffersParser {
  const FlightOffersParser._();

  static List<SearchResultItem> parse(Map<String, dynamic> payload) {
    final normalizedItems = payload['items'];
    if (normalizedItems is List) {
      return normalizedItems.whereType<Map<String, dynamic>>().map(_fromNormalized).toList();
    }

    final data = payload['data'];
    if (data is! List) {
      return const [];
    }

    return data.whereType<Map<String, dynamic>>().map(_fromAmadeusOffer).toList();
  }

  static SearchResultItem _fromNormalized(Map<String, dynamic> item) {
    return SearchResultItem(
      title: item['title']?.toString() ?? 'Oferta de voo',
      subtitle: item['subtitle']?.toString() ?? '',
      details: item['details']?.toString() ?? '',
      price: item['price']?.toString() ?? 'Consultar',
      badge: item['badge']?.toString() ?? 'API Amadeus',
      icon: Icons.flight_takeoff,
      fromApi: true,
    );
  }

  static SearchResultItem _fromAmadeusOffer(Map<String, dynamic> offer) {
    final itineraries = offer['itineraries'];
    final firstItinerary = itineraries is List && itineraries.isNotEmpty && itineraries.first is Map<String, dynamic>
        ? itineraries.first as Map<String, dynamic>
        : const <String, dynamic>{};

    final segments = firstItinerary['segments'];
    final typedSegments = segments is List ? segments.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
    final firstSegment = typedSegments.isNotEmpty ? typedSegments.first : const <String, dynamic>{};
    final lastSegment = typedSegments.isNotEmpty ? typedSegments.last : firstSegment;

    final carrier = firstSegment['carrierCode']?.toString() ?? _firstString(offer['validatingAirlineCodes']) ?? 'Cia aerea';
    final flightNumber = firstSegment['number']?.toString();
    final departure = _locationCode(firstSegment['departure']);
    final arrival = _locationCode(lastSegment['arrival']);
    final departureTime = _time(firstSegment['departure']);
    final arrivalTime = _time(lastSegment['arrival']);
    final duration = _duration(firstItinerary['duration']?.toString());
    final stops = typedSegments.length <= 1 ? 'Direto' : '${typedSegments.length - 1} parada(s)';
    final price = offer['price'] is Map<String, dynamic> ? offer['price'] as Map<String, dynamic> : const <String, dynamic>{};
    final currency = price['currency']?.toString() ?? 'BRL';
    final total = price['grandTotal']?.toString() ?? price['total']?.toString() ?? 'Consultar';
    final seats = offer['numberOfBookableSeats']?.toString();

    return SearchResultItem(
      title: flightNumber == null ? carrier : '$carrier $flightNumber',
      subtitle: '$departure - $arrival | $departureTime - $arrivalTime',
      details: '$duration - $stops - ${seats == null ? 'Oferta Amadeus' : '$seats assentos'}',
      price: '$currency $total',
      badge: 'API Amadeus',
      icon: Icons.flight_takeoff,
      fromApi: true,
    );
  }

  static String? _firstString(Object? value) {
    if (value is List && value.isNotEmpty) {
      return value.first?.toString();
    }
    return null;
  }

  static String _locationCode(Object? value) {
    if (value is Map<String, dynamic>) {
      return value['iataCode']?.toString() ?? '---';
    }
    return '---';
  }

  static String _time(Object? value) {
    if (value is Map<String, dynamic>) {
      final at = value['at']?.toString();
      if (at != null && at.contains('T')) {
        return at.split('T').last.substring(0, 5);
      }
    }
    return '--:--';
  }

  static String _duration(String? value) {
    if (value == null || value.isEmpty) {
      return 'Duracao nao informada';
    }

    return value
        .replaceFirst('PT', '')
        .replaceAll('H', 'h ')
        .replaceAll('M', 'm')
        .trim();
  }
}

class SearchCatalog {
  static List<SearchResultItem> resultsFor(SearchRequest request) {
    switch (request.service) {
      case TravelService.flights:
        final origin = LocationResolver.codeFor(request.origin);
        final destination = LocationResolver.codeFor(request.destination, fallback: 'MIA');
        final route = '$origin - $destination';
        return [
          SearchResultItem(
            id: 'mock-${origin}-${destination}-latam',
            title: 'LATAM Airlines',
            subtitle: '$route | 08:00 - 14:30',
            details: '7h 30m - Direto - Bagagem inclusa',
            price: 'R\$ 1.200',
            badge: 'Mais vendido',
            icon: Icons.flight_takeoff,
          ),
          SearchResultItem(
            id: 'mock-${origin}-${destination}-gol',
            title: 'Gol Linhas Aereas',
            subtitle: '$route | 10:15 - 17:05',
            details: '8h 50m - 1 parada - Tarifa Light',
            price: 'R\$ 980',
            badge: 'Melhor preco',
            icon: Icons.flight,
          ),
          SearchResultItem(
            id: 'mock-${origin}-${destination}-azul',
            title: 'Azul',
            subtitle: '$route | 21:30 - 06:40',
            details: '9h 10m - Direto - Conforto extra',
            price: 'R\$ 1.390',
            badge: 'Conforto',
            icon: Icons.airlines,
          ),
        ];
      case TravelService.hotels:
        final destination = LocationResolver.labelFor(request.destination);
        return [
          SearchResultItem(title: 'Turistar Beach Resort', subtitle: '$destination - 4 estrelas', details: 'Cafe incluso - Piscina - 300m da praia', price: 'R\$ 620/noite', badge: 'Mais reservado', icon: Icons.hotel),
          SearchResultItem(title: 'Downtown Premium Hotel', subtitle: '$destination - Centro', details: 'Cancelamento gratis - Academia - Wi-Fi', price: 'R\$ 790/noite', badge: 'Melhor avaliacao', icon: Icons.apartment),
          SearchResultItem(title: 'Family Suites Airport', subtitle: '$destination - Proximo ao aeroporto', details: 'Suite familia - Transfer - Cafe incluso', price: 'R\$ 480/noite', badge: 'Ideal familia', icon: Icons.king_bed),
        ];
      case TravelService.cars:
        final pickup = LocationResolver.labelFor(request.origin);
        final dropoff = LocationResolver.labelFor(request.destination);
        return [
          SearchResultItem(title: 'Compacto Automatico', subtitle: 'Retirada em $pickup', details: 'Devolucao em $dropoff - Seguro basico', price: 'R\$ 180/dia', badge: 'Economico', icon: Icons.directions_car),
          SearchResultItem(title: 'SUV Confort', subtitle: 'Retirada e devolucao flexivel', details: '7 lugares - Cambio automatico - GPS', price: 'R\$ 320/dia', badge: 'Mais espaco', icon: Icons.car_rental),
          SearchResultItem(title: 'Eletrico Premium', subtitle: 'Pontos de recarga parceiros', details: 'Autonomia estendida - Seguro completo', price: 'R\$ 410/dia', badge: 'Sustentavel', icon: Icons.electric_car),
        ];
      case TravelService.packages:
        final destination = LocationResolver.labelFor(request.destination);
        return [
          SearchResultItem(title: '$destination Completo', subtitle: 'Voo + hotel + transfer', details: '7 noites - Hotel 4 estrelas - Suporte 24/7', price: 'R\$ 4.890', badge: 'Pacote completo', icon: Icons.luggage),
          SearchResultItem(title: '$destination Familia', subtitle: 'Voo + resort + carro', details: '10 noites - Ingressos opcionais - Seguro viagem', price: 'R\$ 6.450', badge: 'Ideal familia', icon: Icons.family_restroom),
          SearchResultItem(title: '$destination Essencial', subtitle: 'Multidestino opcional', details: '12 noites - Hoteis centrais - Transfers inclusos', price: 'R\$ 9.990', badge: 'Multidestino', icon: Icons.travel_explore),
        ];
    }
  }
}
