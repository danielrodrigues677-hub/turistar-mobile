import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
                title: 'Pacotes Turistar',
                subtitle: 'Gerencie destinos, precos, imagens e SEO exibidos na Home e nas paginas /pacotes.',
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

                    final packages = snapshot.data ?? [];
                    if (packages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Nenhum pacote cadastrado.', style: TextStyle(color: TuristarColors.muted)),
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
                          onDelete: TuristarAuth.isAdmin ? () => _deletePackage(package) : null,
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
    this.onDelete,
  });

  final TravelPackage package;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
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
                  ],
                ),
              ],
            ),
          ),
          IconButton(onPressed: onPreview, icon: const Icon(Icons.open_in_new, color: TuristarColors.navy)),
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
  late final TextEditingController slugController;
  late final TextEditingController priceController;
  late final TextEditingController descriptionController;
  late final TextEditingController travelPeriodController;
  late final TextEditingController durationController;
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
  bool isSaving = false;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    final package = widget.package;
    titleController = TextEditingController(text: package?.title ?? '');
    destinationController = TextEditingController(text: package?.destinationName ?? '');
    countryController = TextEditingController(text: package?.country ?? '');
    slugController = TextEditingController(text: package?.slug ?? '');
    priceController = TextEditingController(text: package == null || package.startingPrice <= 0 ? '' : package.startingPrice.toString());
    descriptionController = TextEditingController(text: package?.description ?? '');
    travelPeriodController = TextEditingController(text: package?.travelPeriod ?? '');
    durationController = TextEditingController(text: package?.duration ?? '');
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
  }

  @override
  void dispose() {
    titleController.dispose();
    destinationController.dispose();
    countryController.dispose();
    slugController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    travelPeriodController.dispose();
    durationController.dispose();
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

  Future<void> _uploadImages({required bool mainImage}) async {
    final slug = slugController.text.trim().isEmpty ? 'pacote' : slugController.text.trim();
    final result = await FilePicker.pickFiles(type: FileType.image, allowMultiple: !mainImage, withData: true);
    if (result == null || result.files.isEmpty) return;

    setState(() => isUploading = true);
    try {
      final uploaded = <String>[];
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        final url = await PackageStore.uploadPackageImage(
          slug: slug,
          bytes: bytes,
          fileName: file.name,
          contentType: _contentTypeForName(file.name),
        );
        uploaded.add(url);
      }

      if (!mounted || uploaded.isEmpty) return;
      setState(() {
        if (mainImage) {
          imageUrlController.text = uploaded.first;
        } else {
          final current = _lines(galleryController);
          galleryController.text = [...current, ...uploaded].join('\n');
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(error)), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  String? _contentTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate() || isSaving) return;
    setState(() => isSaving = true);
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final package = TravelPackage(
        id: widget.package?.id ?? '',
        title: titleController.text.trim(),
        destinationName: destinationController.text.trim(),
        country: countryController.text.trim(),
        imageUrl: imageUrlController.text.trim(),
        galleryImages: _lines(galleryController),
        startingPrice: double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0,
        description: descriptionController.text.trim(),
        inclusions: _lines(inclusionsController),
        exclusions: _lines(exclusionsController),
        travelPeriod: travelPeriodController.text.trim(),
        duration: durationController.text.trim(),
        hotelCategory: hotelCategoryController.text.trim(),
        featured: featured,
        active: active,
        displayOrder: int.tryParse(displayOrderController.text.trim()) ?? 0,
        slug: slugController.text.trim().toLowerCase(),
        seoTitle: seoTitleController.text.trim(),
        seoDescription: seoDescriptionController.text.trim(),
        createdAt: widget.package?.createdAt ?? now,
        updatedAt: now,
      );

      await PackageStore.savePackage(package);
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: Text(widget.package == null ? 'Novo pacote' : 'Editar pacote'),
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
                SwitchListTile(
                  title: const Text('Ativo'),
                  value: active,
                  onChanged: (value) => setState(() => active = value),
                ),
                SwitchListTile(
                  title: const Text('Destacar na Home'),
                  value: featured,
                  onChanged: (value) => setState(() => featured = value),
                ),
                TextFormField(controller: titleController, decoration: const InputDecoration(labelText: 'Nome do pacote'), validator: _required),
                const SizedBox(height: 12),
                ResponsiveFields(children: [
                  TextFormField(controller: destinationController, decoration: const InputDecoration(labelText: 'Destino'), validator: _required),
                  TextFormField(controller: slugController, decoration: const InputDecoration(labelText: 'Slug (/pacotes/slug)'), validator: _required),
                ]),
                const SizedBox(height: 12),
                ResponsiveFields(children: [
                  TextFormField(controller: countryController, decoration: const InputDecoration(labelText: 'Pais')),
                  TextFormField(controller: priceController, decoration: const InputDecoration(labelText: 'Preco inicial (R\$)'), keyboardType: TextInputType.number),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: descriptionController, maxLines: 4, decoration: const InputDecoration(labelText: 'Descricao')),
                const SizedBox(height: 12),
                ResponsiveFields(children: [
                  TextFormField(controller: travelPeriodController, decoration: const InputDecoration(labelText: 'Periodo de viagem')),
                  TextFormField(controller: durationController, decoration: const InputDecoration(labelText: 'Duracao')),
                ]),
                const SizedBox(height: 12),
                ResponsiveFields(children: [
                  TextFormField(controller: hotelCategoryController, decoration: const InputDecoration(labelText: 'Categoria hotel')),
                  TextFormField(controller: displayOrderController, decoration: const InputDecoration(labelText: 'Ordem de exibicao'), keyboardType: TextInputType.number),
                ]),
                const SizedBox(height: 18),
                const Text('Imagem principal', style: TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                TextFormField(controller: imageUrlController, decoration: const InputDecoration(labelText: 'URL da imagem principal')),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: isUploading ? null : () => _uploadImages(mainImage: true),
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(isUploading ? 'Enviando...' : 'Upload imagem principal'),
                ),
                if (imageUrlController.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(height: 160, width: double.infinity, child: PackageImage(url: imageUrlController.text)),
                  ),
                ],
                const SizedBox(height: 18),
                const Text('Galeria de imagens', style: TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: galleryController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'URLs da galeria (uma por linha)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: isUploading ? null : () => _uploadImages(mainImage: false),
                  icon: const Icon(Icons.collections_outlined),
                  label: const Text('Upload multiplo para galeria'),
                ),
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
