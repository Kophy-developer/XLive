import 'package:circle_flags/circle_flags.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'auth_constants.dart';
import 'auth_widgets.dart';

Country authDefaultCountry() {
  final s = CountryService();
  return s.findByCode('NG') ?? s.getAll().first;
}

void showAuthCountryPicker(BuildContext context, ValueChanged<Country> onSelect) {
  final h = MediaQuery.sizeOf(context).height;
  showCountryPicker(
    context: context,
    showPhoneCode: true,
    showSearch: true,
    useSafeArea: true,
    customFlagBuilder: (c) => CircleFlag(c.countryCode.toLowerCase(), size: 24),
    countryListTheme: CountryListThemeData(
      flagSize: 24,
      backgroundColor: Colors.white,
      textStyle: const TextStyle(fontSize: 16, color: AuthColors.black),
      bottomSheetHeight: h * 0.88,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      inputDecoration: InputDecoration(
        hintText: 'Search country or code',
        hintStyle: TextStyle(color: AuthColors.grey.withValues(alpha: 0.8)),
        prefixIcon: const Icon(Icons.search_rounded, color: AuthColors.grey),
        filled: true,
        fillColor: AuthColors.chipBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    onSelect: onSelect,
  );
}

class AuthCountryCodeField extends StatelessWidget {
  const AuthCountryCodeField({
    super.key,
    required this.country,
    required this.onTap,
    this.width = 128,
  });

  final Country country;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: InputDecorator(
            decoration: authInputDecoration(hintText: ''),
            child: Row(
              children: [
                ClipOval(
                  child: CircleFlag(
                    country.countryCode.toLowerCase(),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '+${country.phoneCode}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AuthColors.black),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: AuthColors.grey.withValues(alpha: 0.85), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
