// lib/screens/passenger_home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/passenger/trip_card.dart';
import '../../widgets/passenger/travel_prayer_card.dart';
import '../../widgets/passenger/trip_filter_sheet.dart';
import '../../widgets/shared/custom_button.dart';
import '../../widgets/shared/app_scaffold.dart';
import '../../models/trip.dart';
import '../../models/filter_result.dart'; // استخدم النموذج المركزي هنا
import '../../providers/trip_provider.dart';
import '../../utils/app_localizations.dart';
import '../available_trips_screen.dart' hide TripProvider;
import '../my_bookings_screen.dart';
import 'passenger_calendar_screen.dart';
import '../trip_details_screen.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  String? _selectedTripCategory;
  String? _selectedDestination;

  final _formKey = GlobalKey<FormState>();

  final Color _primaryBlue = const Color(0xFF1E70B8);
  final Color _accentTeal = const Color(0xFF17A5A3);

  final List<String> _tripCategories = ['داخلية', 'خارجية'];
  final Map<String, List<String>> _destinations = {
    'داخلية': [
      'صنعاء','عدن','تعز','حضرموت','إب','الحديدة','ذمار','مأرب',
      'شبوة','المهرة','أبين','لحج','البيضاء','عمران','صعدة','الجوف',
      'حجة','المحويت','ريمة','الضالع','سقطرى'
    ],
    'خارجية': [
      'الرياض','جدة','مكة','المدينة المنورة','الدمام','الخبر','الطائف','أبها',
      'مسقط','صلالة','صحار',
      'دبي','أبوظبي','الشارقة','العين',
    ],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().fetchAvailableTrips();
    });
  }

  Future<void> _launchSupport() async {
    final Uri url = Uri.parse("https://wa.me/967770000000");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t(L10nKeys.error))),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t(L10nKeys.error))),
      );
    }
  }

  /// يفتح ورقة الفلتر ويطبق النتيجة على الحقول المحلية
  Future<void> _openFilterSheet() async {
    // حدد النوع هنا صراحةً لتضمن أن result من نوع FilterResult أو null
    final FilterResult? result = await showModalBottomSheet<FilterResult?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TripFilterSheet(
        internalDestinations: _destinations['داخلية']!,
        externalDestinations: _destinations['خارجية']!,
      ),
    );

    if (result == null) return;

    // الآن result هو FilterResult من النموذج المركزي، لا تعارض في الأنواع
    // طبق الفلتر محليًا عبر Provider (إن كانت الدالة متوفرة)
    try {
      context.read<TripProvider>().filterAvailableTrips(filter: result);
    } catch (_) {}

    // استخدم الحقول بأمان
    final String? dir = result.direction;
    final bool? cat = result.onlyDirect;
    final String? from = result.from;
    final String? to = result.to;


    setState(() {
      if (dir == 'inbound') {
        _selectedTripCategory = 'داخلية';
        _selectedDestination = to ?? _selectedDestination;
      } else if (dir == 'outbound') {
        _selectedTripCategory = 'خارجية';
        _selectedDestination = to ?? _selectedDestination;
      } else {
        _selectedTripCategory = (cat ?? _selectedTripCategory) as String?;
        _selectedDestination = to ?? from ?? _selectedDestination;
      }
    });

    if (_selectedTripCategory != null && _selectedDestination != null) {
      _searchTrips();
    }
  }

  void _searchTrips() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvailableTripsScreen(
          destination: _selectedDestination!,
          tripCategory: _selectedTripCategory!,
        ),
      ),
    );
  }

  Future<bool?> _confirmSignOutDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تسجيل الخروج', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد أنك تريد تسجيل الخروج الآن؟', style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.t(L10nKeys.cancel)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue),
            child: Text(context.t(L10nKeys.confirm)),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await _confirmSignOutDialog();
    if (confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    final overlay = OverlayEntry(
      builder: (_) => Material(
        color: Colors.black.withOpacity(0.25),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
    Overlay.of(context).insert(overlay);

    try {
      await FirebaseAuth.instance.signOut();
      try {
        final provider = context.read<TripProvider>();
        provider.stopWatchingAvailableTrips();
        provider.stopWatchingDriverTrips();
      } catch (_) {}
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('فشل تسجيل الخروج. حاول مرة أخرى.')));
    } finally {
      overlay.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.t(L10nKeys.home),
      showSettingsButton: true,
      body: RefreshIndicator(
        onRefresh: () => context.read<TripProvider>().fetchAvailableTrips(forceRefresh: true),
        color: _primaryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeHeader(context),
              const SizedBox(height: 20),
              _buildSearchCard(context),
              const SizedBox(height: 24),
              _buildTravelMessages(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildSectionHeader(context.t(L10nKeys.createTrip)),
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              const _SuggestionsSection(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t(L10nKeys.appTitle), style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.black54)),
        Text(
          context.t(L10nKeys.search),
          style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.bold, color: _primaryBlue),
        ),
      ],
    );
  }

  Widget _buildSearchCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_primaryBlue, _accentTeal], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: _primaryBlue.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Text(context.t('where_to'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildWhiteDropdown(
                    context,
                    context.t('trip_category'),
                    Icons.map_outlined,
                    _tripCategories,
                    _selectedTripCategory,
                        (val) {
                      setState(() {
                        _selectedTripCategory = val;
                        _selectedDestination = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: IconButton(
                    tooltip: context.t('filter'),
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                    onPressed: _openFilterSheet,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildWhiteDropdown(
              context,
              context.t('destination'),
              Icons.location_on_outlined,
              _selectedTripCategory != null ? _destinations[_selectedTripCategory] ?? [] : [],
              _selectedDestination,
                  (val) => setState(() => _selectedDestination = val),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: context.t('search'),
                    compact: false,
                    onPressed: (_selectedTripCategory != null && _selectedDestination != null) ? _searchTrips : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelMessages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('💡 ${context.t(L10nKeys.notifications)}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              TravelPrayerCard(
                title: 'دعاء السفر',
                content: 'سبحان الذي سخر لنا هذا وما كنا له مقرنين...',
                icon: Icons.auto_stories,
                color: Colors.amber,
              ),
              TravelPrayerCard(
                title: 'نصيحة أمان',
                content: 'تأكد من حمل وثائق الهوية الأصلية قبل التوجه للموقف.',
                icon: Icons.gpp_good,
                color: Colors.blue,
              ),
              TravelPrayerCard(
                title: 'حالة الطريق',
                content: 'طريق هيجة العبد مفتوح حالياً للمسافرين.',
                icon: Icons.add_road,
                color: Colors.green,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _buildActionItem(Icons.history, context.t(L10nKeys.myBookings), Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen()))),
        const SizedBox(width: 12),
        _buildActionItem(Icons.calendar_month, context.t('calendar'), Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerCalendarScreen()))),
        const SizedBox(width: 12),
        _buildActionItem(Icons.support_agent, context.t('support'), Colors.green, _launchSupport),
        const SizedBox(width: 12),
        _buildActionItem(Icons.logout, 'تسجيل الخروج', Colors.red, _signOut),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }

  Widget _buildWhiteDropdown(
      BuildContext context,
      String hint,
      IconData icon,
      List<String> items,
      String? value,
      Function(String?) onChanged,
      ) {
    final Color primary = _primaryBlue;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonFormField<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey)),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)))).toList(),
          onChanged: onChanged,
          validator: (val) => val == null ? 'مطلوب' : null,
          decoration: InputDecoration(
            icon: Icon(icon, color: primary, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    );
  }
}

/// فصل قسم الاقتراحات لتقليل إعادة البناء
class _SuggestionsSection extends StatelessWidget {
  const _SuggestionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator());
        final errorText = provider.errorMessage ?? provider.error;
        if (errorText != null) {
          return Center(
            child: Column(
              children: [
                Text(errorText, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                CustomButton(text: context.t(L10nKeys.confirm), compact: true, onPressed: () => provider.fetchAvailableTrips()),
              ],
            ),
          );
        }
        if (provider.availableTrips.isEmpty) {
          return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(context.t(L10nKeys.noTrips))));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.availableTrips.length > 3 ? 3 : provider.availableTrips.length,
          itemBuilder: (context, index) {
            final trip = provider.availableTrips[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TripCard(
                trip: trip,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip))),
              ),
            );
          },
        );
      },
    );
  }
}
