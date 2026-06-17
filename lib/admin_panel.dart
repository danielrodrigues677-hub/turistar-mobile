import 'package:flutter/material.dart';

import 'admin_requests_crm.dart';
import 'admin_store.dart';
import 'firestore_schema.dart';
import 'main.dart';
import 'travel_request_store.dart';

const _staffRoles = [TuristarRole.admin, TuristarRole.agent];

void openAdminPanel(BuildContext context) {
  requireAuth(
    context,
    () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
    ),
    roles: _staffRoles,
  );
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<AdminDashboardStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _statsFuture = AdminStore.fetchDashboardStats());
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Painel administrativo'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: LayoutShell(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: mobile ? 18 : 28),
          child: FutureBuilder<AdminDashboardStats>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: TuristarColors.orange));
              }
              if (snapshot.hasError) {
                return _AdminErrorState(message: authErrorMessage(snapshot.error!), onRetry: _reload);
              }

              final stats = snapshot.data!;
              return ListView(
                children: [
                  const BookingStepHeader(
                    step: 'Operacao Turistar',
                    title: 'Dashboard',
                    subtitle: 'Visao geral de clientes, solicitacoes, reservas e pacotes.',
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _StatCard(label: 'Total clientes', value: stats.totalClients, icon: Icons.people_outline),
                      _StatCard(label: 'Total solicitacoes', value: stats.totalRequests, icon: Icons.flight_takeoff),
                      _StatCard(label: 'Total reservas', value: stats.totalBookings, icon: Icons.confirmation_number_outlined),
                      _StatCard(label: 'Total pacotes', value: stats.totalPackages, icon: Icons.card_travel),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _AdminNavCard(
                    icon: Icons.people_outline,
                    title: 'Clientes',
                    subtitle: 'Listar, pesquisar e visualizar cadastros.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminClientsPage()),
                    ),
                  ),
                  _AdminNavCard(
                    icon: Icons.inbox_outlined,
                    title: 'Solicitacoes',
                    subtitle: 'Listar, filtrar e alterar status das viagens.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminRequestsCrmPage()),
                    ),
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

class AdminClientsPage extends StatefulWidget {
  const AdminClientsPage({super.key});

  @override
  State<AdminClientsPage> createState() => _AdminClientsPageState();
}

class _AdminClientsPageState extends State<AdminClientsPage> {
  final searchController = TextEditingController();
  late Future<List<AdminClient>> _clientsFuture;

  @override
  void initState() {
    super.initState();
    _clientsFuture = AdminStore.listClients();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = searchController.text;
    setState(() {
      _clientsFuture = AdminStore.searchClients(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Clientes'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Pesquisar por nome, e-mail ou telefone',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TuristarColors.line)),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<AdminClient>>(
                  future: _clientsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: TuristarColors.orange));
                    }
                    if (snapshot.hasError) {
                      return _AdminErrorState(message: authErrorMessage(snapshot.error!));
                    }

                    final clients = snapshot.data ?? [];
                    final customers = clients.where((client) => client.role == TuristarRole.customer).toList();

                    if (customers.isEmpty) {
                      return const _AdminEmptyState(
                        icon: Icons.people_outline,
                        title: 'Nenhum cliente encontrado',
                        subtitle: 'Cadastros de clientes aparecerao aqui.',
                      );
                    }

                    return ListView.separated(
                      itemCount: customers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final client = customers[index];
                        return _AdminClientCard(
                          client: client,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AdminClientDetailPage(clientId: client.id),
                            ),
                          ),
                        );
                      },
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

class AdminClientDetailPage extends StatefulWidget {
  const AdminClientDetailPage({super.key, required this.clientId});

  final String clientId;

  @override
  State<AdminClientDetailPage> createState() => _AdminClientDetailPageState();
}

class _AdminClientDetailPageState extends State<AdminClientDetailPage> {
  late Future<AdminClient?> _clientFuture;
  late Future<List<TravelRequest>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _clientFuture = AdminStore.getClient(widget.clientId);
    _requestsFuture = AdminStore.getClient(widget.clientId).then(
      (client) => client == null
          ? Future.value(<TravelRequest>[])
          : AdminStore.listTravelRequestsForClient(widget.clientId, email: client.email),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Detalhe do cliente'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: FutureBuilder<AdminClient?>(
            future: _clientFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: TuristarColors.orange));
              }
              if (snapshot.hasError) {
                return _AdminErrorState(message: authErrorMessage(snapshot.error!));
              }

              final client = snapshot.data;
              if (client == null) {
                return const _AdminEmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'Cliente nao encontrado',
                  subtitle: 'Verifique se o cadastro ainda existe.',
                );
              }

              return ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: TuristarColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client.name, style: const TextStyle(color: TuristarColors.navy, fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text(client.email, style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w700)),
                        if (client.phone.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(client.phone, style: const TextStyle(color: TuristarColors.muted)),
                          ),
                        const SizedBox(height: 8),
                        Text('Perfil: ${client.role}', style: const TextStyle(color: TuristarColors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Solicitacoes do cliente', style: TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 12),
                  FutureBuilder<List<TravelRequest>>(
                    future: _requestsFuture,
                    builder: (context, requestSnapshot) {
                      final requests = requestSnapshot.data ?? [];
                      if (requests.isEmpty) {
                        return const _AdminEmptyState(
                          icon: Icons.flight_takeoff,
                          title: 'Sem solicitacoes',
                          subtitle: 'Este cliente ainda nao solicitou viagens.',
                        );
                      }
                      return Column(
                        children: [
                          for (final request in requests)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AdminRequestCard(
                                request: request,
                                onTap: () => showAdminRequestDetailDialog(context, request),
                              ),
                            ),
                        ],
                      );
                    },
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final width = Responsive.isMobile(context) ? (MediaQuery.sizeOf(context).width - 64) / 2 : 220.0;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TuristarColors.line),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: TuristarColors.orange),
            const SizedBox(height: 12),
            Text('$value', style: const TextStyle(color: TuristarColors.navy, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: TuristarColors.muted, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _AdminNavCard extends StatelessWidget {
  const _AdminNavCard({
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
                Icon(icon, color: TuristarColors.orange),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 17)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: TuristarColors.muted)),
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

class _AdminClientCard extends StatelessWidget {
  const _AdminClientCard({required this.client, required this.onTap});

  final AdminClient client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TuristarColors.line),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: TuristarColors.orange.withOpacity(0.12),
                child: Text(
                  client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
                    Text(client.email, style: const TextStyle(color: TuristarColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: TuristarColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminRequestCard extends StatelessWidget {
  const _AdminRequestCard({required this.request, this.onTap, this.dense = true});

  final TravelRequest request;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: EdgeInsets.all(dense ? 16 : 20),
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
              Expanded(
                child: Text(request.routeLabel, style: TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: dense ? 16 : 20)),
              ),
              _StatusChipAdmin(status: request.status),
            ],
          ),
          const SizedBox(height: 8),
          Text('Cliente: ${request.userEmail}', style: const TextStyle(color: TuristarColors.muted)),
          Text('Ida: ${request.departureDate}${request.returnDate != null ? '  •  Volta: ${request.returnDate}' : ''}', style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w700)),
          Text('${request.passengers} passageiro(s)', style: const TextStyle(color: TuristarColors.muted)),
          if (request.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(request.notes, style: const TextStyle(color: TuristarColors.muted, height: 1.35)),
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: content),
    );
  }
}

class _StatusChipAdmin extends StatelessWidget {
  const _StatusChipAdmin({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TuristarColors.navy.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        TravelRequestStatus.label(status),
        style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({required this.icon, required this.title, required this.subtitle});

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

class _AdminErrorState extends StatelessWidget {
  const _AdminErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: TuristarColors.muted)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Tentar novamente')),
          ],
        ],
      ),
    );
  }
}
