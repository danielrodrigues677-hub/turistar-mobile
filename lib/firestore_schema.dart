/// Firestore collections and role constants for Sprint 1 foundation.
class FirestoreCollections {
  const FirestoreCollections._();

  static const users = 'users';
  static const travelRequests = 'travel_requests';
  static const quotes = 'quotes';
  static const bookings = 'bookings';
  static const packages = 'packages';
  static const featuredPackages = 'featured_packages';
  static const banners = 'banners';
  static const destinations = 'destinations';
  static const testimonials = 'testimonials';
  static const offers = 'offers';
  static const settings = 'settings';
}

/// Application roles. Default for new accounts is [customer].
/// [agent] is displayed as Consultor in the admin panel.
class TuristarRole {
  const TuristarRole._();

  static const customer = 'customer';
  static const agent = 'agent';
  static const admin = 'admin';
  static const operacional = 'operacional';

  static const all = [customer, agent, admin, operacional];

  static const staff = [admin, agent, operacional];

  static bool isValid(String? value) => value != null && all.contains(value);
}

class PackageCategory {
  const PackageCategory._();

  static const nacional = 'Nacional';
  static const internacional = 'Internacional';
  static const cruzeiro = 'Cruzeiro';
  static const promocao = 'Promocao';

  static const all = [nacional, internacional, cruzeiro, promocao];

  static String label(String value) {
    if (value == promocao) return 'Promocao';
    return value;
  }
}

/// Required fields per collection (documentation + validation helpers).
class FirestoreDocumentFields {
  const FirestoreDocumentFields._();

  static const userProfile = ['email', 'name', 'phone', 'role', 'createdAt', 'updatedAt', 'lastAccessAt', 'tripsCount'];
  static const travelRequest = [
    'userId',
    'userEmail',
    'origin',
    'destination',
    'departureDate',
    'passengers',
    'status',
    'createdAt',
    'updatedAt',
    'name',
    'phone',
    'adults',
    'children',
    'budget',
    'notes',
    'consultantEmail',
    'timelineJson',
  ];
  static const quote = ['userId', 'status', 'createdAt', 'updatedAt'];
  static const booking = ['userId', 'status', 'createdAt', 'updatedAt'];
  static const packageDoc = [
    'title',
    'destinationName',
    'country',
    'city',
    'shortDescription',
    'description',
    'imageUrl',
    'galleryJson',
    'startingPrice',
    'promotionalText',
    'inclusionsJson',
    'exclusionsJson',
    'travelPeriod',
    'duration',
    'nights',
    'hotelCategory',
    'category',
    'featured',
    'active',
    'displayOrder',
    'slug',
    'seoTitle',
    'seoDescription',
    'createdAt',
    'updatedAt',
  ];
  static const featuredPackage = [
    'packageId',
    'title',
    'imageUrl',
    'price',
    'promotionalText',
    'active',
    'displayOrder',
    'createdAt',
    'updatedAt',
  ];
  static const offer = ['title', 'active', 'createdAt', 'updatedAt'];
  static const banner = [
    'title',
    'subtitle',
    'imageUrl',
    'ctaText',
    'ctaLink',
    'active',
    'displayOrder',
    'createdAt',
    'updatedAt',
  ];
  static const destination = ['name', 'country', 'imageUrl', 'description', 'active', 'displayOrder', 'createdAt', 'updatedAt'];
  static const testimonial = ['authorName', 'quote', 'imageUrl', 'rating', 'active', 'displayOrder', 'createdAt', 'updatedAt'];
  static const settingsDoc = ['key', 'value', 'updatedAt'];
}
