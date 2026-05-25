import 'package:flutter/material.dart';

void main() {
  runApp(const TuristarApp());
}

class TuristarApp extends StatelessWidget {
  const TuristarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turistar Mobile',
      debugShowCheckedModeBanner: false,
      theme: TuristarTheme.light,
      home: const HomeScreen(),
    );
  }
}

class TuristarTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: TuristarColors.navy,
      primary: TuristarColors.navy,
      secondary: TuristarColors.orange,
      surface: Colors.white,
      background: TuristarColors.background,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: TuristarColors.background,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: TuristarColors.orange, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TuristarColors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class TuristarColors {
  static const navy = Color(0xFF06245C);
  static const navyLight = Color(0xFF123E85);
  static const orange = Color(0xFFFF8A00);
  static const orangeLight = Color(0xFFFFB347);
  static const background = Color(0xFFF6F8FC);
  static const text = Color(0xFF16213E);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE5EAF3);
  static const success = Color(0xFF16A34A);
}

class FlightOption {
  const FlightOption({
    required this.airline,
    required this.fromCity,
    required this.fromCode,
    required this.toCity,
    required this.toCode,
    required this.departure,
    required this.arrival,
    required this.duration,
    required this.price,
    required this.stops,
    required this.badge,
  });

  final String airline;
  final String fromCity;
  final String fromCode;
  final String toCity;
  final String toCode;
  final String departure;
  final String arrival;
  final String duration;
  final int price;
  final String stops;
  final String badge;
}

const flights = [
  FlightOption(
    airline: 'LATAM Airlines',
    fromCity: 'Sao Paulo',
    fromCode: 'GRU',
    toCity: 'Miami',
    toCode: 'MIA',
    departure: '08:00',
    arrival: '14:30',
    duration: '7h 30m',
    price: 1200,
    stops: 'Direto',
    badge: 'Mais vendido',
  ),
  FlightOption(
    airline: 'Gol Linhas Aereas',
    fromCity: 'Sao Paulo',
    fromCode: 'GRU',
    toCity: 'Orlando',
    toCode: 'MCO',
    departure: '10:15',
    arrival: '18:40',
    duration: '9h 25m',
    price: 980,
    stops: '1 parada',
    badge: 'Melhor preco',
  ),
  FlightOption(
    airline: 'Azul',
    fromCity: 'Campinas',
    fromCode: 'VCP',
    toCity: 'Lisboa',
    toCode: 'LIS',
    departure: '21:30',
    arrival: '10:15',
    duration: '9h 45m',
    price: 1890,
    stops: 'Direto',
    badge: 'Internacional',
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedService = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _HeroHeader(),
            Transform.translate(
              offset: const Offset(0, -34),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SearchPanel(
                  selectedService: selectedService,
                  onServiceChanged: (index) {
                    setState(() => selectedService = index);
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                    title: 'Ofertas em destaque',
                    subtitle: 'Rotas selecionadas para sua proxima viagem',
                  ),
                  const SizedBox(height: 14),
                  ...flights.take(2).map(
                        (flight) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: FlightCard(
                            flight: flight,
                            onTap: () => _openResults(context),
                          ),
                        ),
                      ),
                  const SizedBox(height: 12),
                  const _SectionTitle(
                    title: 'Por que escolher a Turistar?',
                    subtitle: 'Atendimento humano, compra simples e suporte 24h',
                  ),
                  const SizedBox(height: 14),
                  const _BenefitsGrid(),
                  const SizedBox(height: 28),
                  _TravelAssistantCard(onTap: () => _openResults(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openResults(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ResultsScreen()),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 58, 20, 72),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TuristarColors.navy,
            TuristarColors.navyLight,
            TuristarColors.orange,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _LogoMark(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.notifications_none, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 34),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              'Agencia de viagens digital',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Explore o mundo\ncom seguranca.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Voos, hoteis, carros e pacotes em uma experiencia simples para mobile.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.86),
              fontSize: 16,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              _HeroMetric(value: '500K+', label: 'viajantes'),
              SizedBox(width: 22),
              _HeroMetric(value: '150+', label: 'destinos'),
              SizedBox(width: 22),
              _HeroMetric(value: '24h', label: 'suporte'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.flight_takeoff, color: TuristarColors.orange),
        ),
        const SizedBox(width: 12),
        const Text(
          'Turistar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.selectedService,
    required this.onServiceChanged,
  });

  final int selectedService;
  final ValueChanged<int> onServiceChanged;

  static const services = [
    (Icons.flight_takeoff, 'Voos'),
    (Icons.hotel, 'Hoteis'),
    (Icons.directions_car, 'Carros'),
    (Icons.luggage, 'Pacotes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F06245C),
              blurRadius: 26,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final service = services[index];
                  final selected = selectedService == index;
                  return ChoiceChip(
                    selected: selected,
                    avatar: Icon(
                      service.$1,
                      size: 18,
                      color: selected ? Colors.white : TuristarColors.navy,
                    ),
                    label: Text(service.$2),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : TuristarColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                    selectedColor: TuristarColors.orange,
                    backgroundColor: TuristarColors.background,
                    side: BorderSide.none,
                    onSelected: (_) => onServiceChanged(index),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemCount: services.length,
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Expanded(child: _InputTile(label: 'Origem', value: 'GRU')),
                SizedBox(width: 12),
                Expanded(child: _InputTile(label: 'Destino', value: 'MIA')),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(child: _InputTile(label: 'Ida', value: '15 Jun')),
                SizedBox(width: 12),
                Expanded(child: _InputTile(label: 'Viajantes', value: '2 adultos')),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ResultsScreen()),
                  );
                },
                icon: const Icon(Icons.search),
                label: const Text('Buscar melhores ofertas'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputTile extends StatelessWidget {
  const _InputTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      style: const TextStyle(fontWeight: FontWeight.w800),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: TuristarColors.text,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: TuristarColors.muted)),
      ],
    );
  }
}

class FlightCard extends StatelessWidget {
  const FlightCard({
    super.key,
    required this.flight,
    this.selected = false,
    required this.onTap,
  });

  final FlightOption flight;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? TuristarColors.orange : TuristarColors.line,
            width: selected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F06245C),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: TuristarColors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.flight,
                        color: TuristarColors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flight.airline,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: TuristarColors.text,
                          ),
                        ),
                        Text(
                          flight.badge,
                          style: const TextStyle(color: TuristarColors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  'R\$ ${flight.price}',
                  style: const TextStyle(
                    color: TuristarColors.orange,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _AirportBlock(
                  code: flight.fromCode,
                  city: flight.fromCity,
                  time: flight.departure,
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.flight_takeoff,
                        color: TuristarColors.navy,
                        size: 18,
                      ),
                      Container(height: 1, color: TuristarColors.line),
                      const SizedBox(height: 4),
                      Text(
                        '${flight.duration} - ${flight.stops}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: TuristarColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _AirportBlock(
                  code: flight.toCode,
                  city: flight.toCity,
                  time: flight.arrival,
                  alignEnd: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AirportBlock extends StatelessWidget {
  const _AirportBlock({
    required this.code,
    required this.city,
    required this.time,
    this.alignEnd = false,
  });

  final String code;
  final String city;
  final String time;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            code,
            style: const TextStyle(
              color: TuristarColors.navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(city, style: const TextStyle(color: TuristarColors.muted)),
          Text(
            time,
            style: const TextStyle(
              color: TuristarColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitsGrid extends StatelessWidget {
  const _BenefitsGrid();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.verified_user, 'Compra segura', 'Dados protegidos'),
      (Icons.price_check, 'Melhor preco', 'Ofertas curadas'),
      (Icons.support_agent, 'Suporte 24h', 'Ajuda em tempo real'),
      (Icons.flash_on, 'Reserva rapida', 'Fluxo simplificado'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: TuristarColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.$1, color: TuristarColors.orange, size: 28),
              const SizedBox(height: 12),
              Text(
                item.$2,
                style: const TextStyle(
                  color: TuristarColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(item.$3, style: const TextStyle(color: TuristarColors.muted)),
            ],
          ),
        );
      },
    );
  }
}

class _TravelAssistantCard extends StatelessWidget {
  const _TravelAssistantCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [TuristarColors.orange, TuristarColors.navy],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
          const SizedBox(height: 14),
          const Text(
            'Planeje sua viagem com a Turistar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Compare opcoes, escolha o voo ideal e finalize sua reserva em poucos passos.',
            style: TextStyle(color: Colors.white.withOpacity(0.84), height: 1.45),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Ver ofertas agora'),
          ),
        ],
      ),
    );
  }
}

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  int selectedFlight = 0;

  @override
  Widget build(BuildContext context) {
    final flight = flights[selectedFlight];

    return Scaffold(
      appBar: AppBar(title: const Text('Voos encontrados')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: TuristarColors.line)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GRU para MIA',
                  style: TextStyle(
                    color: TuristarColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '15 Jun - 2 passageiros - Classe economica',
                  style: TextStyle(color: TuristarColors.muted),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: flights.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: FlightCard(
                    flight: flights[index],
                    selected: selectedFlight == index,
                    onTap: () => setState(() => selectedFlight = index),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: TuristarColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Selecionado',
                          style: TextStyle(color: TuristarColors.muted),
                        ),
                        Text(
                          'R\$ ${flight.price}',
                          style: const TextStyle(
                            color: TuristarColors.orange,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CheckoutScreen(flight: flight),
                        ),
                      );
                    },
                    child: const Text('Continuar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.flight});

  final FlightOption flight;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  bool agreeTerms = false;
  String paymentMethod = 'PIX';

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar reserva')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _CheckoutProgress(),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Resumo do voo',
              child: Column(
                children: [
                  _SummaryRow('Companhia', widget.flight.airline),
                  _SummaryRow(
                    'Rota',
                    '${widget.flight.fromCode} - ${widget.flight.toCode}',
                  ),
                  _SummaryRow(
                    'Horario',
                    '${widget.flight.departure} - ${widget.flight.arrival}',
                  ),
                  _SummaryRow('Duracao', widget.flight.duration),
                  const Divider(),
                  _SummaryRow('Total', 'R\$ ${widget.flight.price}', highlight: true),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Dados do passageiro',
              child: Column(
                children: [
                  _CheckoutField(
                    controller: nameController,
                    label: 'Nome completo',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _CheckoutField(
                    controller: emailController,
                    label: 'E-mail',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _CheckoutField(
                    controller: phoneController,
                    label: 'Telefone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Pagamento',
              child: Column(
                children: [
                  _PaymentOption(
                    value: 'PIX',
                    groupValue: paymentMethod,
                    icon: Icons.qr_code_2,
                    label: 'PIX',
                    onChanged: _selectPayment,
                  ),
                  const SizedBox(height: 10),
                  _PaymentOption(
                    value: 'Cartao',
                    groupValue: paymentMethod,
                    icon: Icons.credit_card,
                    label: 'Cartao de credito',
                    onChanged: _selectPayment,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: agreeTerms,
              onChanged: (value) => setState(() => agreeTerms = value ?? false),
              activeColor: TuristarColors.orange,
              contentPadding: EdgeInsets.zero,
              title: const Text('Concordo com os termos da reserva'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: agreeTerms ? _confirmBooking : null,
              child: const Text('Confirmar compra'),
            ),
          ],
        ),
      ),
    );
  }

  void _selectPayment(String value) {
    setState(() => paymentMethod = value);
  }

  void _confirmBooking() {
    if (formKey.currentState?.validate() != true) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ConfirmationScreen(
          flight: widget.flight,
          passengerName: nameController.text,
        ),
      ),
    );
  }
}

class _CheckoutProgress extends StatelessWidget {
  const _CheckoutProgress();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _ProgressStep(label: 'Voo', active: true),
        _ProgressLine(),
        _ProgressStep(label: 'Dados', active: true),
        _ProgressLine(),
        _ProgressStep(label: 'Pagamento', active: true),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: active ? TuristarColors.orange : TuristarColors.line,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: TuristarColors.muted)),
      ],
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24),
        color: TuristarColors.orange,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: TuristarColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: TuristarColors.muted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: highlight ? TuristarColors.orange : TuristarColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutField extends StatelessWidget {
  const _CheckoutField({
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
        if (value == null || value.trim().isEmpty) {
          return 'Informe $label';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: TuristarColors.orange),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.value,
    required this.groupValue,
    required this.icon,
    required this.label,
    required this.onChanged,
  });

  final String value;
  final String groupValue;
  final IconData icon;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? TuristarColors.orange.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? TuristarColors.orange : TuristarColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: TuristarColors.navy),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: TuristarColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? TuristarColors.orange : TuristarColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({
    super.key,
    required this.flight,
    required this.passengerName,
  });

  final FlightOption flight;
  final String passengerName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 92,
                height: 92,
                decoration: const BoxDecoration(
                  color: TuristarColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 54),
              ),
              const SizedBox(height: 24),
              const Text(
                'Reserva confirmada!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TuristarColors.text,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Obrigado, ${passengerName.trim()}. Enviamos os detalhes da viagem para o seu e-mail.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: TuristarColors.muted, height: 1.45),
              ),
              const SizedBox(height: 24),
              _SectionCard(
                title: 'Codigo TST-2048',
                child: Column(
                  children: [
                    _SummaryRow('Companhia', flight.airline),
                    _SummaryRow('Rota', '${flight.fromCode} - ${flight.toCode}'),
                    _SummaryRow('Horario', '${flight.departure} - ${flight.arrival}'),
                    _SummaryRow('Total', 'R\$ ${flight.price}', highlight: true),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Voltar para o inicio'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
