import 'package:flutter/material.dart';

import 'admin_permissions.dart';
import 'featured_packages_store.dart';
import 'main.dart';
import 'package_page.dart';
import 'package_store.dart';

class AdminFeaturedPackagesPage extends StatefulWidget {
  const AdminFeaturedPackagesPage({super.key});

  @override
  State<AdminFeaturedPackagesPage> createState() => _AdminFeaturedPackagesPageState();
}

class _AdminFeaturedPackagesPageState extends State<AdminFeaturedPackagesPage> {
  late Stream<List<FeaturedPackage>> _stream;
  bool isSavingOrder = false;

  @override
  void initState() {
    super.initState();
    _stream = FeaturedPackagesStore.watchFeatured();
  }

  Future<void> _openEditor({FeaturedPackage? featured, TravelPackage? source}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _FeaturedEditorPage(featured: featured, sourcePackage: source)),
    );
    if (mounted) setState(() => _stream = FeaturedPackagesStore.watchFeatured());
  }

  Future<void> _reorder(int oldIndex, int newIndex, List<FeaturedPackage> items) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final updated = [...items];
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    setState(() => isSavingOrder = true);
    try {
      await FeaturedPackagesStore.reorderFeatured(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(error)), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => isSavingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Pacotes Mais Vendidos'),
        actions: [
          if (isSavingOrder)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ),
          IconButton(
            tooltip: 'Adicionar destaque',
            onPressed: () => _pickPackageAndAdd(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BookingStepHeader(
                step: 'Conteudo do Site',
                title: 'Pacotes Mais Vendidos',
                subtitle: 'Defina a ordem e os destaques exibidos na Home. Arraste para reordenar.',
              ),
              const SizedBox(height: 18),
              Expanded(
                child: StreamBuilder<List<FeaturedPackage>>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: TuristarColors.orange));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text(authErrorMessage(snapshot.error!)));
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Nenhum destaque cadastrado.', style: TextStyle(color: TuristarColors.muted)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _pickPackageAndAdd,
                              style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: Colors.white),
                              child: const Text('Adicionar pacote da vitrine'),
                            ),
                          ],
                        ),
                      );
                    }
                    return ReorderableListView.builder(
                      itemCount: items.length,
                      onReorder: (oldIndex, newIndex) => _reorder(oldIndex, newIndex, items),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _FeaturedTile(
                          key: ValueKey(item.id),
                          item: item,
                          onEdit: () => _openEditor(featured: item),
                          onToggle: () => _toggle(item),
                          onDelete: AdminPermissions.canDeleteRecords(TuristarAuth.currentRole) ? () => _delete(item) : null,
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

  Future<void> _pickPackageAndAdd() async {
    final packages = await PackageStore.listPackages(activeOnly: true);
    if (!mounted) return;
    if (packages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastre pacotes ativos antes de criar destaques.'), backgroundColor: TuristarColors.navy),
      );
      return;
    }
    final selected = await showDialog<TravelPackage>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Escolher pacote'),
        children: packages.take(20).map((package) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, package),
            child: Text(package.title),
          );
        }).toList(),
      ),
    );
    if (selected == null) return;
    await _openEditor(source: selected);
  }

  Future<void> _toggle(FeaturedPackage item) async {
    try {
      await FeaturedPackagesStore.saveFeatured(item.copyWith(active: !item.active));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(error)), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _delete(FeaturedPackage item) async {
    try {
      await FeaturedPackagesStore.deleteFeatured(item.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(error)), backgroundColor: Colors.red.shade700),
      );
    }
  }
}

class _FeaturedTile extends StatelessWidget {
  const _FeaturedTile({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onToggle,
    this.onDelete,
  });

  final FeaturedPackage item;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.drag_handle, color: TuristarColors.muted),
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 72, height: 72, child: PackageImage(url: item.imageUrl, fit: BoxFit.cover)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
                Text(item.priceLabel, style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w700, fontSize: 12)),
                Text(item.active ? 'Ativo na Home' : 'Inativo', style: TextStyle(color: item.active ? TuristarColors.navy : TuristarColors.muted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(onPressed: onToggle, icon: Icon(item.active ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: TuristarColors.orange)),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, color: TuristarColors.orange)),
          if (onDelete != null) IconButton(onPressed: onDelete, icon: Icon(Icons.delete_outline, color: Colors.red.shade400)),
        ],
      ),
    );
  }
}

class _FeaturedEditorPage extends StatefulWidget {
  const _FeaturedEditorPage({this.featured, this.sourcePackage});

  final FeaturedPackage? featured;
  final TravelPackage? sourcePackage;

  @override
  State<_FeaturedEditorPage> createState() => _FeaturedEditorPageState();
}

class _FeaturedEditorPageState extends State<_FeaturedEditorPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController imageUrlController;
  late final TextEditingController priceController;
  late final TextEditingController promotionalTextController;
  late bool active;
  bool isSaving = false;
  late String packageId;

  @override
  void initState() {
    super.initState();
    final featured = widget.featured;
    final source = widget.sourcePackage;
    packageId = featured?.packageId ?? source?.id ?? source?.slug ?? '';
    titleController = TextEditingController(text: featured?.title ?? source?.title ?? '');
    imageUrlController = TextEditingController(text: featured?.imageUrl ?? source?.imageUrl ?? '');
    priceController = TextEditingController(
      text: featured != null
          ? (featured.price > 0 ? featured.price.toString() : '')
          : (source != null && source.startingPrice > 0 ? source.startingPrice.toString() : ''),
    );
    promotionalTextController = TextEditingController(text: featured?.promotionalText ?? source?.promotionalText ?? '');
    active = featured?.active ?? true;
  }

  @override
  void dispose() {
    titleController.dispose();
    imageUrlController.dispose();
    priceController.dispose();
    promotionalTextController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate() || isSaving) return;
    setState(() => isSaving = true);
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final item = FeaturedPackage(
        id: widget.featured?.id ?? '',
        packageId: packageId,
        title: titleController.text.trim(),
        imageUrl: imageUrlController.text.trim(),
        price: double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0,
        promotionalText: promotionalTextController.text.trim(),
        active: active,
        displayOrder: widget.featured?.displayOrder ?? 999,
        createdAt: widget.featured?.createdAt ?? now,
        updatedAt: now,
      );
      await FeaturedPackagesStore.saveFeatured(item);
      if (!mounted) return;
      Navigator.pop(context);
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
    final preview = FeaturedPackage(
      id: '',
      packageId: packageId,
      title: titleController.text.trim(),
      imageUrl: imageUrlController.text.trim(),
      price: double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0,
      promotionalText: promotionalTextController.text.trim(),
      active: active,
      displayOrder: 0,
      createdAt: '',
      updatedAt: '',
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: Text(widget.featured == null ? 'Novo destaque' : 'Editar destaque'),
        actions: [
          TextButton(
            onPressed: isSaving ? null : _save,
            child: isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Form(
            key: formKey,
            child: ListView(
              children: [
                SwitchListTile(title: const Text('Ativo na Home'), value: active, onChanged: (value) => setState(() => active = value)),
                TextFormField(controller: titleController, decoration: const InputDecoration(labelText: 'Titulo exibido'), validator: _required),
                const SizedBox(height: 12),
                TextFormField(controller: imageUrlController, decoration: const InputDecoration(labelText: 'URL da imagem')),
                const SizedBox(height: 12),
                ResponsiveFields(children: [
                  TextFormField(controller: priceController, decoration: const InputDecoration(labelText: 'Preco (R\$)'), keyboardType: TextInputType.number),
                  TextFormField(controller: promotionalTextController, decoration: const InputDecoration(labelText: 'Texto promocional')),
                ]),
                const SizedBox(height: 8),
                Text('Preview: ${preview.priceLabel}', style: const TextStyle(color: TuristarColors.muted, fontSize: 12)),
                if (imageUrlController.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(height: 160, width: double.infinity, child: PackageImage(url: imageUrlController.text, fit: BoxFit.cover)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Campo obrigatorio' : null;
}
