/// Firestore collections and role constants for Sprint 1 foundation.
class FirestoreCollections {
  const FirestoreCollections._();

  static const users = 'users';
  static const travelRequests = 'travel_requests';
  static const quotes = 'quotes';
  static const bookings = 'bookings';
  static const packages = 'packages';
  static const offers = 'offers';
}

/// Application roles. Default for new accounts is [customer].
class TuristarRole {
  const TuristarRole._();

  static const customer = 'customer';
  static const agent = 'agent';
  static const admin = 'admin';

  static const all = [customer, agent, admin];

  static bool isValid(String? value) => value != null && all.contains(value);
}

/// Required fields per collection (documentation + validation helpers).
class FirestoreDocumentFields {
  const FirestoreDocumentFields._();

  static const userProfile = ['email', 'name', 'phone', 'role', 'createdAt', 'updatedAt'];
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
    'timelineJson',
  ];
  static const quote = ['userId', 'status', 'createdAt', 'updatedAt'];
  static const booking = ['userId', 'status', 'createdAt', 'updatedAt'];
  static const packageDoc = [
    'title',
    'destinationName',
    'country',
    'imageUrl',
    'galleryJson',
    'startingPrice',
    'description',
    'inclusionsJson',
    'exclusionsJson',
    'travelPeriod',
    'duration',
    'hotelCategory',
    'featured',
    'active',
    'displayOrder',
    'slug',
    'seoTitle',
    'seoDescription',
    'createdAt',
    'updatedAt',
  ];
  static const offer = ['title', 'active', 'createdAt', 'updatedAt'];
}
