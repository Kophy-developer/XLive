import 'package:flutter/material.dart';

const _sheetTopRadius = 22.0;
const _grabber = Color(0xFFE0E0E0);
const _closeBg = Color(0xFFF2F2F2);
const _submitPurple = Color(0xFF8E24ED);
const _legalUpdated = 'Last updated: June 27, 2026';

Widget _legalIntro(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A), height: 1.55)),
    );

Widget _legalMeta(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF8A8A8E), fontWeight: FontWeight.w600)),
    );

Widget _legalHeading(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black, height: 1.35)),
    );

Widget _legalParagraph(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: const TextStyle(fontSize: 14.5, color: Color(0xFF1A1A1A), height: 1.5)),
    );

Widget _legalBullet(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: 10),
            child: SizedBox(
              width: 5,
              height: 5,
              child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF8A2DDC), shape: BoxShape.circle)),
            ),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14.5, color: Color(0xFF1A1A1A), height: 1.5))),
        ],
      ),
    );

void showTermsOfUseSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, scrollController) => _LegalSheetFrame(
        title: 'Terms of Use',
        scrollController: scrollController,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legalMeta(_legalUpdated),
            _legalIntro(
              'Welcome to Xlive. These Terms of Use ("Terms") are a binding agreement between you and Xlive Ltd ("Xlive", "we", "us") and govern your access to and use of the Xlive app, including livestreaming, clips, chats, calls, gifts, and creator tools (the "Services"). By creating an account or using the Services, you agree to these Terms.',
            ),
            _legalHeading('1. Eligibility'),
            _legalParagraph(
              'You must be at least 13 years old to use Xlive. If you are under the age of majority where you live, you may only use Xlive with the consent of a parent or guardian. You must be at least 18 years old to buy or sell virtual items, receive payouts, or access creator monetization.',
            ),
            _legalHeading('2. Your account'),
            _legalParagraph(
              'You are responsible for your account, for keeping your login credentials secure, and for all activity that happens under it. Provide accurate information and keep it up to date. Notify us immediately of any unauthorized use of your account.',
            ),
            _legalHeading('3. Acceptable use'),
            _legalParagraph('When using Xlive, you agree not to:'),
            _legalBullet('Violate the law or our Community Guidelines, or infringe the rights of others.'),
            _legalBullet('Post content that is unlawful, hateful, harassing, sexually exploitative, or harmful to minors.'),
            _legalBullet('Impersonate any person, or misrepresent your affiliation with a person or entity.'),
            _legalBullet('Use bots, scrapers, or artificial means to inflate views, followers, gifts, or engagement.'),
            _legalBullet('Attempt to disrupt, reverse engineer, or gain unauthorized access to the Services.'),
            _legalHeading('4. Your content and license'),
            _legalParagraph(
              'You retain ownership of the content you create and share on Xlive. By posting content, you grant Xlive a worldwide, non-exclusive, royalty-free, transferable, sub-licensable license to host, store, reproduce, adapt, distribute, and display that content for the purpose of operating, promoting, and improving the Services. This license ends when your content is deleted, except where it has been shared with others who have not deleted it, or where retention is required by law.',
            ),
            _legalHeading('5. Coins, gifts and virtual items'),
            _legalParagraph(
              'Xlive coins and gifts are a limited, non-transferable, revocable license to a feature of the Services. They have no monetary value, are not your property, and cannot be exchanged for cash except through approved creator payouts. Purchases of coins are generally final and non-refundable except where required by law.',
            ),
            _legalHeading('6. Creator monetization and payouts'),
            _legalParagraph(
              'Eligible creators may earn from gifts, subscriptions, and private streams. Payouts are subject to verification, minimum thresholds, applicable fees, taxes, and our payout policies. We may withhold or reverse earnings linked to fraud, chargebacks, or violations of these Terms.',
            ),
            _legalHeading('7. Livestreaming and calls'),
            _legalParagraph(
              'Live content is largely real-time. You are responsible for what you broadcast and for any participant you invite. We may interrupt, remove, or restrict streams and calls that violate these Terms or our Community Guidelines.',
            ),
            _legalHeading('8. Intellectual property'),
            _legalParagraph(
              'The Xlive name, logo, and software are owned by Xlive and protected by law. We respond to valid intellectual-property notices and may remove infringing content and terminate repeat infringers.',
            ),
            _legalHeading('9. Suspension and termination'),
            _legalParagraph(
              'We may suspend or terminate your access if you violate these Terms or our policies, or to protect the community or the Services. You may stop using Xlive and delete your account at any time.',
            ),
            _legalHeading('10. Disclaimers and limitation of liability'),
            _legalParagraph(
              'The Services are provided "as is" without warranties of any kind. To the maximum extent permitted by law, Xlive is not liable for indirect, incidental, or consequential damages arising from your use of the Services.',
            ),
            _legalHeading('11. Changes to these Terms'),
            _legalParagraph(
              'We may update these Terms from time to time. If we make material changes, we will provide notice in the app. Continued use after changes take effect means you accept the updated Terms.',
            ),
            _legalHeading('12. Contact'),
            _legalParagraph('Questions about these Terms? Contact us at support@xlive.app.'),
          ],
        ),
      ),
    ),
  );
}

void showPrivacyPolicySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, scrollController) => _LegalSheetFrame(
        title: 'Privacy Policy',
        scrollController: scrollController,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legalMeta(_legalUpdated),
            _legalIntro(
              'Xlive Ltd ("Xlive", "we", "us") is committed to protecting and respecting your privacy. This Privacy Policy explains what information we collect, how we use and share it, and the choices you have. It applies to the Xlive app and related services.',
            ),
            _legalHeading('1. Information you provide'),
            _legalBullet('Account information such as your name, username, email or phone number, password, date of birth, and profile details.'),
            _legalBullet('Content you create, including streams, clips, comments, chats, calls, and gifts.'),
            _legalBullet('Payment and payout details when you buy coins or receive creator earnings (processed by our payment partners).'),
            _legalBullet('Information you share when you contact support or report an issue.'),
            _legalHeading('2. Information we collect automatically'),
            _legalBullet('Device and connection data such as device model, operating system, app version, and IP address.'),
            _legalBullet('Usage data such as the content you view, features you use, and interactions like likes, follows, and watch time.'),
            _legalBullet('Approximate location derived from your IP address or device settings, where permitted.'),
            _legalHeading('3. How we use your information'),
            _legalParagraph('We use your information to:'),
            _legalBullet('Provide, personalize, and improve the Services, including recommendations.'),
            _legalBullet('Process coin purchases, gifts, and creator payouts.'),
            _legalBullet('Keep Xlive safe by detecting fraud, abuse, and policy violations.'),
            _legalBullet('Communicate with you about updates, security, and support.'),
            _legalHeading('4. How we share your information'),
            _legalParagraph(
              'We do not sell your personal information. We share information with service providers who help us operate Xlive (such as hosting, payments, and analytics), with other users according to your privacy settings (for example, your public profile and content), and where required by law or to protect rights and safety.',
            ),
            _legalHeading('5. Your rights and choices'),
            _legalParagraph(
              'Depending on where you live, you may have the right to access, correct, delete, or export your personal information, and to object to or restrict certain processing. You can manage much of this in the app under Settings, including privacy and content preferences, blocking, and account deletion.',
            ),
            _legalHeading('6. Data retention'),
            _legalParagraph(
              'We keep your information for as long as your account is active or as needed to provide the Services, comply with legal obligations, resolve disputes, and enforce our agreements. When you delete your account, we delete or de-identify your personal information, subject to limited legal exceptions.',
            ),
            _legalHeading('7. Security'),
            _legalParagraph(
              'We use technical and organizational measures designed to protect your information. No method of transmission or storage is completely secure, so we cannot guarantee absolute security.',
            ),
            _legalHeading('8. Children'),
            _legalParagraph(
              'Xlive is not directed to children under 13, and we do not knowingly collect personal information from them. If you believe a child has provided us information, please contact us so we can take appropriate action.',
            ),
            _legalHeading('9. International transfers'),
            _legalParagraph(
              'Your information may be processed in countries other than where you live. Where we transfer data internationally, we use appropriate safeguards as required by law.',
            ),
            _legalHeading('10. Changes to this policy'),
            _legalParagraph(
              'We may update this Privacy Policy from time to time. We will notify you of material changes in the app, and your continued use means you accept the updated policy.',
            ),
            _legalHeading('11. Contact'),
            _legalParagraph('For privacy questions or requests, contact us at privacy@xlive.app.'),
          ],
        ),
      ),
    ),
  );
}

void showCommunityGuidelinesSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, scrollController) => _LegalSheetFrame(
        title: 'Community Guidelines',
        scrollController: scrollController,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legalMeta(_legalUpdated),
            _legalIntro(
              'Xlive is a place to create, connect, and go live. These Community Guidelines set the rules for everyone, and apply to all content and behavior on Xlive including streams, clips, comments, chats, calls, profiles, and gifts. Breaking these rules can lead to content removal, feature limits, or account termination.',
            ),
            _legalHeading('Safety of minors'),
            _legalParagraph(
              'We have zero tolerance for content that sexualizes, endangers, or exploits minors. We do not allow grooming, sexual content involving minors, or sharing of personal information about minors. We report apparent child sexual abuse material to the relevant authorities.',
            ),
            _legalHeading('Violence and dangerous behavior'),
            _legalBullet('No threats, incitement, or glorification of violence.'),
            _legalBullet('No promotion of dangerous acts, challenges, or self-harm and suicide.'),
            _legalBullet('No content promoting terrorism, organized hate, or criminal organizations.'),
            _legalHeading('Harassment and bullying'),
            _legalParagraph(
              'Do not target others with abuse, threats, unwanted sexual advances, or coordinated harassment. Do not share private information about others without consent (doxxing).',
            ),
            _legalHeading('Hateful behavior'),
            _legalParagraph(
              'We remove hate speech and hateful behavior that attacks people based on protected attributes such as race, ethnicity, national origin, religion, caste, sexual orientation, sex, gender, gender identity, disability, or serious disease.',
            ),
            _legalHeading('Nudity and sexual content'),
            _legalParagraph(
              'No pornography or sexually explicit content, and no content that solicits sexual services. Some artistic, educational, or breastfeeding content may be allowed but can be age-restricted.',
            ),
            _legalHeading('Regulated goods and illegal activities'),
            _legalBullet('No trade or promotion of drugs, weapons, or other regulated or illegal goods.'),
            _legalBullet('No fraud, scams, gambling promotion, or other illegal activity.'),
            _legalHeading('Integrity and authenticity'),
            _legalBullet('No spam, fake engagement, or artificially boosting views, followers, or gifts.'),
            _legalBullet('No impersonation or deceptive behavior.'),
            _legalBullet('No harmful misinformation that could cause real-world harm.'),
            _legalHeading('Intellectual property'),
            _legalParagraph(
              'Only share content you have the right to share. Respect copyrights, trademarks, and other rights of creators and brands.',
            ),
            _legalHeading('Enforcement'),
            _legalParagraph(
              'We use a combination of technology and human review to enforce these guidelines. Depending on severity, we may remove content, limit features, restrict livestreaming or monetization, or remove accounts. Serious or repeated violations can lead to permanent bans.',
            ),
            _legalHeading('Reporting'),
            _legalParagraph(
              'If you see something that breaks these guidelines, report it in the app. Reports are confidential, and you can also block users you do not want to interact with.',
            ),
          ],
        ),
      ),
    ),
  );
}

void showReportSubmittedSheet(BuildContext context, {VoidCallback? onClosed}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetTopRadius)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: _grabber, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 28),
            const Text(
              'Report submitted',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'We wiil review your report and get back to you through your email',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.45),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onClosed?.call();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _submitPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LegalSheetFrame extends StatelessWidget {
  const _LegalSheetFrame({required this.title, required this.scrollController, required this.child});

  final String title;
  final ScrollController scrollController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetTopRadius)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: _grabber, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black),
                  ),
                ),
                Material(
                  color: _closeBg,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.close_rounded, size: 20, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(20, 20, 20, 40 + MediaQuery.paddingOf(context).bottom),
              children: [child],
            ),
          ),
        ],
      ),
    );
  }
}

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _controller = TextEditingController();
  static const _purple = Color(0xFF8A2DDC);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    showReportSubmittedSheet(context, onClosed: () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: IconButton(
                      padding: const EdgeInsets.only(left: 10),
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Report an Issue',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tell us more about the issues you will like to report. You can drop a message we will reply back to you through your mail.',
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade800, height: 1.45),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: 'Type here...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _purple, width: 1.2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Submit', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
