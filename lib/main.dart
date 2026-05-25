import 'package:flutter/material.dart';

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
  static const blue = Color(0xFF0D4D9C);
  static const orange = Color(0xFFF6A313);
  static const orangeDark = Color(0xFFD48600);
  static const page = Color(0xFFF8FAFE);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF092A5E);
  static const muted = Color(0xFF62728B);
  static const line = Color(0xFFE2E8F3);
  static const green = Color(0xFF1DBE72);
}

class TuristarLandingPage extends StatelessWidget {
  const TuristarLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const TopNavigation(),
            HeroSection(onSearch: () => _openResults(context)),
            const ServicesSection(),
            const WhyChooseSection(),
            CallToActionSection(onSearch: () => _openResults(context)),
            const FooterSection(),
          ],
        ),
      ),
    );
  }

  void _openResults(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FlightResultsPage()),
    );
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
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }
}

class TopNavigation extends StatelessWidget {
  const TopNavigation({super.key});

  static const navItems = [
    'Passagens',
    'Hospedagens',
    'Aluguel de Carros',
    'Pacotes',
    'Servicos',
    'Empresa',
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 880;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: TuristarColors.orange, width: 2)),
      ),
      child: LayoutShell(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          height: 78,
          child: Row(
            children: [
              const BrandLogo(),
              if (!compact) ...[
                const SizedBox(width: 72),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final item in navItems) NavLink(label: item),
                    ],
                  ),
                ),
              ] else
                const Spacer(),
              if (!compact) const HeaderAction(icon: Icons.help_outline, label: 'Ajuda'),
              if (!compact) const SizedBox(width: 22),
              if (!compact) const HeaderAction(icon: Icons.person_outline, label: 'Entrar'),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Row(
          children: [
            Text(
              'TURIST',
              style: TextStyle(
                color: TuristarColors.navy,
                fontSize: 27,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            Text(
              'AR',
              style: TextStyle(
                color: TuristarColors.orange,
                fontSize: 27,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
          ],
        ),
        Text(
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
  const NavLink({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        label,
        style: const TextStyle(
          color: TuristarColors.navy,
          fontSize: 13,
          fontWeight: FontWeight.w700,
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
  const HeroSection({super.key, required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;

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
          Positioned(
            right: compact ? -80 : 34,
            top: compact ? 84 : 78,
            child: Transform.rotate(
              angle: -0.26,
              child: Icon(
                Icons.airplanemode_active,
                size: compact ? 230 : 360,
                color: Colors.white.withOpacity(0.82),
              ),
            ),
          ),
          LayoutShell(
            child: Padding(
              padding: EdgeInsets.only(top: compact ? 42 : 56, bottom: 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 46,
                              height: 1.08,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                            ),
                            children: [
                              TextSpan(text: 'Explore o '),
                              TextSpan(
                                text: 'Mundo',
                                style: TextStyle(color: TuristarColors.orange),
                              ),
                              TextSpan(text: ' com\n'),
                              TextSpan(
                                text: 'Confianca',
                                style: TextStyle(color: TuristarColors.orange),
                              ),
                              TextSpan(text: ' e Seguranca'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'As melhores opcoes de viagens para voce e sua familia.\nVoos, hoteis e servicos com a qualidade que voce merece.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: compact ? 16 : 18,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 34),
                  SearchHeroCard(onSearch: onSearch),
                  const SizedBox(height: 26),
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
  const SearchHeroCard({super.key, required this.onSearch});

  final VoidCallback onSearch;

  @override
  State<SearchHeroCard> createState() => _SearchHeroCardState();
}

class _SearchHeroCardState extends State<SearchHeroCard> {
  int tabIndex = 0;
  int tripType = 0;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 820;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SearchTab(
              label: 'Buscar Voos',
              selected: tabIndex == 0,
              onTap: () => setState(() => tabIndex = 0),
            ),
            SearchTab(
              label: 'Minhas Reservas',
              selected: tabIndex == 1,
              onTap: () => setState(() => tabIndex = 1),
            ),
          ],
        ),
        Container(
          padding: EdgeInsets.all(compact ? 18 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(10),
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Wrap(
                spacing: compact ? 12 : 92,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TripTypeTile(
                    icon: Icons.sync_alt,
                    title: 'Ida e Volta',
                    subtitle: 'Viagem de ida e volta',
                    selected: tripType == 0,
                    onTap: () => setState(() => tripType = 0),
                  ),
                  TripTypeTile(
                    icon: Icons.flight_takeoff,
                    title: 'So Ida',
                    subtitle: 'Somente ida',
                    selected: tripType == 1,
                    onTap: () => setState(() => tripType = 1),
                  ),
                  TripTypeTile(
                    icon: Icons.travel_explore,
                    title: 'Multidestino',
                    subtitle: 'Varios destinos',
                    selected: tripType == 2,
                    onTap: () => setState(() => tripType = 2),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (compact)
                Column(
                  children: const [
                    SearchField(label: 'De onde?', value: 'Cidade ou aeroporto de origem'),
                    SizedBox(height: 14),
                    SearchField(label: 'Para onde?', value: 'Cidade ou aeroporto de destino'),
                  ],
                )
              else
                const Row(
                  children: [
                    Expanded(child: SearchField(label: 'De onde?', value: 'Cidade ou aeroporto de origem')),
                    SwapButton(),
                    Expanded(child: SearchField(label: 'Para onde?', value: 'Cidade ou aeroporto de destino')),
                  ],
                ),
              const SizedBox(height: 18),
              if (compact)
                const Column(
                  children: [
                    SearchField(label: 'Ida', value: '20 de Junho, 2024', icon: Icons.calendar_today),
                    SizedBox(height: 14),
                    SearchField(label: 'Volta', value: '27 de Junho, 2024', icon: Icons.calendar_today),
                    SizedBox(height: 14),
                    SearchField(label: 'Passageiros', value: '1 Passageiro, Economica', icon: Icons.keyboard_arrow_down),
                  ],
                )
              else
                const Row(
                  children: [
                    Expanded(child: SearchField(label: 'Ida', value: '20 de Junho, 2024', icon: Icons.calendar_today)),
                    SizedBox(width: 18),
                    Expanded(child: SearchField(label: 'Volta', value: '27 de Junho, 2024', icon: Icons.calendar_today)),
                    SizedBox(width: 18),
                    Expanded(child: SearchField(label: 'Passageiros', value: '1 Passageiro, Economica', icon: Icons.keyboard_arrow_down)),
                  ],
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: widget.onSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TuristarColors.orange,
                    foregroundColor: TuristarColors.navyDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text(
                    'Buscar Voos',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SearchTab extends StatelessWidget {
  const SearchTab({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 190,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
          border: Border.all(color: Colors.white.withOpacity(0.65)),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
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
        constraints: const BoxConstraints(minWidth: 210),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? TuristarColors.orange.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TuristarColors.orange, size: 24),
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

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: TuristarColors.line, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 12)),
                const SizedBox(height: 5),
                Text(value, style: const TextStyle(color: TuristarColors.muted, fontSize: 13)),
              ],
            ),
          ),
          if (icon != null) Icon(icon, size: 18, color: TuristarColors.navy),
        ],
      ),
    );
  }
}

class SwapButton extends StatelessWidget {
  const SwapButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: TuristarColors.orange, width: 1.5),
      ),
      child: const Icon(Icons.swap_horiz, size: 18, color: TuristarColors.orange),
    );
  }
}

class HeroStats extends StatelessWidget {
  const HeroStats({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final stats = const [
      (Icons.travel_explore, '100+', 'Destinos', 'Ao redor do mundo'),
      (Icons.support_agent, '24/7', 'Suporte', 'Atendimento sempre'),
      (Icons.verified_user, 'Seguranca', 'Total', 'Seus dados protegidos'),
    ];

    return Wrap(
      spacing: compact ? 20 : 170,
      runSpacing: 18,
      children: [
        for (final stat in stats)
          Row(
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
      ],
    );
  }
}

class ServicesSection extends StatelessWidget {
  const ServicesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    final services = const [
      ServiceData(Icons.flight_takeoff, Color(0xFFEAF2FF), Color(0xFF4E8DFF), 'Passagens Aereas', 'Milhares de rotas com as melhores companhias', 'Buscar Voos'),
      ServiceData(Icons.apartment, Color(0xFFFFF2D8), Color(0xFFF6A313), 'Hospedagem', 'Hoteis, pousadas e resorts com as melhores ofertas', 'Buscar Hoteis'),
      ServiceData(Icons.directions_car, Color(0xFFE1F8EC), Color(0xFF1DBE72), 'Aluguel de Carros', 'Alugue seu carro com as melhores tarifas', 'Alugar Carro'),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: LayoutShell(
        child: Column(
          children: [
            const SectionHeading(title: 'Nossos Servicos', subtitle: 'Tudo que voce precisa para sua viagem em um so lugar'),
            const SizedBox(height: 28),
            if (compact)
              Column(
                children: [
                  for (final service in services) Padding(padding: const EdgeInsets.only(bottom: 16), child: ServiceCard(service: service)),
                ],
              )
            else
              Row(
                children: [
                  for (final service in services) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: ServiceCard(service: service))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class ServiceData {
  const ServiceData(this.icon, this.background, this.iconColor, this.title, this.description, this.action);

  final IconData icon;
  final Color background;
  final Color iconColor;
  final String title;
  final String description;
  final String action;
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service});

  final ServiceData service;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 205,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TuristarColors.line),
        boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(color: service.background, shape: BoxShape.circle),
            child: Icon(service.icon, color: service.iconColor, size: 32),
          ),
          const SizedBox(height: 16),
          Text(service.title, textAlign: TextAlign.center, style: const TextStyle(color: TuristarColors.navy, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(service.description, textAlign: TextAlign.center, style: const TextStyle(color: TuristarColors.muted, fontSize: 12, height: 1.35)),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: TuristarColors.navy,
              side: const BorderSide(color: TuristarColors.navy),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: Text(service.action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class WhyChooseSection extends StatelessWidget {
  const WhyChooseSection({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 860;
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
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      child: LayoutShell(
        child: Column(
          children: [
            const SectionHeading(title: 'Por Que Escolher Turistar?', subtitle: 'Somos lideres em inovacao e atendimento no mercado de viagens'),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: benefits.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: compact ? 1 : 2,
                mainAxisExtent: 62,
                crossAxisSpacing: 14,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) => BenefitTile(benefit: benefits[index]),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
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
                Text(benefit.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TuristarColors.muted, fontSize: 11)),
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
    final compact = MediaQuery.sizeOf(context).width < 760;

    return Container(
      color: TuristarColors.page,
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutShell(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [TuristarColors.navy, Color(0xFF2D3329), TuristarColors.orangeDark],
            ),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CtaCopy(),
                    const SizedBox(height: 18),
                    CtaButton(onSearch: onSearch),
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
    return Row(
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
          child: const Icon(Icons.flight_takeoff, color: TuristarColors.orange, size: 42),
        ),
        const SizedBox(width: 22),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pronto para Comecar?', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              Text('Encontre as melhores opcoes de viagem para seu proximo destino', style: TextStyle(color: Colors.white70, fontSize: 14)),
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
      width: 230,
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
        child: const Text('Buscar Voos Agora', style: TextStyle(fontWeight: FontWeight.w900)),
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
          style: const TextStyle(color: TuristarColors.navy, fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -0.4),
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
    final compact = MediaQuery.sizeOf(context).width < 820;

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
      spacing: 72,
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

class FlightResultsPage extends StatefulWidget {
  const FlightResultsPage({super.key});

  @override
  State<FlightResultsPage> createState() => _FlightResultsPageState();
}

class _FlightResultsPageState extends State<FlightResultsPage> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final selectedFlight = flightOptions[selected];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Voos encontrados'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GRU para MIA', style: TextStyle(color: TuristarColors.navy, fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('15 Jun - 2 passageiros - Classe economica', style: TextStyle(color: TuristarColors.muted)),
              const SizedBox(height: 22),
              Expanded(
                child: ListView.builder(
                  itemCount: flightOptions.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ResultFlightCard(
                        option: flightOptions[index],
                        selected: selected == index,
                        onTap: () => setState(() => selected = index),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: TuristarColors.line)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Selecionado: R\$ ${selectedFlight.price}', style: const TextStyle(color: TuristarColors.orange, fontSize: 22, fontWeight: FontWeight.w900)),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: TuristarColors.navyDark),
                      child: const Text('Continuar'),
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
}

class FlightOption {
  const FlightOption(this.airline, this.route, this.times, this.duration, this.price, this.tag);

  final String airline;
  final String route;
  final String times;
  final String duration;
  final int price;
  final String tag;
}

const flightOptions = [
  FlightOption('LATAM Airlines', 'GRU - MIA', '08:00 - 14:30', '7h 30m direto', 1200, 'Mais vendido'),
  FlightOption('Gol Linhas Aereas', 'GRU - MIA', '10:15 - 17:05', '8h 50m 1 parada', 980, 'Melhor preco'),
  FlightOption('Azul', 'VCP - MIA', '21:30 - 06:40', '9h 10m direto', 1390, 'Conforto'),
];

class ResultFlightCard extends StatelessWidget {
  const ResultFlightCard({super.key, required this.option, required this.selected, required this.onTap});

  final FlightOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? TuristarColors.orange : TuristarColors.line, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: TuristarColors.orange.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.flight_takeoff, color: TuristarColors.orange),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.airline, style: const TextStyle(color: TuristarColors.navy, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('${option.route} - ${option.times} - ${option.duration}', style: const TextStyle(color: TuristarColors.muted)),
                  const SizedBox(height: 4),
                  Text(option.tag, style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Text('R\$ ${option.price}', style: const TextStyle(color: TuristarColors.orange, fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
