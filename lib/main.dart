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
    required this.title,
    required this.subtitle,
    required this.details,
    required this.price,
    required this.badge,
    required this.icon,
    this.fromApi = false,
  });

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
                const HeaderAction(icon: Icons.help_outline, label: 'Ajuda'),
                const SizedBox(width: 22),
                const HeaderAction(icon: Icons.person_outline, label: 'Entrar'),
              ] else
                const Spacer(),
              const SizedBox(width: 18),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  border: Border.all(color: TuristarColors.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.menu, size: 20, color: TuristarColors.navy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'TURIST',
              style: TextStyle(
                color: TuristarColors.navy,
                fontSize: mobile ? 22 : 27,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            Text(
              'AR',
              style: TextStyle(
                color: TuristarColors.orange,
                fontSize: mobile ? 22 : 27,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
          ],
        ),
        const Text(
          'Viagens Premium',
          style: TextStyle(
            color: TuristarColors.orangeDark,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
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
  const HeaderAction({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
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
              ),
              SearchTextField(
                controller: returnController,
                label: _returnLabel(widget.selectedService),
                hint: 'Data final',
                icon: Icons.calendar_month,
              ),
              SearchTextField(
                controller: travelersController,
                label: _travelersLabel(widget.selectedService),
                hint: 'Quantidade',
                icon: Icons.keyboard_arrow_down,
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
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
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
      height: 220,
      padding: const EdgeInsets.all(22),
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
          Text(data.description, textAlign: TextAlign.center, style: const TextStyle(color: TuristarColors.muted, fontSize: 12, height: 1.35)),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: TuristarColors.navy,
              side: const BorderSide(color: TuristarColors.navy),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
        const BrandLogo(),
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
                                  itemBuilder: (context, index) => SearchResultCard(item: state.items[index]),
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
    final usingApi = state.source == SearchResultSource.amadeus;
    final message = state.notice ??
        (usingApi
            ? '${state.items.length} ofertas reais retornadas pela Amadeus.'
            : '${state.items.length} ofertas demonstrativas. Configure o backend Amadeus para dados reais.');

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
  const SearchResultCard({super.key, required this.item});

  final SearchResultItem item;

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
                _ResultPrice(item: item),
              ],
            )
          : Row(
              children: [
                Expanded(child: _ResultInfo(item: item)),
                const SizedBox(width: 18),
                _ResultPrice(item: item),
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
  const _ResultPrice({required this.item});

  final SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: Responsive.isMobile(context) ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(item.price, style: const TextStyle(color: TuristarColors.orange, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: TuristarColors.navyDark),
          child: const Text('Selecionar'),
        ),
      ],
    );
  }
}

enum SearchResultSource { mock, amadeus }

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
        return const SearchResultState(
          items: [],
          source: SearchResultSource.amadeus,
          notice: 'A Amadeus nao retornou ofertas para esta busca.',
        );
      }

      return SearchResultState(
        items: apiItems,
        source: SearchResultSource.amadeus,
      );
    } catch (error) {
      return SearchResultState(
        items: SearchCatalog.resultsFor(request),
        source: SearchResultSource.mock,
        notice: 'API Amadeus indisponivel ou nao configurada. Exibindo dados demonstrativos.',
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
    final normalized = value.trim().toUpperCase();
    final match = RegExp(r'[A-Z]{3}').firstMatch(normalized);
    if (match != null) {
      return match.group(0)!;
    }
    if (normalized.isEmpty) {
      return 'GRU';
    }
    return normalized.substring(0, normalized.length.clamp(0, 3).toInt());
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
        return const [
          SearchResultItem(title: 'LATAM Airlines', subtitle: 'GRU - MIA | 08:00 - 14:30', details: '7h 30m - Direto - Bagagem inclusa', price: 'R\$ 1.200', badge: 'Mais vendido', icon: Icons.flight_takeoff),
          SearchResultItem(title: 'Gol Linhas Aereas', subtitle: 'GRU - MIA | 10:15 - 17:05', details: '8h 50m - 1 parada - Tarifa Light', price: 'R\$ 980', badge: 'Melhor preco', icon: Icons.flight),
          SearchResultItem(title: 'Azul', subtitle: 'VCP - MIA | 21:30 - 06:40', details: '9h 10m - Direto - Conforto extra', price: 'R\$ 1.390', badge: 'Conforto', icon: Icons.airlines),
        ];
      case TravelService.hotels:
        return const [
          SearchResultItem(title: 'Turistar Beach Resort', subtitle: 'Miami Beach - 4 estrelas', details: 'Cafe incluso - Piscina - 300m da praia', price: 'R\$ 620/noite', badge: 'Mais reservado', icon: Icons.hotel),
          SearchResultItem(title: 'Downtown Premium Hotel', subtitle: 'Centro de Miami - 5 estrelas', details: 'Cancelamento gratis - Academia - Wi-Fi', price: 'R\$ 790/noite', badge: 'Melhor avaliacao', icon: Icons.apartment),
          SearchResultItem(title: 'Family Suites Airport', subtitle: 'Proximo ao aeroporto', details: 'Suite familia - Transfer - Cafe incluso', price: 'R\$ 480/noite', badge: 'Ideal familia', icon: Icons.king_bed),
        ];
      case TravelService.cars:
        return const [
          SearchResultItem(title: 'Compacto Automatico', subtitle: 'Retirada no aeroporto de Miami', details: 'Ar-condicionado - 4 portas - Seguro basico', price: 'R\$ 180/dia', badge: 'Economico', icon: Icons.directions_car),
          SearchResultItem(title: 'SUV Confort', subtitle: 'Retirada e devolucao flexivel', details: '7 lugares - Cambio automatico - GPS', price: 'R\$ 320/dia', badge: 'Mais espaco', icon: Icons.car_rental),
          SearchResultItem(title: 'Eletrico Premium', subtitle: 'Pontos de recarga parceiros', details: 'Autonomia estendida - Seguro completo', price: 'R\$ 410/dia', badge: 'Sustentavel', icon: Icons.electric_car),
        ];
      case TravelService.packages:
        return const [
          SearchResultItem(title: 'Miami Completo', subtitle: 'Voo + hotel + transfer', details: '7 noites - Hotel 4 estrelas - Suporte 24/7', price: 'R\$ 4.890', badge: 'Pacote completo', icon: Icons.luggage),
          SearchResultItem(title: 'Orlando Familia', subtitle: 'Voo + resort + carro', details: '10 noites - Ingressos opcionais - Seguro viagem', price: 'R\$ 6.450', badge: 'Ideal familia', icon: Icons.family_restroom),
          SearchResultItem(title: 'Europa Essencial', subtitle: 'Lisboa + Madrid + Paris', details: '12 noites - Hoteis centrais - Trens inclusos', price: 'R\$ 9.990', badge: 'Multidestino', icon: Icons.travel_explore),
        ];
    }
  }
}
