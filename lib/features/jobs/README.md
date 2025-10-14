# Job Offers System - Flutter Integration

## Structure

```
lib/features/jobs/
├── domain/
│   └── job_offer_model.dart        # Data model
├── data/
│   └── job_offers_repository.dart  # Supabase integration
├── application/
│   └── job_offers_provider.dart    # Riverpod state management
└── presentation/
    └── screens/
        ├── job_offers_screen.dart      # Main screen with tabs
        └── add_job_offer_screen.dart   # Add job offer form
```

## Features

### 1. View All Jobs (Available Jobs Tab)
- Displays all active job offers from all users
- Pull-to-refresh support
- Empty state for no jobs
- Error handling with retry option

### 2. My Job Offers Tab
- Displays user's own job offers (all statuses)
- Delete job offers with confirmation dialog
- Pull-to-refresh support
- Empty state with quick add button

### 3. Add Job Offer
- Form validation:
  - Title: 10-200 characters
  - Description: 20-100 words
  - Phone: Egyptian format (01XXXXXXXXX)
- Word counter for description
- Loading state during submission
- Success/error feedback

## Usage

### 1. Navigate to Job Offers
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const JobOffersScreen(),
  ),
);
```

### 2. Add Job Offer
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const AddJobOfferScreen(),
  ),
);
```

## Providers

### Available Providers

1. **jobOffersRepositoryProvider**
   - Type: `Provider<JobOffersRepository>`
   - Access to repository methods

2. **allJobOffersNotifierProvider**
   - Type: `StateNotifierProvider<JobOffersNotifier, AsyncValue<List<JobOffer>>>`
   - Manages all active job offers state
   - Methods: `fetchAllJobs()`, `refreshAllJobs()`

3. **myJobOffersNotifierProvider**
   - Type: `StateNotifierProvider<MyJobOffersNotifier, AsyncValue<List<JobOffer>>>`
   - Manages user's own job offers state
   - Methods: `fetchMyJobs()`, `refreshMyJobs()`, `deleteJob(id)`, `closeJob(id)`

### Example Usage

```dart
// Watch all jobs
final jobsAsync = ref.watch(allJobOffersNotifierProvider);

// Refresh jobs
await ref.read(allJobOffersNotifierProvider.notifier).refreshAllJobs();

// Delete a job
final success = await ref.read(myJobOffersNotifierProvider.notifier).deleteJob(jobId);
```

## Database Functions Used

- `get_all_job_offers()` - Fetch all active jobs
- `get_my_job_offers(user_id)` - Fetch user's jobs
- `create_job_offer(title, description, phone)` - Create new job
- `update_job_offer(id, title, description, phone)` - Update job
- `delete_job_offer(id)` - Delete job
- `close_job_offer(id)` - Close job
- `increment_job_views(id)` - Increment view counter

## Translations Required

Add these keys to your translation files:

```json
{
  "jobOffers": "Job Offers / عروض التوظيف",
  "availableJobs": "Available Jobs / الوظائف المتاحة",
  "myJobOffers": "My Job Offers / عروضي الوظيفية",
  "addJobOffer": "Add Job Offer / إضافة عرض توظيف",
  "noJobsAvailable": "No Jobs Available / لا توجد وظائف متاحة",
  "noMyJobOffers": "You Have No Job Offers / ليس لديك عروض توظيف",
  "addYourFirstJob": "Add Your First Job / أضف عرضك الأول",
  "jobOfferSubmitted": "Job offer published successfully / تم نشر العرض بنجاح"
}
```

## Integration Checklist

- [x] Database migration applied
- [x] Models created
- [x] Repository implemented
- [x] Providers configured
- [x] UI screens created
- [x] Navigation integrated
- [x] Translations added
- [ ] Test on device
- [ ] Add to navigation menu (Already done!)

## Notes

- All job offers are created with `active` status by default
- Users can only modify/delete their own job offers
- Pull-to-refresh is available on both tabs
- Error handling with user-friendly messages
- Loading states during data fetching
- Optimistic UI updates (delete shows immediately)
