import 'package:flutter/material.dart';

import 'admin_banners.dart';
import 'admin_featured_packages.dart';
import 'admin_packages.dart';
import 'admin_permissions.dart';
import 'admin_requests_crm.dart';
import 'admin_store.dart';
import 'firestore_schema.dart';
import 'main.dart';
import 'travel_request_store.dart';

const _staffRoles = TuristarRole.staff;

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
    setState(() {
      _statsFuture = AdminStore.fetchDashboardStats();
      return;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final role = TuristarAuth.currentRole;

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
                  BookingStepHeader(
                    step: 'Operacao Turistar',
                    title: 'Dashboard Comercial',
                    subtitle: 'Perfil: ${AdminPermissions.roleLabel(role ?? TuristarRole.customer)} — indicadores em tempo real.',
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _StatCard(label: 'Total clientes', value: stats.totalClients, icon: Icons.people_outline),
                      _StatCard(label: 'Total solicitacoes', value: stats.totalRequests, icon: Icons.flight_takeoff),
                      _StatCard(label: 'Pacotes ativos', value: stats.totalActivePackages, icon: Icons.card_travel),
                      _StatCard(label: 'Total reservas', value: stats.totalBookings, icon: Icons.confirmation_number_outlined),
                      _StatCard(label: 'Conversao de leads', value: stats.leadConversionRate.round(), icon: Icons.trending_up, suffix: '%'),
                      _StatCard(label: 'Taxa de fechamento', value: stats.closingRate.round(), icon: Icons.check_circle_outline, suffix: '%'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Solicitacoes por status', style: TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 12),
                  _StatusBarChart(data: stats.requestsByStatus),
                  const SizedBox(height: 24),
                  const Text('Ultimas solicitacoes', style: TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 10),
                  if (stats.recentRequests.isEmpty)
                    const Text('Nenhuma solicitacao recente.', style: TextStyle(color: TuristarColors.muted))
                  else
                    ...stats.recentRequests.map((request) => _RecentRequestRow(request: request)),
                  const SizedBox(height: 24),
                  const Text('Ultimos clientes cadastrados', style: TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 10),
                  if (stats.recentClients.isEmpty)
                    const Text('Nenhum cliente recente.', style: TextStyle(color: TuristarColors.muted))
                  else
                    ...stats.recentClients.map((client) => _RecentClientRow(client: client)),
                  const SizedBox(height: 24),
                  if (AdminPermissions.canAccessClients(role))
                    _AdminNavCard(
                      icon: Icons.people_outline,
                      title: 'Clientes',
                      subtitle: 'Listar, pesquisar, editar e visualizar historico.',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminClientsPage())),
                    ),
                  if (AdminPermissions.canAccessRequests(role))
                    _AdminNavCard(
                      icon: Icons.inbox_outlined,
                      title: 'Solicitacoes',
                      subtitle: 'CRM com kanban, tabela e filtros avancados.',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminRequestsCrmPage())),
                    ),
                  if (AdminPermissions.canAccessPackages(role))
                    _AdminNavCard(
                      icon: Icons.card_travel,
                      title: 'Pacotes',
                      subtitle: 'Gestao completa de pacotes com imagens por URL.',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPackagesPage())),
                    ),
                  if (AdminPermissions.canAccessFeaturedPackages(role))
                    _AdminNavCard(
                      icon: Icons.star_outline,
                      title: 'Pacotes Mais Vendidos',
                      subtitle: 'Ordem da Home, precos e textos promocionais.',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminFeaturedPackagesPage())),
                    ),
                  if (AdminPermissions.canAccessBanners(role))
                    _AdminNavCard(
                      icon: Icons.image_outlined,
                      title: 'Banners',
                      subtitle: 'Cadastro e reordenacao de banners por URL.',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminBannersPage())),
                    ),
                  if (AdminPermissions.canAccessBookings(role))
                    _AdminNavCard(
                      icon: Icons.confirmation_number_outlined,
                      title: 'Reservas',
                      subtitle: 'Acompanhamento operacional de reservas.',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminBookingsPage())),
                    ),
                  if (AdminPermissions.canManageRoles(role))
                    _AdminNavCard(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Permissoes',
                      subtitle: 'Perfis Admin, Consultor e Operacional.',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPermissionsPage())),
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

class _StatusBarChart extends StatelessWidget {
  const _StatusBarChart({required this.data});

  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    final maxValue = data.values.fold<int>(0, (max, value) => value > max ? value : max);
    if (maxValue == 0) {
      return const Text('Sem dados de solicitacoes.', style: TextStyle(color: TuristarColors.muted));
    }
    return Column(
      children: TravelRequestStatus.all.map((status) {
        final value = data[status] ?? 0;
        final widthFactor = value / maxValue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(width: 130, child: Text(TravelRequestStatus.label(status), style: const TextStyle(fontSize: 12, color: TuristarColors.text))),
              Expanded(
                child: Stack(
                  children: [
                    Container(height: 18, decoration: BoxDecoration(color: TuristarColors.line, borderRadius: BorderRadius.circular(6))),
                    FractionallySizedBox(
                      widthFactor: widthFactor,
                      child: Container(height: 18, decoration: BoxDecoration(color: TuristarColors.orange.withOpacity(0.85), borderRadius: BorderRadius.circular(6))),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('$value', style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w800, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RecentRequestRow extends StatelessWidget {
  const _RecentRequestRow({required this.request});

  final TravelRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: TuristarColors.line)),
      child: Row(
        children: [
          Expanded(child: Text('${request.clientName} — ${request.destination}', style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w700))),
          Text(TravelRequestStatus.label(request.status), style: const TextStyle(color: TuristarColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RecentClientRow extends StatelessWidget {
  const _RecentClientRow({required this.client});

  final AdminClient client;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: TuristarColors.line)),
      child: Row(
        children: [
          Expanded(child: Text(client.name, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w700))),
          Text(client.email, style: const TextStyle(color: TuristarColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class AdminBookingsPage extends StatelessWidget {
  const AdminBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: TuristarColors.navy, foregroundColor: Colors.white, title: const Text('Reservas')),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: FutureBuilder<AdminDashboardStats>(
            future: AdminStore.fetchDashboardStats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: TuristarColors.orange));
              }
              if (snapshot.hasError) {
                return Center(child: Text(authErrorMessage(snapshot.error!)));
              }
              final total = snapshot.data?.totalBookings ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BookingStepHeader(
                    step: 'Operacional',
                    title: 'Reservas',
                    subtitle: 'Acompanhamento de reservas confirmadas pela equipe.',
                  ),
                  const SizedBox(height: 18),
                  _StatCard(label: 'Reservas registradas', value: total, icon: Icons.confirmation_number_outlined),
                  const SizedBox(height: 18),
                  const Text('Modulo operacional conectado ao Firestore bookings.', style: TextStyle(color: TuristarColors.muted)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class AdminPermissionsPage extends StatefulWidget {
  const AdminPermissionsPage({super.key});

  @override
  State<AdminPermissionsPage> createState() => _AdminPermissionsPageState();
}

class _AdminPermissionsPageState extends State<AdminPermissionsPage> {
  late Future<List<AdminClient>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = AdminStore.listClients();
  }

  Future<void> _changeRole(AdminClient user, String role) async {
    try {
      await AdminStore.updateUserRole(userId: user.id, role: role);
      if (!mounted) return;
      setState(() => _usersFuture = AdminStore.listClients());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Perfil de ${user.name} atualizado.'), backgroundColor: TuristarColors.green),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(error)), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: TuristarColors.navy, foregroundColor: Colors.white, title: const Text('Permissoes')),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: FutureBuilder<List<AdminClient>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: TuristarColors.orange));
              }
              if (snapshot.hasError) {
                return Center(child: Text(authErrorMessage(snapshot.error!)));
              }
              final users = snapshot.data ?? [];
              return ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: TuristarColors.line)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
                              Text(user.email, style: const TextStyle(color: TuristarColors.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        DropdownButton<String>(
                          value: AdminPermissions.assignableRoles().contains(user.role) ? user.role : TuristarRole.customer,
                          items: AdminPermissions.assignableRoles()
                              .map((role) => DropdownMenuItem(value: role, child: Text(AdminPermissions.roleLabel(role))))
                              .toList(),
                          onChanged: (role) {
                            if (role == null) return;
                            _changeRole(user, role);
                          },
                        ),
                      ],
                    ),
                  );
                },
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
      return;
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
        actions: [
          if (AdminPermissions.canAccessClients(TuristarAuth.currentRole))
            IconButton(
              tooltip: 'Editar cliente',
              onPressed: () async {
                final client = await _clientFuture;
                if (client == null || !context.mounted) return;
                final nameController = TextEditingController(text: client.name);
                final phoneController = TextEditingController(text: client.phone);
                final saved = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Editar cliente'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome')),
                        TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Telefone')),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
                    ],
                  ),
                );
                if (saved != true) return;
                try {
                  await AdminStore.updateClientProfile(clientId: client.id, name: nameController.text.trim(), phone: phoneController.text.trim());
                  if (!context.mounted) return;
                  _reload();
                  setState(() {});
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(authErrorMessage(error)), backgroundColor: Colors.red.shade700),
                  );
                }
              },
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
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
                        Text('Perfil: ${AdminPermissions.roleLabel(client.role)}', style: const TextStyle(color: TuristarColors.muted)),
                        Text('Cadastro: ${client.createdAt.isEmpty ? '—' : client.createdAt}', style: const TextStyle(color: TuristarColors.muted, fontSize: 12)),
                        if (client.lastAccessAt.isNotEmpty)
                          Text('Ultimo acesso: ${client.lastAccessAt}', style: const TextStyle(color: TuristarColors.muted, fontSize: 12)),
                        Text('Viagens realizadas: ${client.tripsCount}', style: const TextStyle(color: TuristarColors.muted, fontSize: 12)),
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
  const _StatCard({required this.label, required this.value, required this.icon, this.suffix = ''});

  final String label;
  final int value;
  final IconData icon;
  final String suffix;

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
            Text('$value$suffix', style: const TextStyle(color: TuristarColors.navy, fontSize: 28, fontWeight: FontWeight.w900)),
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
