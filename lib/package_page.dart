import 'package:flutter/material.dart';

import 'main.dart';
import 'package_store.dart';
import 'seo_stub.dart' if (dart.library.js_interop) 'seo_web.dart' as page_seo;
import 'travel_request_store.dart';

Route<dynamic>? generateTuristarRoute(RouteSettings settings) {
  final name = settings.name ?? '/';
  if (name.startsWith('/pacotes/')) {
    final slug = name.replaceFirst('/pacotes/', '').split('?').first.trim();
    if (slug.isNotEmpty) {
      return MaterialPageRoute(
        settings: RouteSettings(name: '/pacotes/$slug'),
        builder: (_) => PackageDetailPage(slug: slug),
      );
    }
  }
  return MaterialPageRoute(
    settings: const RouteSettings(name: '/'),
    builder: (_) => const TuristarLandingPage(),
  );
}

void openPackagePage(BuildContext context, TravelPackage package) {
  final route = '/pacotes/${package.slug}';
  Navigator.of(context).pushNamed(route);
}

class PackageDetailPage extends StatefulWidget {
  const PackageDetailPage({super.key, required this.slug});

  final String slug;

  @override
  State<PackageDetailPage> createState() => _PackageDetailPageState();
}

class _PackageDetailPageState extends State<PackageDetailPage> {
  late Future<TravelPackage?> _packageFuture;
  late Future<List<TravelPackage>> _relatedFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _packageFuture = PackageStore.getBySlug(widget.slug);
    _relatedFuture = PackageStore.listPackages(activeOnly: true);
  }

  void _applySeo(TravelPackage package) {
    page_seo.updatePageSeo(
      title: package.resolvedSeoTitle,
      description: package.resolvedSeoDescription,
      imageUrl: package.imageUrl.startsWith('http') ? package.imageUrl : null,
      canonicalUrl: 'https://agenciaturistar.com.br${package.packagePath}',
    );
  }

  @override
  void dispose() {
    page_seo.resetPageSeo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return Scaffold(
      body: FutureBuilder<TravelPackage?>(
        future: _packageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: TuristarColors.orange));
          }

          final package = snapshot.data;
          if (package == null || !package.active) {
            return _PackageNotFound(onBack: () => Navigator.of(context).pop());
          }

          _applySeo(package);

          return SingleChildScrollView(
            child: Column(
              children: [
                TopNavigation(onServiceSelected: (_) {}),
                _PackageHero(package: package, mobile: mobile),
                LayoutShell(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: mobile ? 24 : 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.title,
                          style: TextStyle(
                            color: TuristarColors.navy,
                            fontSize: mobile ? 28 : 36,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          package.description,
                          style: const TextStyle(color: TuristarColors.muted, fontSize: 16, height: 1.45),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _InfoChip(icon: Icons.payments_outlined, label: package.priceLabel),
                            if (package.travelPeriod.isNotEmpty)
                              _InfoChip(icon: Icons.calendar_month_outlined, label: package.travelPeriod),
                            if (package.duration.isNotEmpty)
                              _InfoChip(icon: Icons.timelapse, label: package.duration),
                            if (package.hotelCategory.isNotEmpty)
                              _InfoChip(icon: Icons.hotel_outlined, label: package.hotelCategory),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (package.galleryImages.isNotEmpty) ...[
                          const Text('Galeria', style: TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 20)),
                          const SizedBox(height: 12),
                          _PackageGallery(images: [package.imageUrl, ...package.galleryImages.where((url) => url != package.imageUrl)]),
                          const SizedBox(height: 24),
                        ],
                        ResponsiveFields(
                          children: [
                            _ListCard(
                              title: 'Inclui',
                              icon: Icons.check_circle_outline,
                              iconColor: TuristarColors.green,
                              items: package.inclusions,
                            ),
                            _ListCard(
                              title: 'Nao inclui',
                              icon: Icons.cancel_outlined,
                              iconColor: Colors.red.shade400,
                              items: package.exclusions,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _PackageActionBar(
                          package: package,
                          onQuote: () => _openLeadForm(context, package),
                          onConsultant: () => Whatsapp.open(
                            context,
                            'Ola, gostaria de falar com um consultor sobre o pacote ${package.title}.',
                          ),
                          onWhatsApp: () => Whatsapp.open(
                            context,
                            Whatsapp.packageInterest(package.title),
                          ),
                        ),
                        const SizedBox(height: 32),
                        FutureBuilder<List<TravelPackage>>(
                          future: _relatedFuture,
                          builder: (context, relatedSnapshot) {
                            final related = (relatedSnapshot.data ?? [])
                                .where((item) => item.id != package.id && item.active)
                                .take(4)
                                .toList();
                            if (related.isEmpty) return const SizedBox.shrink();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionHeading(
                                  title: 'Voce tambem pode gostar',
                                  subtitle: 'Outros destinos selecionados pela Turistar',
                                ),
                                const SizedBox(height: 16),
                                ResponsiveCardGrid(
                                  minCardWidth: 220,
                                  children: [
                                    for (final item in related) PackageHomeCard(package: item),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const FooterSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openLeadForm(BuildContext context, TravelPackage package) async {
    requireAuth(
      context,
      () async {
        await showDialog<void>(
          context: context,
          builder: (context) => _PackageLeadDialog(package: package),
        );
      },
    );
  }
}

class PackageHomeCard extends StatelessWidget {
  const PackageHomeCard({super.key, required this.package});

  final TravelPackage package;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openPackagePage(context, package),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TuristarColors.line),
            boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 16, offset: Offset(0, 8))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 128,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PackageImage(url: package.imageUrl, fit: BoxFit.cover),
                    if (package.duration.isNotEmpty)
                      Positioned(
                        left: 12,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: TuristarColors.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            package.duration,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.destinationName,
                      style: const TextStyle(color: TuristarColors.navy, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      package.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: TuristarColors.muted, fontSize: 12, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      package.priceLabel,
                      style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w800, fontSize: 13),
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

class PackageImage extends StatelessWidget {
  const PackageImage({super.key, required this.url, this.fit = BoxFit.cover, this.height});

  final String url;
  final BoxFit fit;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final child = url.startsWith('assets/')
        ? Image.asset(
            url,
            fit: fit,
            errorBuilder: (_, __, ___) => _placeholder(),
          )
        : Image.network(
            url,
            fit: fit,
            errorBuilder: (_, __, ___) => _placeholder(),
          );

    if (height == null) return child;
    return SizedBox(height: height, width: double.infinity, child: child);
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFEAF2FF),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: TuristarColors.navy, size: 36),
    );
  }
}

class _PackageHero extends StatelessWidget {
  const _PackageHero({required this.package, required this.mobile});

  final TravelPackage package;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: mobile ? 260 : 360,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PackageImage(url: package.imageUrl, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.15), Colors.black.withOpacity(0.55)],
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black26),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.country,
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                ),
                Text(
                  package.destinationName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: mobile ? 30 : 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageGallery extends StatelessWidget {
  const _PackageGallery({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 180,
              child: PackageImage(url: images[index], fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: iconColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item, style: const TextStyle(color: TuristarColors.text, height: 1.35))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PackageActionBar extends StatelessWidget {
  const _PackageActionBar({
    required this.package,
    required this.onQuote,
    required this.onConsultant,
    required this.onWhatsApp,
  });

  final TravelPackage package;
  final VoidCallback onQuote;
  final VoidCallback onConsultant;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    final buttons = [
      Expanded(
        child: ElevatedButton(
          onPressed: onQuote,
          style: ElevatedButton.styleFrom(
            backgroundColor: TuristarColors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Solicitar orcamento', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton(
          onPressed: onConsultant,
          style: OutlinedButton.styleFrom(
            foregroundColor: TuristarColors.navy,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Falar com consultor', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: onWhatsApp,
          icon: const Icon(Icons.chat, size: 18),
          label: const Text('WhatsApp'),
          style: ElevatedButton.styleFrom(
            backgroundColor: TuristarColors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ];

    if (mobile) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onQuote,
              style: ElevatedButton.styleFrom(
                backgroundColor: TuristarColors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Solicitar orcamento', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onWhatsApp,
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: TuristarColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onConsultant,
              style: OutlinedButton.styleFrom(
                foregroundColor: TuristarColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Falar com consultor', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      );
    }

    return Row(children: buttons);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: TuristarColors.navy.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: TuristarColors.navy),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PackageNotFound extends StatelessWidget {
  const _PackageNotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.travel_explore, size: 48, color: TuristarColors.muted),
          const SizedBox(height: 12),
          const Text('Pacote nao encontrado', style: TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onBack, child: const Text('Voltar')),
        ],
      ),
    );
  }
}

class _PackageLeadDialog extends StatefulWidget {
  const _PackageLeadDialog({required this.package});

  final TravelPackage package;

  @override
  State<_PackageLeadDialog> createState() => _PackageLeadDialogState();
}

class _PackageLeadDialogState extends State<_PackageLeadDialog> {
  final formKey = GlobalKey<FormState>();
  final notesController = TextEditingController();
  DateTime? departureDate;
  int passengers = 2;
  bool isSubmitting = false;

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate() || departureDate == null || isSubmitting) return;
    setState(() => isSubmitting = true);
    try {
      await CustomerAreaStore.createTravelRequestFromPackage(
        packageId: widget.package.id,
        packageSlug: widget.package.slug,
        destinationName: widget.package.destinationName,
        packageTitle: widget.package.title,
        startingPrice: widget.package.startingPrice,
        departureDate: departureDate!.toIso8601String().split('T').first,
        passengers: passengers,
        notes: notesController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitacao enviada com sucesso!'), backgroundColor: TuristarColors.green),
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
    return AlertDialog(
      title: Text('Solicitar orcamento — ${widget.package.destinationName}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Data desejada: ${departureDate == null ? 'Selecionar' : _formatDate(departureDate!)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) setState(() => departureDate = picked);
                  },
                ),
              ),
              Row(
                children: [
                  const Text('Passageiros', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(onPressed: passengers > 1 ? () => setState(() => passengers--) : null, icon: const Icon(Icons.remove_circle_outline)),
                  Text('$passengers', style: const TextStyle(fontWeight: FontWeight.w900)),
                  IconButton(onPressed: passengers < 9 ? () => setState(() => passengers++) : null, icon: const Icon(Icons.add_circle_outline, color: TuristarColors.orange)),
                ],
              ),
              TextFormField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Observacoes (opcional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: Colors.white),
          child: isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Enviar'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
