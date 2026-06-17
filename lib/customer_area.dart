import 'package:flutter/material.dart';

import 'main.dart';
import 'travel_request_store.dart';

void openCustomerAreaHub(BuildContext context) {
  requireAuth(
    context,
    () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomerAreaHubPage()),
    ),
  );
}

void openCustomerProfilePage(BuildContext context) {
  requireAuth(
    context,
    () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomerProfilePage()),
    ),
  );
}

void openMyTripsPage(BuildContext context) {
  requireAuth(
    context,
    () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyTripsPage()),
    ),
  );
}

void openMyQuotesPage(BuildContext context) {
  requireAuth(
    context,
    () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyQuotesPage()),
    ),
  );
}

void openNewTravelRequestPage(BuildContext context) {
  requireAuth(
    context,
    () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewTravelRequestPage()),
    ),
  );
}

class CustomerAreaHubPage extends StatelessWidget {
  const CustomerAreaHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = TuristarAuth.session;
    final mobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Area do cliente'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: mobile ? 18 : 28),
          child: ListView(
            children: [
              BookingStepHeader(
                step: 'Area do cliente',
                title: 'Ola, ${TuristarAuth.greeting(session)}',
                subtitle: session?.email == null
                    ? 'Gerencie suas viagens, orcamentos e reservas.'
                    : 'Conta ${session!.email}',
              ),
              const SizedBox(height: 20),
              _HubActionCard(
                icon: Icons.edit_outlined,
                title: 'Meu perfil',
                subtitle: 'Visualize e edite seus dados pessoais.',
                onTap: () => openCustomerProfilePage(context),
              ),
              _HubActionCard(
                icon: Icons.flight_takeoff,
                title: 'Minhas Viagens',
                subtitle: 'Historico de solicitacoes de orcamento.',
                onTap: () => openMyTripsPage(context),
              ),
              _HubActionCard(
                icon: Icons.request_quote_outlined,
                title: 'Meus Orcamentos',
                subtitle: 'Acompanhe propostas enviadas pela equipe.',
                onTap: () => openMyQuotesPage(context),
              ),
              _HubActionCard(
                icon: Icons.confirmation_number_outlined,
                title: 'Minhas Reservas',
                subtitle: 'Localizadores e status de reservas confirmadas.',
                onTap: () => openReservationsPage(context),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => openNewTravelRequestPage(context),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Solicitar orcamento'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TuristarColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubActionCard extends StatelessWidget {
  const _HubActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TuristarColors.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: TuristarColors.orange.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: TuristarColors.orange),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 17)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: TuristarColors.muted, height: 1.35)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: TuristarColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final session = TuristarAuth.session;
    nameController = TextEditingController(text: session?.name ?? '');
    phoneController = TextEditingController(text: session?.phone ?? '');
    emailController = TextEditingController(text: session?.email ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (formKey.currentState?.validate() != true || isSaving) return;

    setState(() => isSaving = true);
    try {
      await TuristarAuth.updateProfile(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso.'), backgroundColor: TuristarColors.navy),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(error)), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Meu perfil'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: ListView(
            children: [
              const BookingStepHeader(
                step: 'Area do cliente',
                title: 'Dados pessoais',
                subtitle: 'Mantenha seu cadastro atualizado para receber orcamentos e confirmacoes.',
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
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Nome completo', prefixIcon: Icon(Icons.person_outline)),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Campo obrigatorio' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: emailController,
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline)),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: 'Telefone / WhatsApp', prefixIcon: Icon(Icons.phone_outlined)),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Campo obrigatorio' : null,
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TuristarColors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSaving
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Salvar alteracoes'),
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
}

class MyTripsPage extends StatefulWidget {
  const MyTripsPage({super.key});

  @override
  State<MyTripsPage> createState() => _MyTripsPageState();
}

class _MyTripsPageState extends State<MyTripsPage> {
  late Future<List<TravelRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = CustomerAreaStore.listTravelRequests();
  }

  Future<void> _reload() async {
    setState(() {
      _future = CustomerAreaStore.listTravelRequests();
      return;
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Minhas Viagens'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openNewTravelRequestPage(context),
        backgroundColor: TuristarColors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova solicitacao'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: FutureBuilder<List<TravelRequest>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: TuristarColors.orange));
              }

              final requests = snapshot.data ?? [];
              return ListView(
                children: [
                  BookingStepHeader(
                    step: 'Area do cliente',
                    title: 'Historico de solicitacoes',
                    subtitle: TuristarAuth.session?.email == null
                        ? 'Suas solicitacoes de orcamento aparecem aqui.'
                        : 'Solicitacoes de ${TuristarAuth.session!.email}.',
                  ),
                  const SizedBox(height: 18),
                  if (requests.isEmpty)
                    const _EmptyCustomerPanel(
                      icon: Icons.flight_takeoff,
                      title: 'Nenhuma solicitacao encontrada',
                      subtitle: 'Solicite um orcamento e acompanhe o status por aqui.',
                    )
                  else
                    for (final request in requests)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _TravelRequestCard(request: request),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class MyQuotesPage extends StatefulWidget {
  const MyQuotesPage({super.key});

  @override
  State<MyQuotesPage> createState() => _MyQuotesPageState();
}

class _MyQuotesPageState extends State<MyQuotesPage> {
  late Future<List<CustomerQuote>> _future;

  @override
  void initState() {
    super.initState();
    _future = CustomerAreaStore.listQuotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Meus Orcamentos'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: FutureBuilder<List<CustomerQuote>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: TuristarColors.orange));
              }

              final quotes = snapshot.data ?? [];
              return ListView(
                children: [
                  const BookingStepHeader(
                    step: 'Area do cliente',
                    title: 'Meus orcamentos',
                    subtitle: 'Propostas preparadas pela equipe Turistar apos sua solicitacao.',
                  ),
                  const SizedBox(height: 18),
                  if (quotes.isEmpty)
                    const _EmptyCustomerPanel(
                      icon: Icons.request_quote_outlined,
                      title: 'Nenhum orcamento disponivel',
                      subtitle: 'Quando sua solicitacao for analisada, o orcamento aparecera aqui.',
                    )
                  else
                    for (final quote in quotes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CustomerQuoteCard(quote: quote),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class NewTravelRequestPage extends StatefulWidget {
  const NewTravelRequestPage({super.key});

  @override
  State<NewTravelRequestPage> createState() => _NewTravelRequestPageState();
}

class _NewTravelRequestPageState extends State<NewTravelRequestPage> {
  final formKey = GlobalKey<FormState>();
  final originController = TextEditingController();
  final destinationController = TextEditingController();
  final notesController = TextEditingController();
  DateTime? departureDate;
  DateTime? returnDate;
  int passengers = 1;
  bool isSubmitting = false;

  @override
  void dispose() {
    originController.dispose();
    destinationController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isReturn}) async {
    final initial = isReturn ? (returnDate ?? departureDate ?? DateTime.now()) : (departureDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isReturn) {
        returnDate = picked;
      } else {
        departureDate = picked;
        if (returnDate != null && returnDate!.isBefore(picked)) {
          returnDate = null;
        }
      }
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Selecionar';
    return _formatDateValue(date);
  }

  String _isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _formatDateValue(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _submit() async {
    if (formKey.currentState?.validate() != true || isSubmitting) return;
    if (departureDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a data de ida.'), backgroundColor: TuristarColors.navy),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      await CustomerAreaStore.createTravelRequest(
        origin: originController.text.trim(),
        destination: destinationController.text.trim(),
        departureDate: _isoDate(departureDate!),
        returnDate: returnDate == null ? null : _isoDate(returnDate!),
        passengers: passengers,
        notes: notesController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitacao enviada! Acompanhe o status em Minhas Viagens.'),
          backgroundColor: TuristarColors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(error)), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Solicitar orcamento'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: mobile ? 18 : 28),
          child: ListView(
            children: [
              const BookingStepHeader(
                step: 'Area do cliente',
                title: 'Conte-nos sobre sua viagem',
                subtitle: 'Nossa equipe prepara um orcamento personalizado com base nos dados abaixo.',
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
                    children: [
                      ResponsiveFields(
                        children: [
                          TextFormField(
                            controller: originController,
                            decoration: const InputDecoration(labelText: 'Origem', prefixIcon: Icon(Icons.flight_takeoff)),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatorio' : null,
                          ),
                          TextFormField(
                            controller: destinationController,
                            decoration: const InputDecoration(labelText: 'Destino', prefixIcon: Icon(Icons.flight_land)),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatorio' : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ResponsiveFields(
                        children: [
                          _DatePickerField(label: 'Ida', value: _formatDate(departureDate), onTap: () => _pickDate(isReturn: false)),
                          _DatePickerField(label: 'Volta (opcional)', value: _formatDate(returnDate), onTap: () => _pickDate(isReturn: true)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text('Passageiros', style: TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          IconButton(
                            onPressed: passengers > 1 ? () => setState(() => passengers--) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            color: TuristarColors.navy,
                          ),
                          Text('$passengers', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: TuristarColors.navy)),
                          IconButton(
                            onPressed: passengers < 9 ? () => setState(() => passengers++) : null,
                            icon: const Icon(Icons.add_circle_outline),
                            color: TuristarColors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: notesController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Observacoes',
                          alignLabelWithHint: true,
                          hintText: 'Classe desejada, flexibilidade de datas, hotel, etc.',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TuristarColors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Enviar solicitacao'),
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
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_month_outlined)),
        child: Text(value, style: TextStyle(color: value == 'Selecionar' ? TuristarColors.muted : TuristarColors.navy, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _TravelRequestCard extends StatelessWidget {
  const _TravelRequestCard({required this.request});

  final TravelRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TuristarColors.line),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 14, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(request.routeLabel, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
              _StatusChip(label: TravelRequestStatus.label(request.status)),
            ],
          ),
          const SizedBox(height: 10),
          Text('Ida: ${_displayDate(request.departureDate)}${request.returnDate != null ? '  •  Volta: ${_displayDate(request.returnDate!)}' : ''}',
              style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${request.passengers} passageiro(s)', style: const TextStyle(color: TuristarColors.muted)),
          if (request.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(request.notes, style: const TextStyle(color: TuristarColors.muted, height: 1.35)),
          ],
        ],
      ),
    );
  }

  String _displayDate(String iso) {
    try {
      return _NewTravelRequestPageState._formatDateValue(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}

class _CustomerQuoteCard extends StatelessWidget {
  const _CustomerQuoteCard({required this.quote});

  final CustomerQuote quote;

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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: TuristarColors.orange.withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.request_quote_outlined, color: TuristarColors.orange),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quote.route, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(CustomerQuoteStatus.label(quote.status), style: const TextStyle(color: TuristarColors.muted)),
              ],
            ),
          ),
          if (quote.totalPrice != null && quote.totalPrice!.isNotEmpty)
            Text('R\$ ${quote.totalPrice}', style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _EmptyCustomerPanel extends StatelessWidget {
  const _EmptyCustomerPanel({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: TuristarColors.muted, size: 42),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: TuristarColors.navy, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: TuristarColors.muted, height: 1.4)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TuristarColors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}
