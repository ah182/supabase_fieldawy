import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/core/utils/number_formatter.dart';
import 'package:fieldawy_store/features/stories/domain/story_model.dart';
import 'package:fieldawy_store/features/stories/presentation/widgets/product_tag_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fieldawy_store/features/stories/application/seen_stories_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gal/gal.dart'; // Import for saving images
import 'package:http/http.dart' as http; // For downloading image bytes
import 'package:path_provider/path_provider.dart'; // For temp path

import 'package:shared_preferences/shared_preferences.dart'; // Import for local storage
import 'package:fieldawy_store/core/caching/caching_service.dart'; // Import caching service
import 'package:fieldawy_store/features/stories/application/stories_provider.dart'; // Import stories provider

class StoryViewScreen extends ConsumerStatefulWidget {
  final List<DistributorStoriesGroup> groups;
  final int initialGroupIndex;

  const StoryViewScreen({
    super.key,
    required this.groups,
    this.initialGroupIndex = 0,
  });

  @override
  ConsumerState<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends ConsumerState<StoryViewScreen> {
  late PageController _groupController;
  int _currentGroupIndex = 0;
  int _currentStoryIndex = 0;
  Timer? _timer;
  double _progress = 0.0;
  bool _isImageLoaded = false;
  bool _isLiked = false; // حالة الإعجاب المحلية
  int _localLikesCount = 0; // عداد محلي للتحديث اللحظي
  static const int _storyDurationSeconds = 10;
  List<String> _likedStoriesIds = []; // قائمة محلية للإعجابات
  bool _needsRefresh = false; // علم لتحديد ما إذا كنا نحتاج لتحديث القائمة عند الخروج
  double _tagYOffset = 0.0; // إزاحة التاج الرأسية

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex;
    _groupController = PageController(initialPage: _currentGroupIndex);
    _localLikesCount = widget.groups[_currentGroupIndex].stories[_currentStoryIndex].likesCount;
    _loadLikedStories(); // تحميل الإعجابات المحلية
  }

  // تحميل الإعجابات من الذاكرة المحلية
  Future<void> _loadLikedStories() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _likedStoriesIds = prefs.getStringList('liked_stories_list') ?? [];
    });
    // التحقق فوراً بعد التحميل للستوري الحالية
    _checkIfLiked(widget.groups[_currentGroupIndex].stories[_currentStoryIndex].id);
    _incrementViewAndMarkSeen(); // استدعاء زيادة المشاهدة بعد التأكد من تحميل البيانات
  }

  // دالة لزيادة المشاهدات وتحديدها كـ "تمت المشاهدة"
  Future<void> _incrementViewAndMarkSeen() async {
    try {
      final story = widget.groups[_currentGroupIndex].stories[_currentStoryIndex];
      
      // إعادة تعيين الحالة مبدئياً لتجنب ظهور حالة الستوري السابقة
      if (mounted) {
        setState(() {
          _localLikesCount = story.likesCount;
           // نتحقق من القائمة المحلية المحملة
          _isLiked = _likedStoriesIds.contains(story.id);
          _tagYOffset = 0.0; // إعادة ضبط موقع التاج للستوري الجديدة
        });
      }

      await Supabase.instance.client.rpc('increment_story_view', params: {
        'p_story_id': story.id,
      });

      if (mounted) {
        ref.read(seenStoriesProvider.notifier).markAsSeen(story.id);
      }
    } catch (e) {
      debugPrint('Error in _incrementViewAndMarkSeen: $e');
    }
  }

  // التحقق من الإعجاب (محلياً)
  void _checkIfLiked(String storyId) {
    if (mounted) {
      setState(() {
        _isLiked = _likedStoriesIds.contains(storyId);
      });
    }
  }

  // دالة التعامل مع الإعجاب (محلي + سيرفر بسيط)
  Future<void> _handleLike() async {
    HapticFeedback.heavyImpact();
    
    final storyId = widget.groups[_currentGroupIndex].stories[_currentStoryIndex].id;
    final isCurrentlyLiked = _likedStoriesIds.contains(storyId);
    
    // تحديث الواجهة فوراً
    setState(() {
      if (isCurrentlyLiked) {
        _isLiked = false;
        _localLikesCount = (_localLikesCount - 1).clamp(0, 999999);
        _likedStoriesIds.remove(storyId);
      } else {
        _isLiked = true;
        _localLikesCount++;
        _likedStoriesIds.add(storyId);
      }
      _needsRefresh = true; // حدث تغيير، سنحتاج لتحديث الكاش عند الخروج
    });

    // حفظ التغيير محلياً
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('liked_stories_list', _likedStoriesIds);

    // تحديث السيرفر (بدون انتظار النتيجة)
    try {
      if (isCurrentlyLiked) {
        await Supabase.instance.client.rpc('decrement_story_like', params: {
          'p_story_id': storyId,
        });
      } else {
        await Supabase.instance.client.rpc('increment_story_like', params: {
          'p_story_id': storyId,
        });
      }
    } catch (e) {
      debugPrint('Error updating server like count: $e');
    }
  }

  // دالة تحميل الاستوري
  Future<void> _downloadStory() async {
    _timer?.cancel(); // إيقاف الاستوري مؤقتاً
    try {
      final imageUrl = widget.groups[_currentGroupIndex].stories[_currentStoryIndex].imageUrl;
      
      // 1. تحميل الصورة لملف مؤقت
      final response = await http.get(Uri.parse(imageUrl));
      final bytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/story_download_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(path);
      await file.writeAsBytes(bytes);

      // 2. الحفظ في المعرض باستخدام Gal
      await Gal.putImage(path);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حفظ الصورة في المعرض')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ فشل تحميل الصورة')),
        );
      }
    } finally {
      _startStoryTimer(); // استكمال الاستوري
    }
  }

  // دالة حذف الاستوري
  Future<void> _deleteStory(String storyId) async {
    _timer?.cancel(); // إيقاف الاستوري
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الاستوري'),
        content: const Text('هل أنت متأكد من حذف هذه الاستوري؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('distributor_stories')
            .delete()
            .eq('id', storyId);
            
        if (mounted) {
          // تحديث الكاش وإغلاق الصفحة
          ref.read(cachingServiceProvider).invalidate('active_distributor_stories_v1');
          ref.invalidate(storiesProvider);
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الاستوري بنجاح')),
          );
        }
      } catch (e) {
        debugPrint('Error deleting story: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل حذف الاستوري')),
          );
          _startStoryTimer(); // استئناف الستوري في حالة الفشل
        }
      }
    } else {
      _startStoryTimer(); // استئناف الستوري عند الإلغاء
    }
  }

  void _startStoryTimer() {
    if (!_isImageLoaded) return; // منع البدء إذا لم تحمل الصورة
    
    _timer?.cancel();
    _progress = 0.0;
    
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress += 0.05 / _storyDurationSeconds;
        if (_progress >= 1.0) {
          _nextStory();
        }
      });
    });
  }

  void _nextStory() {
    final currentGroup = widget.groups[_currentGroupIndex];
    if (_currentStoryIndex < currentGroup.stories.length - 1) {
      if (!mounted) return;
      setState(() {
        _isImageLoaded = false; // إعادة ضبط الحالة للستوري الجديدة
        _currentStoryIndex++;
        _timer?.cancel();
        _progress = 0.0;
      });
      _incrementViewAndMarkSeen();
    } else {
      _nextGroup();
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      if (!mounted) return;
      setState(() {
        _isImageLoaded = false;
        _currentStoryIndex--;
        _timer?.cancel();
        _progress = 0.0;
      });
      _incrementViewAndMarkSeen();
    } else {
      _previousGroup();
    }
  }

  void _nextGroup() {
    if (_currentGroupIndex < widget.groups.length - 1) {
      if (!mounted) return;
      setState(() {
        _isImageLoaded = false;
        _currentGroupIndex++;
        _currentStoryIndex = 0;
        _timer?.cancel();
        _progress = 0.0;
      });
      _groupController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _incrementViewAndMarkSeen();
    } else {
      _timer?.cancel();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _previousGroup() {
    if (_currentGroupIndex > 0) {
      if (!mounted) return;
      setState(() {
        _isImageLoaded = false;
        _currentGroupIndex--;
        _currentStoryIndex = widget.groups[_currentGroupIndex].stories.length - 1;
        _timer?.cancel();
        _progress = 0.0;
      });
      _groupController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _incrementViewAndMarkSeen();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _groupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _needsRefresh) {
          ref.read(cachingServiceProvider).invalidate('active_distributor_stories_v1');
          ref.invalidate(storiesProvider);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
         body: PageView.builder(
            controller: _groupController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.groups.length,
            itemBuilder: (context, index) {
              int storyIndex;
              if (index == _currentGroupIndex) {
                storyIndex = _currentStoryIndex;
              } else if (index < _currentGroupIndex) {
                storyIndex = widget.groups[index].stories.length - 1;
              } else {
                storyIndex = 0;
              }
              storyIndex = storyIndex.clamp(0, widget.groups[index].stories.length - 1);
              
              return _buildGroupPage(index, storyIndex);
            },
          ),
        ),
      
    );
  }

  Widget _buildGroupPage(int groupIndex, int storyIndex) {
    final group = widget.groups[groupIndex];
    final story = group.stories[storyIndex];
    final distributor = group.distributor;
    final isCurrentPage = (groupIndex == _currentGroupIndex);
    
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = currentUserId != null && currentUserId == story.distributorId;

    return Stack(
      children: [
        // 1. الصورة الخلفية مع مراقب التحميل
        GestureDetector(
          onTapUp: (details) {
            if (!isCurrentPage) return;
            final width = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < width / 3) {
              _previousStory();
            } else {
              _nextStory();
            }
          },
          onLongPressStart: (_) => isCurrentPage ? _timer?.cancel() : null,
          onLongPressEnd: (_) => isCurrentPage ? _startStoryTimer() : null,
          child: Padding(
            padding: const EdgeInsets.only(top: 110, bottom: 195),
            child: Center(
              child: CachedNetworkImage(
                imageUrl: story.imageUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white70)),
                imageBuilder: (context, imageProvider) {
                  if (isCurrentPage && !_isImageLoaded) {
                    _isImageLoaded = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) => _startStoryTimer());
                  }
                  return Image(image: imageProvider, fit: BoxFit.contain);
                },
              ),
            ),
          ),
        ),

        // 3. معلومات الموزع وأزرار الأكشن العلوية
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              children: [
                Row(
                  children: List.generate(group.stories.length, (index) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: LinearProgressIndicator(
                          value: isCurrentPage
                              ? (index < _currentStoryIndex
                                  ? 1.0
                                  : (index == _currentStoryIndex ? _progress : 0.0))
                              : (index < storyIndex ? 1.0 : 0.0),
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 2,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: distributor.photoURL != null
                          ? CachedNetworkImageProvider(distributor.photoURL!)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      distributor.displayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.visibility_rounded, size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            NumberFormatter.formatCompact(story.viewsCount),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (isOwner)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        onPressed: () => _deleteStory(story.id),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 3.5 أزرار التفاعل الجانبية
        if (isCurrentPage)
          Positioned(
            right: 15,
            bottom: 180,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _handleLike,
                  child: Column(
                    children: [
                      AnimatedScale(
                        scale: _isLiked ? 1.2 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: _isLiked
                            ? ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF89CFF0), Color(0xFF00BFFF)],
                                ).createShader(bounds),
                                child: Icon(
                                  Icons.favorite_rounded,
                                  color: Colors.white,
                                  size: 32,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              )
                            : Icon(
                                Icons.favorite_border_rounded,
                                color: Colors.white,
                                size: 32,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_localLikesCount',
                        style: TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 12,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                GestureDetector(
                  onTap: _downloadStory,
                  child: Column(
                    children: [
                      Icon(
                        Icons.download_for_offline_rounded,
                        color: Colors.white,
                        size: 32,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'حفظ',
                        style: TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 12,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // 4. الوصف والأكشن
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (story.caption != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Text(
                          story.caption!,
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                if (isCurrentPage)
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openWhatsApp(distributor.whatsappNumber, story.imageUrl),
                      icon: const Icon(Icons.forum_rounded, size: 22),
                      label: const Text(
                        'ارسل رسالة', 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 8,
                        shadowColor: const Color(0xFF25D366).withOpacity(0.4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 3.8 تاغ المنتج
        if (isCurrentPage && story.productLinkId != null)
           Positioned(
             bottom: (105 - _tagYOffset).clamp(80.0, MediaQuery.of(context).size.height - 150), 
             left: 0,
             right: 0,
             child: ProductTagOverlay(
               productLinkId: story.productLinkId!,
               onDialogOpened: () => setState(() => _timer?.cancel()),
               onDialogClosed: () => setState(() => _startStoryTimer()),
               onVerticalDragStart: (_) {
                 setState(() {
                   _timer?.cancel();
                 });
               },
               onVerticalDragUpdate: (details) {
                 setState(() {
                   _tagYOffset += details.delta.dy; 
                 });
               },
               onVerticalDragEnd: (_) {
                 setState(() {
                   _startStoryTimer();
                 });
               },
             ),
           ),
      ],
    );
  }

  Future<void> _openWhatsApp(String? phone, String imageUrl) async {
    if (phone == null || phone.isEmpty) return;

    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (!cleanPhone.startsWith('2') && !cleanPhone.startsWith('+')) {
      cleanPhone = '2$cleanPhone';
    }
    if (!cleanPhone.startsWith('+')) {
      cleanPhone = '+$cleanPhone';
    }

    final url = Uri.parse("https://wa.me/${cleanPhone.replaceAll('+', '')}");
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
