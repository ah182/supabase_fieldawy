-- دالة لإنقاص عداد المشاهدات للستوري (للاستخدام مع التخزين المحلي)
CREATE OR REPLACE FUNCTION decrement_story_like(p_story_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE distributor_stories
    SET likes_count = GREATEST(0, likes_count - 1)
    WHERE id = p_story_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ملاحظة: يمكنك الآن حذف جدول story_likes لتوفير المساحة إذا أردت:
-- DROP TABLE IF EXISTS story_likes;
