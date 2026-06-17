import 'package:flutter/material.dart';

import 'admin_permissions.dart';
import 'main.dart';
import 'site_media_store.dart';

class AdminBannersPage extends StatefulWidget {
  const AdminBannersPage({super.key});

  @override
  State<AdminBannersPage> createState() => _AdminBannersPageState();
}

class _AdminBannersPageState extends State<AdminBannersPage> {
  late Stream<List<SiteBanner>> _stream;
  bool isSavingOrder = false;

  @override
  void initState() {
    super.initState();
    _stream = SiteMediaStore.watchBanners();
  }

  Future<void> _openEditor(SiteBanner? banner) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _BannerEditorPage(banner: banner)));
    if (mounted) setState(() => _stream = SiteMediaStore.watchBanners());
  }

  Future<void> _reorder(int oldIndex, int newIndex, List<SiteBanner> items) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final updated = [...items];
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    setState(() => isSavingOrder = true);
    try {
      await SiteMediaStore.reorderBanners(updated);
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
        title: const Text('Banners'),
        actions: [
          if (isSavingOrder)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ),
          IconButton(onPressed: () => _openEditor(null), icon: const Icon(Icons.add)),
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
                title: 'Gestao de Banners',
                subtitle: 'Cadastre banners com imagem por URL, CTA e ordem de exibicao.',
              ),
              const SizedBox(height: 18),
              Expanded(
                child: StreamBuilder<List<SiteBanner>>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: TuristarColors.orange));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text(authErrorMessage(snapshot.error!)));
                    }
                    final banners = snapshot.data ?? [];
                    if (banners.isEmpty) {
                      return const Center(child: Text('Nenhum banner cadastrado.', style: TextStyle(color: TuristarColors.muted)));
                    }
                    return ReorderableListView.builder(
                      itemCount: banners.length,
                      onReorder: (oldIndex, newIndex) => _reorder(oldIndex, newIndex, banners),
                      itemBuilder: (context, index) {
                        final banner = banners[index];
                        return _BannerTile(
                          key: ValueKey(banner.id),
                          banner: banner,
                          onEdit: () => _openEditor(banner),
                          onDelete: AdminPermissions.canDeleteRecords(TuristarAuth.currentRole) ? () => _delete(banner.id) : null,
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

  Future<void> _delete(String id) async {
    try {
      await SiteMediaStore.deleteBanner(id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(error)), backgroundColor: Colors.red.shade700),
      );
    }
  }
}

class _BannerTile extends StatelessWidget {
  const _BannerTile({super.key, required this.banner, required this.onEdit, this.onDelete});

  final SiteBanner banner;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: TuristarColors.line)),
      child: Row(
        children: [
          const Icon(Icons.drag_handle, color: TuristarColors.muted),
          const SizedBox(width: 10),
          if (banner.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(banner.imageUrl, width: 96, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
            )
          else
            Container(width: 96, height: 56, color: TuristarColors.line, child: const Icon(Icons.image_outlined)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(banner.title, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
                if (banner.subtitle.isNotEmpty) Text(banner.subtitle, style: const TextStyle(color: TuristarColors.muted, fontSize: 12)),
                Text(banner.active ? 'Ativo' : 'Inativo', style: TextStyle(color: banner.active ? TuristarColors.navy : TuristarColors.muted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, color: TuristarColors.orange)),
          if (onDelete != null) IconButton(onPressed: onDelete, icon: Icon(Icons.delete_outline, color: Colors.red.shade400)),
        ],
      ),
    );
  }
}

class _BannerEditorPage extends StatefulWidget {
  const _BannerEditorPage({this.banner});

  final SiteBanner? banner;

  @override
  State<_BannerEditorPage> createState() => _BannerEditorPageState();
}

class _BannerEditorPageState extends State<_BannerEditorPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController subtitleController;
  late final TextEditingController imageUrlController;
  late final TextEditingController ctaTextController;
  late final TextEditingController ctaLinkController;
  late bool active;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final banner = widget.banner;
    titleController = TextEditingController(text: banner?.title ?? '');
    subtitleController = TextEditingController(text: banner?.subtitle ?? '');
    imageUrlController = TextEditingController(text: banner?.imageUrl ?? '');
    ctaTextController = TextEditingController(text: banner?.ctaText ?? '');
    ctaLinkController = TextEditingController(text: banner?.ctaLink ?? '');
    active = banner?.active ?? true;
  }

  @override
  void dispose() {
    titleController.dispose();
    subtitleController.dispose();
    imageUrlController.dispose();
    ctaTextController.dispose();
    ctaLinkController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate() || isSaving) return;
    setState(() => isSaving = true);
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final banner = SiteBanner(
        id: widget.banner?.id ?? '',
        title: titleController.text.trim(),
        subtitle: subtitleController.text.trim(),
        imageUrl: imageUrlController.text.trim(),
        ctaText: ctaTextController.text.trim(),
        ctaLink: ctaLinkController.text.trim(),
        active: active,
        displayOrder: widget.banner?.displayOrder ?? 999,
        createdAt: widget.banner?.createdAt ?? now,
        updatedAt: now,
      );
      await SiteMediaStore.saveBanner(banner);
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: Text(widget.banner == null ? 'Novo banner' : 'Editar banner'),
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
                SwitchListTile(title: const Text('Ativo'), value: active, onChanged: (value) => setState(() => active = value)),
                TextFormField(controller: titleController, decoration: const InputDecoration(labelText: 'Titulo'), validator: _required),
                const SizedBox(height: 12),
                TextFormField(controller: subtitleController, decoration: const InputDecoration(labelText: 'Subtitulo')),
                const SizedBox(height: 12),
                TextFormField(controller: imageUrlController, decoration: const InputDecoration(labelText: 'URL da imagem'), validator: _required),
                const SizedBox(height: 12),
                ResponsiveFields(children: [
                  TextFormField(controller: ctaTextController, decoration: const InputDecoration(labelText: 'Botao CTA')),
                  TextFormField(controller: ctaLinkController, decoration: const InputDecoration(labelText: 'Link CTA')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Campo obrigatorio' : null;
}
