/// كل النصوص الظاهرة في تطبيق الدليفيري.
///
/// عدّل النصوص من هذا الملف فقط. التطبيق يقرأ القيم من هنا،
/// فتغيير النص هنا يغيّره في الشاشة المرتبطة به.
abstract final class AppTexts {
  const AppTexts._();
}

/// الاسم والنصوص الثابتة للعلامة.
abstract final class BrandTexts {
  static const appName = 'Yalla Delivery';
  static const splashFirst = 'يلا ';
  static const splashSecond = 'دليفري';
  static const splashTagline = 'استلم، تتبّع وسلّم الطلبات بسهولة';
  static const courierFallbackName = 'طيار Yalla Delivery';
}

/// نصوص متكررة في أكثر من شاشة.
abstract final class CommonTexts {
  static const retry = 'إعادة المحاولة';
  static const retrying = 'جاري المحاولة...';
  static const cancel = 'إلغاء';
  static const confirm = 'تأكيد';
  static const confirming = 'جاري التأكيد...';
  static const back = 'رجوع';
  static const today = 'اليوم';
  static const unspecified = 'غير محدد';
  static const unavailable = 'غير متاح';
  static const signIn = 'تسجيل الدخول';
  static const connectionFailed = 'تعذر الاتصال. حاول مرة أخرى.';
  static const serverConnectionFailed = 'تعذر الاتصال بالخادم. حاول مرة أخرى.';
  static const listSeparator = '، ';

  static String copied(String label) => 'تم نسخ $label';
}

/// صيغ الوقت النسبية والتواريخ.
abstract final class TimeTexts {
  static const now = 'الآن';
  static const oneMinuteAgo = 'منذ دقيقة';
  static const twoMinutesAgo = 'منذ دقيقتين';
  static const oneHourAgo = 'منذ ساعة';
  static const twoHoursAgo = 'منذ ساعتين';
  static const oneDayAgo = 'منذ يوم';
  static const twoDaysAgo = 'منذ يومين';

  static const january = 'يناير';
  static const february = 'فبراير';
  static const march = 'مارس';
  static const april = 'أبريل';
  static const may = 'مايو';
  static const june = 'يونيو';
  static const july = 'يوليو';
  static const august = 'أغسطس';
  static const september = 'سبتمبر';
  static const october = 'أكتوبر';
  static const november = 'نوفمبر';
  static const december = 'ديسمبر';

  static const months = <String>[
    january,
    february,
    march,
    april,
    may,
    june,
    july,
    august,
    september,
    october,
    november,
    december,
  ];

  static String minutesAgo(int count) => 'منذ $count دقائق';
  static String minutesAgoSingular(int count) => 'منذ $count دقيقة';
  static String hoursAgo(int count) => 'منذ $count ساعات';
  static String hoursAgoSingular(int count) => 'منذ $count ساعة';
  static String daysAgo(int count) => 'منذ $count أيام';
  static String daysAgoSingular(int count) => 'منذ $count يوم';

  static String notificationMinutesAgo(int count) => 'منذ $count دقيقة';
  static String notificationHoursAgo(int count) => 'منذ $count ساعة';
  static String notificationDaysAgo(int count) => 'منذ $count يوم';

  static String minutes(int count) => '$count دقيقة';
  static String minuteRange(int from, int to) => '$from - $to دقيقة';
  static String days(int count) => '$count يوم';
}

/// العملة.
abstract final class CurrencyTexts {
  static String pounds(String amount) => '$amount جنيه';
}

/// رسائل الجلسة وتسجيل الدخول والأخطاء العامة.
abstract final class AuthTexts {
  static const connectionTimeout =
      'انتهت مهلة الاتصال. تحقق من الإنترنت وحاول مرة أخرى.';
  static const accountNotActivated = 'الحساب لم يتم تفعيله بعد.';
  static const routeNotFound = 'المسار غير موجود. تأكد من إعداد رابط الخادم.';
  static const accountDisabled = 'تم إيقاف حسابك. تواصل مع الدعم.';
  static const sessionEnded = 'انتهت الجلسة.';
  static const sessionEndedTitle = 'انتهت الجلسة';
  static const sessionEndedHint =
      'سجّل دخول تاني عشان تكمل. «افتكرني» بتحافظ على تسجيل دخولك بعد قفل التطبيق.';
  static const rateLimited = 'طلبات كتير في وقت قصير. استنى شوية وحاول تاني.';
  static const invalidCredentials = 'الإيميل أو كلمة السر غير صحيحين.';
  static const loginFailed = 'تعذر تسجيل الدخول.';
  static const incompleteLogin = 'استجابة تسجيل الدخول غير مكتملة.';
  static const loadDataFailed = 'تعذر تحميل البيانات.';
  static const sendRequestFailed = 'تعذر إرسال الطلب.';
  static const updateOrderFailed = 'تعذر تحديث الطلب.';
  static const deleteItemFailed = 'تعذر حذف العنصر.';
  static const confirmDeliveryFailed = 'تعذر تأكيد التسليم.';
  static const loadImageFailed = 'تعذر تحميل الصورة.';
  static const loadAccountFailed = 'تعذر تحميل بيانات الحساب.';
  static const readAccountFailed = 'تعذر قراءة بيانات الحساب.';
  static const sessionChanged = 'تغيرت الجلسة. أعد فتح الطلب من حسابك الحالي.';
  static const noSavedSession = 'لا توجد جلسة محفوظة.';
  static const passwordChanged = 'تم تغيير كلمة المرور.';
  static const passwordChangedTitle = 'تم تغيير كلمة المرور';
  static const passwordChangedMessage =
      'تم تغيير كلمة مرور حسابك. سجّل الدخول بكلمة المرور الجديدة للمتابعة.';
  static const incompleteOrderResponse =
      'استجابة الطلب غير مكتملة. حاول مرة أخرى.';
  static const readCourierAccountFailed = 'تعذر قراءة بيانات حساب الطيار.';
  static const notCourierAccount = 'هذا الحساب ليس حساب طيار.';
  static const actionFailed = 'تعذر تنفيذ العملية. حاول مرة أخرى.';
}

/// تسجيل الدخول.
abstract final class LoginTexts {
  static const welcome = 'أهلاً يا كابتن';
  static const identifierHint = 'موبايل / إيميل / اسم مستخدم';
  static const password = 'كلمة المرور';
  static const showPassword = 'إظهار كلمة المرور';
  static const hidePassword = 'إخفاء كلمة المرور';
  static const rememberMe = 'تذكرني';
  static const support = 'الدعم الفني';
  static const identifierRequired = 'اكتب رقم الموبايل أو الإيميل';
  static const identifierInvalid = 'اكتب إيميل صحيح أو رقم موبايل صحيح';
  static const passwordRequired = 'اكتب كلمة المرور';
  static const whatsAppUnavailable = 'تعذر فتح واتساب على هذا الجهاز.';
}

/// الشريط السفلي والتنقل.
abstract final class ShellTexts {
  static const orders = 'الطلبات';
  static const delivered = 'المسلّمة';
  static const account = 'حسابي';
  static const orderUnassigned = 'لم يعد هذا الطلب معينًا لك.';
  static const orderUnavailable = 'لم يعد هذا الطلب متاحًا لك.';
}

/// قائمة الطلبات النشطة.
abstract final class OrdersTexts {
  static const title = 'طلبات التوصيل';
  static const subtitle = 'الطلبات المطلوب تسليمها اليوم';
  static const active = 'نشط';
  static const value = 'القيمة';
  static const empty = 'لا توجد طلبات نشطة حاليًا';
  static const cash = 'كاش';
  static const card = 'بطاقة';
  static const wallet = 'محفظة';
  static const online = 'أونلاين';

  static String markets(int count) => '$count محلات';
  static String products(int count) => '$count منتج';
}

/// حالات الطلب.
abstract final class OrderStatusTexts {
  static const pending = 'قيد الانتظار';
  static const confirmed = 'مؤكد';
  static const assigned = 'مطلوب الاستلام';
  static const pickedUp = 'تم الاستلام';
  static const delivered = 'تم التسليم';
  static const failedDelivery = 'تعذر التوصيل';
  static const cancelled = 'ملغي';
  static const unknown = 'الحالة غير معروفة';
}

/// القيم الافتراضية لبيانات الطلب.
abstract final class OrderFallbackTexts {
  static const customer = 'عميل';
  static const addressUnspecified = 'العنوان غير محدد';
  static const marketUnspecified = 'المحل غير محدد';
  static const product = 'منتج';
  static const offer = 'عرض';

  static String markets(int count) => '$count محلات';
}

/// تفاصيل الطلب.
abstract final class OrderDetailsTexts {
  static const title = 'تفاصيل الطلب';
  static const customerData = 'بيانات العميل';
  static const addressName = 'اسم العنوان';
  static const area = 'المنطقة';
  static const city = 'المدينة';
  static const market = 'المحل';
  static const marketCount = 'عدد المحلات';
  static const customerNote = 'ملاحظة العميل';
  static const addressInstructions = 'تعليمات العنوان';
  static const addedOffers = 'العروض المضافة';
  static const contact = 'تواصل';
  static const map = 'الخريطة';
  static const orderCancelled = 'تم إلغاء هذا الطلب.';
  static const callsUnsupported = 'المكالمات غير مدعومة على هذا الجهاز.';
  static const mapUnavailable = 'تعذر فتح الخريطة على هذا الجهاز.';
  static const pickupRecorded = 'تم تسجيل الاستلام بنجاح.';
  static const marketPickupRecorded = 'تم تسجيل استلام منتجات المحل.';
  static const deliveryRecorded = 'تم تسجيل التسليم بنجاح.';
  static const summaryTitle = 'ملخص الطلب والدفع';
  static const paymentMethod = 'طريقة الدفع';
  static const shippingCompany = 'شركة الشحن';
  static const pricingType = 'نوع التسعير';
  static const fixedAreaPrice = 'سعر منطقة ثابت';
  static const orderDeliveryPrice = 'سعر توصيل محدد للطلب';
  static const products = 'المنتجات';
  static const delivery = 'التوصيل';
  static const discount = 'الخصم';
  static const multiMarketFee = 'رسوم تعدد المحلات';
  static const total = 'الإجمالي';
  static const expectedDuration = 'المدة المتوقعة';
  static const orderTime = 'وقت الطلب';
  static const cashOnDelivery = 'الدفع عند الاستلام';
  static const electronicWallet = 'محفظة إلكترونية';
  static const pickupAllMarketsFirst = 'استلم منتجات كل المحلات أولًا';
  static const confirmPickup = 'تأكيد استلام الطلب';
  static const deliveryTime = 'وقت التسليم';
  static const customerPhoto = 'صورة العميل';
  static const address = 'العنوان';
  static const addressCopied = 'تم نسخ العنوان';
  static const copyAddress = 'نسخ العنوان';
  static const noProducts = 'لا توجد منتجات في هذا الطلب.';
  static const noMarketProducts = 'لا توجد منتجات لهذا المحل.';
  static const confirmMarketPickup = 'تأكيد استلام منتجات المحل';
  static const attachedPhoto = 'صورة مرفقة بالطلب';
  static const customerPhotoDescription =
      'الصورة التي أرسلها العميل مع تفاصيل الطلب.';
  static const customerOrderPhoto = 'صورة الطلب المرسلة من العميل';
  static const deliveryProof = 'إثبات التسليم';
  static const note = 'ملاحظة';
  static const noUploadedPhoto = 'لا توجد صورة مرفوعة.';
  static const deliveryProofPhoto = 'صورة إثبات التسليم';
  static const contactCustomer = 'تواصل مع العميل';
  static const whatsAppChat = 'شات واتساب';
  static const whatsAppChatHint = 'فتح محادثة واتساب مع العميل';
  static const phoneCall = 'مكالمة هاتفية';
  static const phoneCallHint = 'فتح تطبيق الهاتف للاتصال بالعميل';

  static String pickedUpMarkets(int pickedUp, int total) =>
      'تم استلام منتجات $pickedUp من $total محلات';

  static String marketLine(String name) => 'المحل: $name';

  static String additions(String value) => 'الإضافات: $value';

  static String sku(String sku) => 'SKU: $sku';
}

/// تأكيد التسليم.
abstract final class DeliveryConfirmationTexts {
  static const title = 'تأكيد التسليم';
  static const noteHint = 'ملاحظة التسليم (اختياري)';
  static const captureProof = 'التقاط صورة إثبات التسليم';
  static const retakeProof = 'تم التقاط الصورة — إعادة الالتقاط';
  static const deletePhoto = 'حذف الصورة';
  static const unreadableProof = 'تعذر قراءة صورة إثبات التسليم.';
  static const cameraUnavailable =
      'تعذر فتح الكاميرا. تحقق من الإذن وحاول مرة أخرى.';

  static String prompt(Object orderId) =>
      'أضف صورة أو ملاحظة تسليم للطلب $orderId.';
}

/// سجل الطلبات المسلّمة وملخص الفترة.
abstract final class DeliveredTexts {
  static const title = 'المسلّمة';
  static const subtitle = 'الطلبات المسلّمة';
  static const loading = 'جارٍ التحميل...';
  static const loadMore = 'تحميل المزيد';
  static const deliveredOrder = 'طلب مسلّم';
  static const totalValue = 'إجمالي القيمة';
  static const deliveryFees = 'رسوم التوصيل';
  static const empty = 'لسه مفيش طلبات مسلّمة';
  static const deliveryCount = 'عدد التسليم';
  static const value = 'القيمة';
  static const emptyPeriod = 'مفيش تسليم في الفترة دي';
  static const pickDate = 'اختيار التاريخ';
  static const month = 'الشهر';
  static const year = 'السنة';
  static const from = 'من';
  static const to = 'إلى';
  static const reset = 'إعادة الضبط';
  static const apply = 'تطبيق';
  static const selectedDays = 'عدد الأيام المحددة';
  static const summaryTitle = 'إجمالي التسليم';
  static const summarySubtitle = 'ملخص الطلبات المسلّمة حسب الفترة';
  static const today = 'انهارده';
  static const yesterday = 'امبارح';
  static const thisWeek = 'الأسبوع ده';
  static const thisMonth = 'الشهر ده';
  static const custom = 'مخصص';
}

/// الإشعارات داخل التطبيق.
abstract final class NotificationTexts {
  static const title = 'الإشعارات';
  static const subtitle = 'تنبيهات الطلبات وحالة التسليم';
  static const markAllRead = 'تعليم الكل كمقروء';
  static const markedRead = 'تم تعليم الإشعارات كمقروءة';
  static const deleted = 'تم حذف الإشعار';
  static const orderUnavailable = 'هذا الطلب لم يعد متاحا لك.';
  static const allRead = 'كل الإشعارات مقروءة';
  static const details = 'تفاصيل الإشعار';
  static const status = 'الحالة';
  static const resolved = 'تم الحل';
  static const needsFollowUp = 'يتطلب متابعة';
  static const openOrder = 'فتح الطلب';
  static const loadFailed = 'تعذر تحميل الإشعارات';
  static const empty = 'لا توجد إشعارات حاليا';
  static const emptyHint = 'أي تنبيه جديد بخصوص الطلبات سيظهر هنا.';
  static const assignedTitle = 'تم إسناد طلب جديد';
  static const fallbackTitle = 'إشعار';
  static const assignedWithoutNumber = 'تم إسناد طلب جديد إليك.';
  static const fallbackMessage = 'لديك إشعار جديد.';
  static const loadFailedRetry = 'تعذر تحميل الإشعارات. حاول مرة أخرى.';

  static String unread(int count) => '$count إشعار غير مقروء';

  static String total(int count) => 'إجمالي $count إشعار.';

  static String assigned(String orderNumber) =>
      'تم إسناد الطلب #$orderNumber إليك.';
}

/// حساب الطيار والإعدادات.
abstract final class ProfileTexts {
  static const allCities = 'كل المدن';
  static const unlimitedOrders = 'غير محدود';
  static const title = 'حساب الطيار';
  static const subtitle = 'بيانات التشغيل والحساب';
  static const activeOrders = 'طلبات نشطة';
  static const deliveredOrders = 'طلبات مسلّمة';
  static const operationData = 'بيانات تشغيل الطيار';
  static const serviceCity = 'مدينة الخدمة';
  static const serviceCityUnspecified = 'مدينة الخدمة غير محددة';
  static const receivingStatus = 'حالة استقبال الطلبات';
  static const vehicleType = 'نوع المركبة';
  static const plateNumber = 'رقم اللوحة';
  static const maxActiveOrders = 'الحد الأقصى للطلبات النشطة';
  static const appSettings = 'إعدادات التطبيق';
  static const logout = 'تسجيل الخروج';
  static const logoutConfirm = 'متأكد إنك عايز تسجل خروج؟';
  static const loadFailed = 'تعذر تحميل بيانات حساب الطيار';
  static const refresh = 'تحديث';
  static const incompleteProfile = 'بيانات تشغيل الطيار غير مكتملة.';
  static const contactUnspecified = 'بيانات الاتصال غير محددة';
  static const courierPhoto = 'صورة الطيار';
  static const available = 'متاح لاستقبال الطلبات';
  static const unavailableNow = 'غير متاح حاليًا';
  static const loadFailedRetry =
      'تعذر تحميل بيانات حساب الطيار. حاول مرة أخرى.';
  static const theme = 'ثيم التطبيق';
  static const themeUpdated = 'تم تحديث الثيم';
  static const themeSystem = 'النظام';
  static const themeLight = 'فاتح';
  static const themeDark = 'داكن';
  static const themeSystemHint = 'استخدم إعدادات الجهاز.';
  static const themeLightHint = 'استخدم الثيم الفاتح دائمًا.';
  static const themeDarkHint = 'استخدم الثيم الداكن دائمًا.';
}

/// الاتصال والإشعارات المحلية.
abstract final class SystemTexts {
  static const offline =
      'لا يوجد اتصال بالإنترنت. تحقق من الشبكة لإكمال التحديثات.';
  static const ordersChannel = 'طلبات التوصيل';
  static const accountChannel = 'تحديثات الحساب';
  static const courierChannel = 'تحديثات الطيار';
  static const newDelivery = 'طلب توصيل جديد';
  static const orderWithdrawn = 'تم سحب طلب';
  static const orderCancelled = 'تم إلغاء طلب';
  static const accountRestored = 'تم استعادة حسابك';
  static const accountUpdated = 'تم تحديث بيانات حسابك';
  static const availabilityUpdated = 'تحديث حالة استقبال الطلبات';
  static const marketUpdate = 'تحديث من يلا ماركت';
  static const courierRestored =
      'تم استعادة حساب الطيار بواسطة فريق دعم يلا ماركت.';
  static const courierUpdated = 'تم تحديث بيانات الطيار.';
  static const availabilityStatusUpdated = 'تم تحديث حالة استقبال الطلبات.';
  static const courierAccountUpdated = 'تم تحديث بيانات حساب الطيار.';

  static String assignedBody(Object number) =>
      'تم تعيين الطلب #$number لك. اضغط لعرض التفاصيل.';

  static String withdrawnBody(Object number) =>
      'تم سحب الطلب #$number من قائمة مهامك.';

  static String cancelledBody(Object number) => 'تم إلغاء الطلب #$number.';
}
