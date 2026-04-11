class ApiEndpoints {
  ApiEndpoints._();

  static const apiPrefix = '/api/v1';

  // Auth
  static const authRequestOtp = '$apiPrefix/auth/request-otp';
  static const authVerifyOtp = '$apiPrefix/auth/verify-otp';
  static const authRefresh = '$apiPrefix/auth/refresh';
  static const authGoogle = '$apiPrefix/auth/google';
  static const authFacebook = '$apiPrefix/auth/facebook';
  static const authLogout = '$apiPrefix/auth/logout';

  // Profile
  static const profile = '$apiPrefix/profile/';
  static const profileLocation = '$apiPrefix/profile/location';

  // Catalog
  static const catalog = '$apiPrefix/catalog';
  static const pricingRules = '$apiPrefix/catalog/pricing-rules';

  // Orders
  static const orders = '$apiPrefix/orders';
  static String orderById(String id) => '$apiPrefix/orders/$id';

  // Subscription
  static const subscriptionPlans = '$apiPrefix/subscription/plans';
  static const subscriptionMine = '$apiPrefix/subscription/mine';

  // FAQ
  static const faqCategories = '$apiPrefix/faq/categories';
  static String faqArticle(String id) => '$apiPrefix/faq/$id';

  // Feedback
  static const feedback = '$apiPrefix/feedback';
}
