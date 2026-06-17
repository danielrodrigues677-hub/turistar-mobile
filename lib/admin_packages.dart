import 'package:flutter/material.dart';

import 'firestore_schema.dart';
import 'admin_permissions.dart';
import 'main.dart';
import 'package_page.dart';
import 'package_store.dart';

class AdminPackagesPage extends StatefulWidget {
  const AdminPackagesPage({super.key});

  @override
  State<AdminPackagesPage> createState() => _AdminPackagesPageState();
}

class _AdminPackagesPageState extends State<AdminPackagesPage> {
  late Stream<List<TravelPackage>> _packagesStream;
  bool seeding = false;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _packagesStream = PackageStore.watchAllPackages();
  }

  Future<void> _seedDefaults() async {
    setState(() => seeding = true);
    try {
      await PackageStore.seedDefaultPackagesIfEmpty();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pacotes iniciais publicados.'), backgroundColor: TuristarColors.green),
      );
      setState(() => _packagesStream = PackageStore.watchAllPackages());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(error)), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => seeding = false);
    }
  }

  List<TravelPackage> _filter(List<TravelPackage> packages) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return packages;
    return packages.where((item) {
      return item.title.toLowerCase().contains(query) ||
          item.destinationName.toLowerCase().contains(query) ||
          item.country.toLowerCase().contains(query) ||
          item.slug.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _toggleActive(TravelPackage package) async {
    try {
      await PackageStore.savePackage(package.copyWith(active: !package.active, updatedAt: DateTime.now().toUtc().toIso8601String()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(package.active ? 'Pacote inativado.' : 'Pacote ativado.'), backgroundColor: TuristarColors.navy),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(error)), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _duplicatePackage(TravelPackage package) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final copy = package.copyWith(
      title: '${package.title} (copia)',
      slug: '${package.slug}-copia-${DateTime.now().millisecondsSinceEpoch}',
      active: false,
      featured: false,
      updatedAt: now,
    );
    final duplicate = TravelPackage(
      id: '',
      title: copy.title,
      destinationName: copy.destinationName,
      country: copy.country,
      city: copy.city,
      shortDescription: copy.shortDescription,
      imageUrl: copy.imageUrl,
      galleryImages: copy.galleryImages,
      startingPrice: copy.startingPrice,
      promotionalText: copy.promotionalText,
      description: copy.description,
      inclusions: copy.inclusions,
      exclusions: copy.exclusions,
      travelPeriod: copy.travelPeriod,
      duration: copy.duration,
      nights: copy.nights,
      hotelCategory: copy.hotelCategory,
      category: copy.category,
      featured: copy.featured,
      active: copy.active,
      displayOrder: copy.displayOrder + 1,
      slug: copy.slug,
      seoTitle: copy.seoTitle,
      seoDescription: copy.seoDescription,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await PackageStore.savePackage(duplicate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pacote duplicado.'), backgroundColor: TuristarColors.green),
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
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Pacotes'),
        actions: [
          IconButton(
            tooltip: 'Importar pacotes iniciais',
            onPressed: seeding ? null : _seedDefaults,
            icon: seeding
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_download_outlined),
          ),
          IconButton(
            tooltip: 'Novo pacote',
            onPressed: () => _openEditor(context, null),
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
                title: 'Gestao de Pacotes',
                subtitle: 'Cadastre destinos com imagens por URL e controle de publicacao.',
              ),
              const SizedBox(height: 14),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Pesquisar por destino, pais ou slug',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => searchQuery = value),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: StreamBuilder<List<TravelPackage>>(
                  stream: _packagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: TuristarColors.orange));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text(authErrorMessage(snapshot.error!)));
                    }

                    final packages = _filter(snapshot.data ?? []);
                    if (packages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Nenhum pacote encontrado.', style: TextStyle(color: TuristarColors.muted)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: seeding ? null : _seedDefaults,
                              style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: Colors.white),
                              child: const Text('Importar pacotes iniciais'),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: packages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final package = packages[index];
                        return _AdminPackageTile(
                          package: package,
                          onEdit: () => _openEditor(context, package),
                          onPreview: () => openPackagePage(context, package),
                          onDuplicate: () => _duplicatePackage(package),
                          onToggleActive: () => _toggleActive(package),
                          onDelete: AdminPermissions.canDeleteRecords(TuristarAuth.currentRole) ? () => _deletePackage(package) : null,
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

  Future<void> _openEditor(BuildContext context, TravelPackage? package) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminPackageEditorPage(package: package)),
    );
    if (mounted) setState(() => _packagesStream = PackageStore.watchAllPackages());
  }

  Future<void> _deletePackage(TravelPackage package) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir pacote'),
        content: Text('Deseja excluir ${package.title}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PackageStore.deletePackage(package.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pacote excluido.'), backgroundColor: TuristarColors.navy),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(error)), backgroundColor: Colors.red.shade700),
      );
    }
  }
}

class _AdminPackageTile extends StatelessWidget {
  const _AdminPackageTile({
    required this.package,
    required this.onEdit,
    required this.onPreview,
    required this.onDuplicate,
    required this.onToggleActive,
    this.onDelete,
  });

  final TravelPackage package;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onDuplicate;
  final VoidCallback onToggleActive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 72, height: 72, child: PackageImage(url: package.imageUrl, fit: BoxFit.cover)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(package.title, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
                Text('/pacotes/${package.slug}', style: const TextStyle(color: TuristarColors.muted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(package.priceLabel, style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w700, fontSize: 12)),
                Wrap(
                  spacing: 8,
                  children: [
                    _Badge(label: package.active ? 'Ativo' : 'Inativo', active: package.active),
                    if (package.featured) const _Badge(label: 'Home', active: true),
                    if (package.category.isNotEmpty) _Badge(label: PackageCategory.label(package.category), active: true),
                  ],
                ),
              ],
            ),
          ),
          IconButton(onPressed: onPreview, icon: const Icon(Icons.open_in_new, color: TuristarColors.navy)),
          IconButton(onPressed: onDuplicate, icon: const Icon(Icons.copy_outlined, color: TuristarColors.muted)),
          IconButton(onPressed: onToggleActive, icon: Icon(package.active ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: TuristarColors.orange)),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, color: TuristarColors.orange)),
          if (onDelete != null)
            IconButton(onPressed: onDelete, icon: Icon(Icons.delete_outline, color: Colors.red.shade400)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? TuristarColors.orange.withOpacity(0.15) : TuristarColors.line,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: active ? TuristarColors.navy : TuristarColors.muted, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class AdminPackageEditorPage extends StatefulWidget {
  const AdminPackageEditorPage({super.key, this.package});

  final TravelPackage? package;

  @override
  State<AdminPackageEditorPage> createState() => _AdminPackageEditorPageState();
}

class _AdminPackageEditorPageState extends State<AdminPackageEditorPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController destinationController;
  late final TextEditingController countryController;
  late final TextEditingController cityController;
  late final TextEditingController slugController;
  late final TextEditingController priceController;
  late final TextEditingController promotionalTextController;
  late final TextEditingController shortDescriptionController;
  late final TextEditingController descriptionController;
  late final TextEditingController travelPeriodController;
  late final TextEditingController durationController;
  late final TextEditingController nightsController;
  late final TextEditingController hotelCategoryController;
  late final TextEditingController imageUrlController;
  late final TextEditingController galleryController;
  late final TextEditingController inclusionsController;
  late final TextEditingController exclusionsController;
  late final TextEditingController seoTitleController;
  late final TextEditingController seoDescriptionController;
  late final TextEditingController displayOrderController;
  late bool featured;
  late bool active;
  late String category;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final package = widget.package;
    titleController = TextEditingController(text: package?.title ?? '');
    destinationController = TextEditingController(text: package?.destinationName ?? '');
    countryController = TextEditingController(text: package?.country ?? '');
    cityController = TextEditingController(text: package?.city ?? '');
    slugController = TextEditingController(text: package?.slug ?? '');
    priceController = TextEditingController(text: package == null || package.startingPrice <= 0 ? '' : package.startingPrice.toString());
    promotionalTextController = TextEditingController(text: package?.promotionalText ?? '');
    shortDescriptionController = TextEditingController(text: package?.shortDescription ?? '');
    descriptionController = TextEditingController(text: package?.description ?? '');
    travelPeriodController = TextEditingController(text: package?.travelPeriod ?? '');
    durationController = TextEditingController(text: package?.duration ?? '');
    nightsController = TextEditingController(text: package == null || package.nights <= 0 ? '' : '${package.nights}');
    hotelCategoryController = TextEditingController(text: package?.hotelCategory ?? '');
    imageUrlController = TextEditingController(text: package?.imageUrl ?? '');
    galleryController = TextEditingController(text: package?.galleryImages.join('\n') ?? '');
    inclusionsController = TextEditingController(text: package?.inclusions.join('\n') ?? '');
    exclusionsController = TextEditingController(text: package?.exclusions.join('\n') ?? '');
    seoTitleController = TextEditingController(text: package?.seoTitle ?? '');
    seoDescriptionController = TextEditingController(text: package?.seoDescription ?? '');
    displayOrderController = TextEditingController(text: '${package?.displayOrder ?? 0}');
    featured = package?.featured ?? false;
    active = package?.active ?? true;
    category = package?.category.isNotEmpty == true ? package!.category : PackageCategory.nacional;
  }

  @override
  void dispose() {
    titleController.dispose();
    destinationController.dispose();
    countryController.dispose();
    cityController.dispose();
    slugController.dispose();
    priceController.dispose();
    promotionalTextController.dispose();
    shortDescriptionController.dispose();
    descriptionController.dispose();
    travelPeriodController.dispose();
    durationController.dispose();
    nightsController.dispose();
    hotelCategoryController.dispose();
    imageUrlController.dispose();
    galleryController.dispose();
    inclusionsController.dispose();
    exclusionsController.dispose();
    seoTitleController.dispose();
    seoDescriptionController.dispose();
    displayOrderController.dispose();
    super.dispose();
  }

  List<String> _lines(TextEditingController controller) {
    return controller.text.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
  }

  TravelPackage _buildDraft() {
    final now = DateTime.now().toUtc().toIso8601String();
    return TravelPackage(
      id: widget.package?.id ?? '',
      title: titleController.text.trim(),
      destinationName: destinationController.text.trim(),
      country: countryController.text.trim(),
      city: cityController.text.trim(),
      shortDescription: shortDescriptionController.text.trim(),
      imageUrl: imageUrlController.text.trim(),
      galleryImages: _lines(galleryController),
      startingPrice: double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0,
      promotionalText: promotionalTextController.text.trim(),
      description: descriptionController.text.trim(),
      inclusions: _lines(inclusionsController),
      exclusions: _lines(exclusionsController),
      travelPeriod: travelPeriodController.text.trim(),
      duration: durationController.text.trim(),
      nights: int.tryParse(nightsController.text.trim()) ?? 0,
      hotelCategory: hotelCategoryController.text.trim(),
      category: category,
      featured: featured,
      active: active,
      displayOrder: int.tryParse(displayOrderController.text.trim()) ?? 0,
      slug: slugController.text.trim().toLowerCase(),
      seoTitle: seoTitleController.text.trim(),
      seoDescription: seoDescriptionController.text.trim(),
      createdAt: widget.package?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _previewBeforeSave() async {
    if (!formKey.currentState!.validate()) return;
    final draft = _buildDraft();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pre-visualizacao do pacote'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (draft.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(height: 140, width: double.infinity, child: PackageImage(url: draft.imageUrl, fit: BoxFit.cover)),
                ),
              const SizedBox(height: 12),
              Text(draft.title, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 18)),
              Text('${draft.destinationName}, ${draft.country}', style: const TextStyle(color: TuristarColors.muted)),
              const SizedBox(height: 8),
              Text(draft.shortDescription.isNotEmpty ? draft.shortDescription : draft.description, maxLines: 4, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(draft.priceLabel, style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _save();
            },
            style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: Colors.white),
            child: const Text('Confirmar e salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate() || isSaving) return;
    setState(() => isSaving = true);
    try {
      await PackageStore.savePackage(_buildDraft());
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pacote salvo.'), backgroundColor: TuristarColors.green),
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
    final autoPrice = _buildDraft().priceLabel;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: Text(widget.package == null ? 'Novo pacote' : 'Editar pacote'),
        actions: [
          TextButton(onPressed: isSaving ? null : _previewBeforeSave, child: const Text('Pre-visualizar', style: TextStyle(color: Colors.white))),
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
                SwitchListTile(title: const Text('Ativo'), value: active, onChanged: (value) => setState(() => active = value)),
                SwitchListTile(title: const Text('Destacar na Home'), value: featured, onChanged: (value) => setState(() => featured = value)),
                TextFormField(controller: titleController, decoration: const InputDecoration(labelText: 'Nome do pacote'), validator: _required),
                const SizedBox(height: 12),
                ResponsiveFields(children: [
                  TextFormField(controller: destinationController, decoration: const InputDecoration(labelText: 'Destino'), validator: _required),
                  TextFormField(controller: slugController, decoration: const InputDecoration(labelText: 'Slug (/pacotes/slug)'), validator: _required),
                ]),
                const SizedBox(height: 12),
                ResponsiveFields(children: [
                  TextFormField(controller: countryController, decoration: const InputDecoration(labelText: 'Pais')),
                  TextFormField(controller: cityController, decoration: const InputDecoration(labelText: 'Cidade')),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: PackageCategory.all.map((item) => DropdownMenuItem(value: item, child: Text(PackageCategory.label(item)))).toList(),
                  onChanged: (value) => setState(() => category = value ?? PackageCategory.nacional),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: shortDescriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'Descricao curta')),
                const SizedBox(height: 12),
                TextFormField(controller: descriptionController, maxLines: 4, decoration: const InputDecoration(labelText: 'Descricao completa')),
                const SizedBox(height: 12),
                ResponsiveFields(children: [
                  TextFormField(controller: priceController, decoration: const InputDecoration(labelText: 'Preco (R\$)'), keyboardType: TextInputType.number),
                  TextFormField(controller: promotionalTextController, decoration: const InputDecoration(labelText: 'Texto promocional (opcional)')),
                ]),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Texto automatico no site: $autoPrice', style: const TextStyle(color: TuristarColors.muted, fontSize: 12)),
                ),
                const SizedBox(height: 12),
                ResponsiveFields(children: [
                  TextFormField(controller: travelPeriodController, decoration: const InputDecoration(labelText: 'Periodo de viagem')),
                  TextFormField(controller: durationController, decoration: const InputDecoration(labelText: 'Duracao')),
                ]),
                const SizedBox(height: 12),
                ResponsiveFields(children: [
                  TextFormField(controller: nightsController, decoration: const InputDecoration(labelText: 'Quantidade de noites'), keyboardType: TextInputType.number),
                  TextFormField(controller: hotelCategoryController, decoration: const InputDecoration(labelText: 'Tipo de hospedagem')),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: displayOrderController, decoration: const InputDecoration(labelText: 'Ordem de exibicao'), keyboardType: TextInputType.number),
                const SizedBox(height: 18),
                TextFormField(controller: imageUrlController, decoration: const InputDecoration(labelText: 'URL da imagem principal')),
                if (imageUrlController.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(height: 160, width: double.infinity, child: PackageImage(url: imageUrlController.text)),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(controller: galleryController, maxLines: 4, decoration: const InputDecoration(labelText: 'URLs da galeria (uma por linha)')),
                const SizedBox(height: 18),
                TextFormField(controller: inclusionsController, maxLines: 5, decoration: const InputDecoration(labelText: 'Itens inclusos (um por linha)')),
                const SizedBox(height: 12),
                TextFormField(controller: exclusionsController, maxLines: 5, decoration: const InputDecoration(labelText: 'Itens nao inclusos (um por linha)')),
                const SizedBox(height: 18),
                const Text('SEO', style: TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 8),
                TextFormField(controller: seoTitleController, decoration: const InputDecoration(labelText: 'Meta Title')),
                const SizedBox(height: 12),
                TextFormField(controller: seoDescriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Meta Description')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Campo obrigatorio' : null;
}
