import 'package:flutter/material.dart';

import 'admin_store.dart';
import 'main.dart';
import 'travel_request_store.dart';

enum _RequestsViewMode { table, kanban }

void showAdminRequestDetailDialog(BuildContext context, TravelRequest request) {
  showDialog<void>(
    context: context,
    builder: (context) => _RequestDetailDialog(request: request),
  );
}

class AdminRequestsCrmPage extends StatefulWidget {
  const AdminRequestsCrmPage({super.key});

  @override
  State<AdminRequestsCrmPage> createState() => _AdminRequestsCrmPageState();
}

class _AdminRequestsCrmPageState extends State<AdminRequestsCrmPage> {
  final searchController = TextEditingController();
  String? statusFilter;
  String? destinationFilter;
  String? consultantFilter;
  DateTime? startDate;
  DateTime? endDate;
  List<String> consultants = [];
  _RequestsViewMode viewMode = _RequestsViewMode.table;
  late Stream<List<TravelRequest>> _requestsStream;
  String? actionError;

  @override
  void initState() {
    super.initState();
    _requestsStream = AdminStore.watchTravelRequests();
    searchController.addListener(() => setState(() {}));
    AdminStore.listConsultantEmails().then((values) {
      if (mounted) setState(() => consultants = values);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<TravelRequest> _filter(List<TravelRequest> requests) {
    return AdminStore.filterTravelRequests(
      requests: requests,
      query: searchController.text,
      statusFilter: statusFilter,
      destinationFilter: destinationFilter,
      consultantFilter: consultantFilter,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> _changeStatus(TravelRequest request, String status) async {
    setState(() => actionError = null);
    try {
      await AdminStore.updateTravelRequestStatus(requestId: request.id, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status atualizado para ${TravelRequestStatus.label(status)}.'),
          backgroundColor: TuristarColors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => actionError = authErrorMessage(error));
    }
  }

  Future<void> _deleteRequest(TravelRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir solicitacao'),
        content: Text('Deseja excluir a solicitacao de ${request.clientName} para ${request.destination}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await AdminStore.deleteTravelRequest(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitacao excluida.'), backgroundColor: TuristarColors.navy),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(error)), backgroundColor: Colors.red.shade700),
      );
    }
  }

  void _openWhatsApp(TravelRequest request) {
    final message = [
      'Ola ${request.clientName}.',
      'Sou da Turistar Viagens.',
      '',
      'Recebemos sua solicitacao para ${request.destination} e estamos preparando seu atendimento.',
    ].join('\n');
    Whatsapp.openToNumber(context, request.phone, message);
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Solicitacoes'),
        actions: [
          IconButton(
            tooltip: 'Criar solicitacao',
            onPressed: () => _showCreateRequestDialog(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: LayoutShell(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: mobile ? 18 : 28),
          child: StreamBuilder<List<TravelRequest>>(
            stream: _requestsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: TuristarColors.orange));
              }
              if (snapshot.hasError) {
                return _CrmErrorState(message: authErrorMessage(snapshot.error!), onRetry: () {
                  setState(() => _requestsStream = AdminStore.watchTravelRequests());
                });
              }

              final allRequests = snapshot.data ?? [];
              final filtered = _filter(allRequests);
              final stats = AdminStore.requestStatsFrom(allRequests);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BookingStepHeader(
                    step: 'CRM Turistar',
                    title: 'Gestao comercial de viagens',
                    subtitle: 'Acompanhe leads, status e atendimento em tempo real.',
                  ),
                  const SizedBox(height: 18),
                  _RequestStatsRow(stats: stats, mobile: mobile),
                  const SizedBox(height: 18),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Pesquisar por nome, e-mail, telefone ou destino',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: TuristarColors.line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _CrmFilterChip(
                          label: 'Todos',
                          selected: statusFilter == null,
                          onSelected: () => setState(() => statusFilter = null),
                        ),
                        for (final status in TravelRequestStatus.all)
                          _CrmFilterChip(
                            label: TravelRequestStatus.label(status),
                            selected: statusFilter == status,
                            onSelected: () => setState(() => statusFilter = status),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 220,
                        child: TextField(
                          decoration: const InputDecoration(labelText: 'Destino', isDense: true),
                          onChanged: (value) => setState(() => destinationFilter = value.trim().isEmpty ? null : value.trim()),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Consultor', isDense: true),
                          value: consultantFilter,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Todos')),
                            ...consultants.map((email) => DropdownMenuItem(value: email, child: Text(email))),
                          ],
                          onChanged: (value) => setState(() => consultantFilter = value),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (range == null) return;
                          setState(() {
                            startDate = range.start;
                            endDate = range.end.add(const Duration(hours: 23, minutes: 59));
                          });
                        },
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(startDate == null ? 'Periodo' : '${startDate!.day}/${startDate!.month} - ${endDate!.day}/${endDate!.month}'),
                      ),
                      if (startDate != null)
                        TextButton(
                          onPressed: () => setState(() {
                            startDate = null;
                            endDate = null;
                          }),
                          child: const Text('Limpar periodo'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SegmentedButton<_RequestsViewMode>(
                        segments: const [
                          ButtonSegment(value: _RequestsViewMode.table, label: Text('Tabela'), icon: Icon(Icons.table_rows_outlined)),
                          ButtonSegment(value: _RequestsViewMode.kanban, label: Text('Kanban'), icon: Icon(Icons.view_kanban_outlined)),
                        ],
                        selected: {viewMode},
                        onSelectionChanged: (value) => setState(() => viewMode = value.first),
                        style: ButtonStyle(
                          foregroundColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) return TuristarColors.navy;
                            return TuristarColors.muted;
                          }),
                        ),
                      ),
                      const Spacer(),
                      Text('${filtered.length} resultado(s)', style: const TextStyle(color: TuristarColors.muted, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  if (actionError != null) ...[
                    const SizedBox(height: 8),
                    Text(actionError!, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? _RequestsEmptyState(onCreate: () => _showCreateRequestDialog(context))
                        : viewMode == _RequestsViewMode.table
                            ? _RequestsTableView(
                                requests: filtered,
                                mobile: mobile,
                                onView: (request) => _showRequestDetailDialog(context, request),
                                onEdit: (request) => _showEditRequestDialog(context, request),
                                onStatus: (request) => _showStatusDialog(context, request),
                                onWhatsApp: _openWhatsApp,
                                onDelete: TuristarAuth.isAdmin ? _deleteRequest : null,
                              )
                            : _RequestsKanbanView(
                                requests: filtered,
                                onMove: _changeStatus,
                                onOpen: (request) => _showRequestDetailDialog(context, request),
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

  Future<void> _showCreateRequestDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _StaffCreateRequestDialog(
        onCreated: () {
          if (mounted) {
            setState(() => _requestsStream = AdminStore.watchTravelRequests());
          }
        },
      ),
    );
  }

  Future<void> _showRequestDetailDialog(BuildContext context, TravelRequest request) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _RequestDetailDialog(request: request),
    );
  }

  Future<void> _showEditRequestDialog(BuildContext context, TravelRequest request) async {
    final updated = await showDialog<TravelRequest>(
      context: context,
      builder: (context) => _RequestEditDialog(request: request),
    );
    if (updated == null || !mounted) return;
    try {
      await AdminStore.updateTravelRequest(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitacao atualizada.'), backgroundColor: TuristarColors.green),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(error)), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _showStatusDialog(BuildContext context, TravelRequest request) async {
    final status = await showDialog<String>(
      context: context,
      builder: (context) => _StatusPickerDialog(current: request.status),
    );
    if (status == null) return;
    await _changeStatus(request, status);
  }
}

class _RequestStatsRow extends StatelessWidget {
  const _RequestStatsRow({required this.stats, required this.mobile});

  final TravelRequestStats stats;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatTile(label: 'Total de Solicitacoes', value: stats.total, icon: Icons.inbox_outlined),
      _StatTile(label: 'Novas Solicitacoes', value: stats.newRequests, icon: Icons.fiber_new_outlined),
      _StatTile(label: 'Em Analise', value: stats.inAnalysis, icon: Icons.manage_search_outlined),
      _StatTile(label: 'Orcamentando', value: stats.quoting, icon: Icons.request_quote_outlined),
      _StatTile(label: 'Aguardando Cliente', value: stats.waitingClient, icon: Icons.hourglass_top_outlined),
      _StatTile(label: 'Confirmadas', value: stats.confirmed, icon: Icons.check_circle_outline),
      _StatTile(label: 'Canceladas', value: stats.cancelled, icon: Icons.cancel_outlined),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards.map((card) {
        final width = mobile ? (MediaQuery.sizeOf(context).width - 56) / 2 : 180.0;
        return SizedBox(width: width, child: card);
      }).toList(),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TuristarColors.line),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: TuristarColors.orange, size: 20),
          const SizedBox(height: 8),
          Text('$value', style: const TextStyle(color: TuristarColors.navy, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: TuristarColors.muted, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RequestsTableView extends StatelessWidget {
  const _RequestsTableView({
    required this.requests,
    required this.mobile,
    required this.onView,
    required this.onEdit,
    required this.onStatus,
    required this.onWhatsApp,
    this.onDelete,
  });

  final List<TravelRequest> requests;
  final bool mobile;
  final ValueChanged<TravelRequest> onView;
  final ValueChanged<TravelRequest> onEdit;
  final ValueChanged<TravelRequest> onStatus;
  final ValueChanged<TravelRequest> onWhatsApp;
  final ValueChanged<TravelRequest>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (mobile) {
      return ListView.separated(
        itemCount: requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final request = requests[index];
          return _MobileRequestCard(
            request: request,
            onView: () => onView(request),
            onEdit: () => onEdit(request),
            onStatus: () => onStatus(request),
            onWhatsApp: () => onWhatsApp(request),
            onDelete: onDelete == null ? null : () => onDelete!(request),
          );
        },
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TuristarColors.line),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 48),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(TuristarColors.navy.withOpacity(0.04)),
            columns: const [
              DataColumn(label: Text('Cliente', style: TextStyle(fontWeight: FontWeight.w900, color: TuristarColors.navy))),
              DataColumn(label: Text('Telefone')),
              DataColumn(label: Text('Destino')),
              DataColumn(label: Text('Data da Viagem')),
              DataColumn(label: Text('Orcamento')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Data da Solicitacao')),
              DataColumn(label: Text('Acoes')),
            ],
            rows: [
              for (final request in requests)
                DataRow(
                  cells: [
                    DataCell(Text(request.clientName, style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(request.phone.isEmpty ? '—' : request.phone)),
                    DataCell(Text(request.destination)),
                    DataCell(Text(_formatTravelDate(request.departureDate))),
                    DataCell(Text(request.budgetLabel)),
                    DataCell(_CrmStatusChip(status: request.status)),
                    DataCell(Text(_formatTravelDate(request.createdAt))),
                    DataCell(
                      _RequestActionsMenu(
                        onView: () => onView(request),
                        onEdit: () => onEdit(request),
                        onStatus: () => onStatus(request),
                        onWhatsApp: () => onWhatsApp(request),
                        onDelete: onDelete == null ? null : () => onDelete!(request),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileRequestCard extends StatelessWidget {
  const _MobileRequestCard({
    required this.request,
    required this.onView,
    required this.onEdit,
    required this.onStatus,
    required this.onWhatsApp,
    this.onDelete,
  });

  final TravelRequest request;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onStatus;
  final VoidCallback onWhatsApp;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(request.clientName, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
              ),
              _CrmStatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(request.destination, style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w700)),
          Text('Viagem: ${_formatTravelDate(request.departureDate)}', style: const TextStyle(color: TuristarColors.muted)),
          Text('Orcamento: ${request.budgetLabel}', style: const TextStyle(color: TuristarColors.muted)),
          const SizedBox(height: 10),
          _RequestActionsMenu(
            compact: true,
            onView: onView,
            onEdit: onEdit,
            onStatus: onStatus,
            onWhatsApp: onWhatsApp,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

class _RequestActionsMenu extends StatelessWidget {
  const _RequestActionsMenu({
    required this.onView,
    required this.onEdit,
    required this.onStatus,
    required this.onWhatsApp,
    this.onDelete,
    this.compact = false,
  });

  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onStatus;
  final VoidCallback onWhatsApp;
  final VoidCallback? onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _ActionChip(icon: Icons.visibility_outlined, label: 'Ver', onTap: onView),
          _ActionChip(icon: Icons.edit_outlined, label: 'Editar', onTap: onEdit),
          _ActionChip(icon: Icons.sync_alt, label: 'Status', onTap: onStatus),
          _ActionChip(icon: Icons.chat_outlined, label: 'WhatsApp', onTap: onWhatsApp),
          if (onDelete != null) _ActionChip(icon: Icons.delete_outline, label: 'Excluir', onTap: onDelete!),
        ],
      );
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: TuristarColors.navy),
      onSelected: (value) {
        switch (value) {
          case 'view':
            onView();
          case 'edit':
            onEdit();
          case 'status':
            onStatus();
          case 'whatsapp':
            onWhatsApp();
          case 'delete':
            onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'view', child: Text('Visualizar')),
        const PopupMenuItem(value: 'edit', child: Text('Editar')),
        const PopupMenuItem(value: 'status', child: Text('Alterar Status')),
        const PopupMenuItem(value: 'whatsapp', child: Text('Abrir WhatsApp')),
        if (onDelete != null)
          const PopupMenuItem(value: 'delete', child: Text('Excluir', style: TextStyle(color: Colors.red))),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: TuristarColors.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: TuristarColors.navy),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: TuristarColors.navy, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _RequestsKanbanView extends StatelessWidget {
  const _RequestsKanbanView({
    required this.requests,
    required this.onMove,
    required this.onOpen,
  });

  final List<TravelRequest> requests;
  final Future<void> Function(TravelRequest request, String status) onMove;
  final ValueChanged<TravelRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final status in TravelRequestStatus.all)
            _KanbanColumn(
              status: status,
              requests: requests.where((request) => TravelRequestStatus.normalize(request.status) == status).toList(),
              width: mobile ? 260 : 280,
              onMove: onMove,
              onOpen: onOpen,
            ),
        ],
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.status,
    required this.requests,
    required this.width,
    required this.onMove,
    required this.onOpen,
  });

  final String status;
  final List<TravelRequest> requests;
  final double width;
  final Future<void> Function(TravelRequest request, String status) onMove;
  final ValueChanged<TravelRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    return DragTarget<TravelRequest>(
      onWillAcceptWithDetails: (details) => TravelRequestStatus.normalize(details.data.status) != status,
      onAcceptWithDetails: (details) => onMove(details.data, status),
      builder: (context, candidate, rejected) {
        return Container(
          width: width,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: candidate.isNotEmpty ? TuristarColors.orange.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: candidate.isNotEmpty ? TuristarColors.orange : TuristarColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      TravelRequestStatus.label(status),
                      style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: TuristarColors.navy.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('${requests.length}', style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final request in requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Draggable<TravelRequest>(
                    data: request,
                    feedback: Material(
                      color: Colors.transparent,
                      child: SizedBox(width: width - 24, child: _KanbanCard(request: request, dragging: true)),
                    ),
                    childWhenDragging: Opacity(opacity: 0.35, child: _KanbanCard(request: request)),
                    child: _KanbanCard(request: request, onTap: () => onOpen(request)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _KanbanCard extends StatelessWidget {
  const _KanbanCard({required this.request, this.onTap, this.dragging = false});

  final TravelRequest request;
  final VoidCallback? onTap;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: dragging ? 4 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TuristarColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(request.clientName, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(request.destination, style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(_formatTravelDate(request.departureDate), style: const TextStyle(color: TuristarColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestDetailDialog extends StatelessWidget {
  const _RequestDetailDialog({required this.request});

  final TravelRequest request;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Detalhes da solicitacao', style: TextStyle(color: TuristarColors.navy, fontSize: 20, fontWeight: FontWeight.w900)),
                    ),
                    _CrmStatusChip(status: request.status),
                  ],
                ),
                const SizedBox(height: 18),
                _DetailSection(
                  title: 'Dados do cliente',
                  rows: [
                    _DetailRow('Nome', request.clientName),
                    _DetailRow('E-mail', request.clientEmail),
                    _DetailRow('Telefone', request.phone.isEmpty ? '—' : request.phone),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'Dados da viagem',
                  rows: [
                    _DetailRow('Destino', request.destination),
                    _DetailRow('Ida', _formatTravelDate(request.departureDate)),
                    _DetailRow('Volta', request.returnDate == null ? '—' : _formatTravelDate(request.returnDate!)),
                    _DetailRow('Adultos', '${request.adultCount}'),
                    _DetailRow('Criancas', '${request.children}'),
                    _DetailRow('Orcamento', request.budgetLabel),
                  ],
                ),
                if (request.notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _DetailSection(title: 'Observacoes', rows: [_DetailRow('', request.notes)]),
                ],
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'Registro',
                  rows: [
                    _DetailRow('Status atual', TravelRequestStatus.label(request.status)),
                    _DetailRow('Data de criacao', _formatTravelDateTime(request.createdAt)),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('Timeline de atendimento', style: TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 10),
                _RequestTimeline(entries: request.timeline),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestTimeline extends StatelessWidget {
  const _RequestTimeline({required this.entries});

  final List<TravelRequestTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text('Sem historico registrado.', style: TextStyle(color: TuristarColors.muted));
    }

    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: const BoxDecoration(color: TuristarColors.orange, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatTravelDateTime(entry.at), style: const TextStyle(color: TuristarColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(entry.message, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.rows});

  final String title;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          for (final row in rows) row,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return Text(value, style: const TextStyle(color: TuristarColors.text, height: 1.4));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: TuristarColors.muted, fontWeight: FontWeight.w700))),
          Expanded(child: Text(value, style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _RequestEditDialog extends StatefulWidget {
  const _RequestEditDialog({required this.request});

  final TravelRequest request;

  @override
  State<_RequestEditDialog> createState() => _RequestEditDialogState();
}

class _RequestEditDialogState extends State<_RequestEditDialog> {
  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController phoneController;
  late final TextEditingController destinationController;
  late final TextEditingController departureController;
  late final TextEditingController returnController;
  late final TextEditingController budgetController;
  late final TextEditingController notesController;
  late int adults;
  late int children;

  @override
  void initState() {
    super.initState();
    final request = widget.request;
    nameController = TextEditingController(text: request.clientName);
    emailController = TextEditingController(text: request.clientEmail);
    phoneController = TextEditingController(text: request.phone);
    destinationController = TextEditingController(text: request.destination);
    departureController = TextEditingController(text: request.departureDate);
    returnController = TextEditingController(text: request.returnDate ?? '');
    budgetController = TextEditingController(text: request.budget > 0 ? request.budget.toString() : '');
    notesController = TextEditingController(text: request.notes);
    adults = request.adultCount;
    children = request.children;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    destinationController.dispose();
    returnController.dispose();
    budgetController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Editar solicitacao', style: TextStyle(color: TuristarColors.navy, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome')),
                const SizedBox(height: 10),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'E-mail')),
                const SizedBox(height: 10),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Telefone')),
                const SizedBox(height: 10),
                TextField(controller: destinationController, decoration: const InputDecoration(labelText: 'Destino')),
                const SizedBox(height: 10),
                TextField(controller: departureController, decoration: const InputDecoration(labelText: 'Ida (AAAA-MM-DD)')),
                const SizedBox(height: 10),
                TextField(controller: returnController, decoration: const InputDecoration(labelText: 'Volta (opcional)')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text('Adultos: $adults')),
                    IconButton(onPressed: adults > 1 ? () => setState(() => adults--) : null, icon: const Icon(Icons.remove_circle_outline)),
                    IconButton(onPressed: () => setState(() => adults++), icon: const Icon(Icons.add_circle_outline, color: TuristarColors.orange)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text('Criancas: $children')),
                    IconButton(onPressed: children > 0 ? () => setState(() => children--) : null, icon: const Icon(Icons.remove_circle_outline)),
                    IconButton(onPressed: () => setState(() => children++), icon: const Icon(Icons.add_circle_outline, color: TuristarColors.orange)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: budgetController, decoration: const InputDecoration(labelText: 'Orcamento (R\$)'), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                TextField(controller: notesController, maxLines: 3, decoration: const InputDecoration(labelText: 'Observacoes')),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final budget = double.tryParse(budgetController.text.replaceAll(',', '.')) ?? 0;
                        Navigator.pop(
                          context,
                          widget.request.copyWith(
                            userEmail: emailController.text.trim(),
                            name: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                            destination: destinationController.text.trim(),
                            departureDate: departureController.text.trim(),
                            returnDate: returnController.text.trim().isEmpty ? null : returnController.text.trim(),
                            adults: adults,
                            children: children,
                            passengers: adults + children,
                            budget: budget,
                            notes: notesController.text.trim(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: Colors.white),
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPickerDialog extends StatelessWidget {
  const _StatusPickerDialog({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alterar status'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final status in TravelRequestStatus.all)
              ListTile(
                title: Text(TravelRequestStatus.label(status)),
                trailing: TravelRequestStatus.normalize(current) == status ? const Icon(Icons.check, color: TuristarColors.orange) : null,
                onTap: () => Navigator.pop(context, status),
              ),
          ],
        ),
      ),
    );
  }
}

class _StaffCreateRequestDialog extends StatefulWidget {
  const _StaffCreateRequestDialog({required this.onCreated});

  final VoidCallback onCreated;

  @override
  State<_StaffCreateRequestDialog> createState() => _StaffCreateRequestDialogState();
}

class _StaffCreateRequestDialogState extends State<_StaffCreateRequestDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final originController = TextEditingController(text: 'GRU');
  final destinationController = TextEditingController();
  final departureController = TextEditingController();
  final returnController = TextEditingController();
  final budgetController = TextEditingController();
  final notesController = TextEditingController();
  int adults = 2;
  int children = 0;
  bool isSubmitting = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    originController.dispose();
    destinationController.dispose();
    departureController.dispose();
    returnController.dispose();
    budgetController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate() || isSubmitting) return;
    setState(() => isSubmitting = true);
    try {
      await AdminStore.createTravelRequestAsStaff(
        name: nameController.text,
        email: emailController.text,
        phone: phoneController.text,
        origin: originController.text,
        destination: destinationController.text,
        departureDate: departureController.text,
        returnDate: returnController.text.trim().isEmpty ? null : returnController.text.trim(),
        adults: adults,
        children: children,
        budget: double.tryParse(budgetController.text.replaceAll(',', '.')) ?? 0,
        notes: notesController.text,
      );
      if (!mounted) return;
      widget.onCreated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitacao criada.'), backgroundColor: TuristarColors.green),
      );
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Criar solicitacao', style: TextStyle(color: TuristarColors.navy, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome'), validator: _required),
                  const SizedBox(height: 10),
                  TextFormField(controller: emailController, decoration: const InputDecoration(labelText: 'E-mail'), validator: _required),
                  const SizedBox(height: 10),
                  TextFormField(controller: phoneController, decoration: const InputDecoration(labelText: 'Telefone')),
                  const SizedBox(height: 10),
                  TextFormField(controller: originController, decoration: const InputDecoration(labelText: 'Origem'), validator: _required),
                  const SizedBox(height: 10),
                  TextFormField(controller: destinationController, decoration: const InputDecoration(labelText: 'Destino'), validator: _required),
                  const SizedBox(height: 10),
                  TextFormField(controller: departureController, decoration: const InputDecoration(labelText: 'Ida (AAAA-MM-DD)'), validator: _required),
                  const SizedBox(height: 10),
                  TextFormField(controller: returnController, decoration: const InputDecoration(labelText: 'Volta (opcional)')),
                  const SizedBox(height: 10),
                  TextFormField(controller: budgetController, decoration: const InputDecoration(labelText: 'Orcamento (R\$)'), keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  TextFormField(controller: notesController, maxLines: 3, decoration: const InputDecoration(labelText: 'Observacoes')),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: Colors.white),
                        child: isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Criar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Campo obrigatorio' : null;
}

class _RequestsEmptyState extends StatelessWidget {
  const _RequestsEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TuristarColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight_takeoff, size: 56, color: TuristarColors.navy.withOpacity(0.35)),
            const SizedBox(height: 16),
            const Text('Nenhuma solicitacao encontrada', style: TextStyle(color: TuristarColors.navy, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
              'Quando clientes solicitarem viagens, elas aparecerao aqui para gestao comercial.',
              textAlign: TextAlign.center,
              style: TextStyle(color: TuristarColors.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Criar Solicitacao'),
              style: ElevatedButton.styleFrom(
                backgroundColor: TuristarColors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrmFilterChip extends StatelessWidget {
  const _CrmFilterChip({required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: TuristarColors.orange.withOpacity(0.18),
        checkmarkColor: TuristarColors.navy,
        labelStyle: TextStyle(
          color: selected ? TuristarColors.navy : TuristarColors.muted,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _CrmStatusChip extends StatelessWidget {
  const _CrmStatusChip({required this.status});

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

class _CrmErrorState extends StatelessWidget {
  const _CrmErrorState({required this.message, this.onRetry});

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

String _formatTravelDate(String raw) {
  try {
    final date = DateTime.parse(raw);
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  } catch (_) {
    return raw;
  }
}

String _formatTravelDateTime(String raw) {
  try {
    final date = DateTime.parse(raw).toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  } catch (_) {
    return raw;
  }
}
