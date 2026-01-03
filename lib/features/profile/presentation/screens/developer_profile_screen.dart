import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DeveloperProfileScreen extends StatelessWidget {
  const DeveloperProfileScreen({super.key});

  Future<void> _launchSocial(String url) async {
    Uri uri = Uri.parse(url);
    
    if (url.contains('facebook.com')) {
      // Try native Facebook app scheme
      final fbUri = Uri.parse('fb://facewebmodal/f?href=$url');
      try {
        if (await canLaunchUrl(fbUri)) {
          await launchUrl(fbUri);
          return;
        }
      } catch (e) {
        debugPrint('Facebook app not found');
      }
    }

    // Fallback to browser/external app
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch url: $e');
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent('Fieldawy App Support')}',
    );
    
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch email');
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
      // Fallback: try simple string parsing
      final String simpleMailto = 'mailto:$email?subject=Support';
      await launchUrl(Uri.parse(simpleMailto), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('contact_support'.tr()),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
              ? [const Color.fromARGB(255, 33, 33, 35), const Color(0xFF0F0F1A)]
              : [const Color(0xFFE3F2FD), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(50.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Developer Image - Clean Zoom-Out (No Border)
                  Center(
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: 'https://res.cloudinary.com/dk8twnfrk/image/upload/v1766123631/profile_images/o5w5sunzbzverjtzmyhm.jpg',
                        width: 130, // تصغير الحجم يعطي إيحاء بالزوم أوت
                        height: 130,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const SizedBox(
                          width: 130,
                          height: 130,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.person, size: 80, color: Colors.grey),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Name
                  Text(
                    'DR / Ahmed Hamed', 
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Veterinarian & Developer',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Social Icons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(
                        context,
                        icon: FontAwesomeIcons.whatsapp,
                        color: const Color(0xFF25D366),
                        onTap: () => _launchSocial('https://wa.me/+201017016217'),
                      ),
                      const SizedBox(width: 20),
                      _buildSocialButton(
                        context,
                        icon: FontAwesomeIcons.facebookF,
                        color: const Color(0xFF1877F2),
                        onTap: () => _launchSocial('https://www.facebook.com/ahmed.hamed.567117'), 
                      ),
                      const SizedBox(width: 20),
                      _buildSocialButton(
                        context,
                        icon: Icons.email_rounded,
                        color: const Color(0xFFEA4335),
                        onTap: () => _launchEmail('ah3181997@gmail.com'), 
                      ),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  Text(
                    'v1.0.0',
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(BuildContext context, {required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
        child: Icon(
          icon,
          color: color,
          size: 30,
        ),
      ),
    );
  }
}
