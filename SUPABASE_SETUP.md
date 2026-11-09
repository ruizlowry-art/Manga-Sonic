# Supabase Integration Setup Guide for MangaSonic

This guide walks you through setting up Supabase authentication and sync for MangaSonic.

## Prerequisites

- A Supabase project (you have this: https://uqctywfelijyndqtulgu.supabase.co)
- Supabase anon/public key (configured in `lib/config/supabase_config.dart`)

## Step 1: Run Database Schema in Supabase Dashboard

1. Go to your Supabase Dashboard: https://supabase.com/dashboard/project/uqctywfelijyndqtulgu
2. Navigate to **SQL Editor** (left sidebar)
3. Click **New Query**
4. Copy and paste the entire contents of `supabase_schema.sql` (in the project root)
5. Click **Run** (or press Ctrl+Enter)

This will create:
- `library_items` table - for user's manga library
- `reading_progress` table - for reading progress per chapter
- `categories` table - for custom library categories (optional)
- Row Level Security (RLS) policies - ensures users only access their own data

### Verify the setup:
Run these queries in SQL Editor:
```sql
-- Check tables exist
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

-- Check RLS is enabled
SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';

-- Check policies
SELECT * FROM pg_policies WHERE schemaname = 'public';
```

## Step 2: Configure Authentication Settings

1. In Supabase Dashboard, go to **Authentication** → **Settings**
2. Under **Email Auth**, configure:
   - **Enable email confirmations**: OFF (you chose to disable email confirmation)
   - **Enable email change confirmations**: OFF
   - **Secure password requirements**: Set as desired (default: 6 chars minimum)
3. Under **URL Configuration**:
   - **Site URL**: `https://uqctywfelijyndqtulgu.supabase.co` (or your production URL)
   - **Redirect URLs**: Add `io.supabase.flutter://login-callback/` for mobile deep linking

## Step 3: Verify App Configuration

The app is already configured with your credentials in:
- `lib/config/supabase_config.dart` - Contains project URL and anon key

## Step 4: Test the Integration

1. Run the app: `flutter run`
2. You should see the authentication screen on first launch
3. Sign up with a test email/password
4. After signing in, you'll be taken to the home screen
5. Go to Settings → Account to see sync status
6. Add manga to your library - it should sync to Supabase
7. Read some chapters - progress should sync to Supabase

## Step 5: Test Cross-Device Sync

1. Install the app on another device (or use a different browser/profile)
2. Sign in with the same credentials
3. Your library and reading progress should appear

## Architecture Overview

### Local-First Sync Flow

```
User Action (Add to Library / Read Chapter)
         │
         ▼
    ┌─────────────────────┐
    │  Write to Local DB  │  (Hive - instant, works offline)
    └─────────────────────┘
         │
         ▼
    ┌─────────────────────┐
    │  Queue for Sync     │  (In-memory pending changes)
    └─────────────────────┘
         │
         ▼ (when online + signed in)
    ┌─────────────────────┐
    │  Push to Supabase   │  (Upsert with conflict resolution)
    └─────────────────────┘
         │
         ▼
    ┌─────────────────────┐
    │  Pull from Supabase │  (Merge with local, last-write-wins)
    └─────────────────────┘
```

### Conflict Resolution Policy

**Last-Write-Wins (based on timestamp)**
- Library items: Compared by `addedAt` timestamp
- Reading progress: Compared by `lastReadTimestamp`
- The most recently updated record wins
- Local changes made during sync remain pending for next sync

### Data Synced

| Data Type | Local Storage | Synced to Supabase |
|-----------|---------------|-------------------|
| Library Items (manga) | Hive `library_items` box | `library_items` table |
| Reading Progress | Hive `chapter_statuses` box | `reading_progress` table |
| Categories | Hive `categories` box | `categories` table (optional) |
| Downloaded Chapters | Local filesystem | ❌ NOT synced |
| Cached Manga Details | Hive `manga_cache` box | ❌ NOT synced |

## Troubleshooting

### "Sync failed" in Settings
- Check internet connection
- Verify Supabase project is not paused
- Check Supabase logs: Dashboard → Logs → Database

### Authentication not working
- Verify anon key in `lib/config/supabase_config.dart`
- Check Supabase Auth settings (email confirmations disabled)
- Check browser console for errors

### Data not syncing
- Ensure user is signed in (Settings → Account shows email)
- Check sync status in Settings
- Try "Sync Now" button
- Check pending changes count

### RLS Policy Errors
- Verify policies were created correctly (Step 1)
- Ensure user_id matches auth.uid() in all queries

## Security Notes

- **Anon key** is safe to include in client code (it's designed for public access)
- **RLS policies** ensure users only access their own data
- **No service role key** is used in the app
- **Passwords** are never stored locally - handled by Supabase Auth
- **Downloaded content** stays local - only metadata syncs

## Files Modified/Added

### New Files
- `lib/config/supabase_config.dart` - Supabase configuration
- `lib/services/auth_service.dart` - Authentication management
- `lib/services/sync_service.dart` - Local-first sync logic
- `lib/features/auth/auth_wrapper.dart` - Auth state routing
- `lib/features/auth/auth_screen.dart` - Sign in/up UI
- `supabase_schema.sql` - Database schema with RLS

### Modified Files
- `pubspec.yaml` - Added `supabase_flutter` dependency
- `lib/app/bootstrap.dart` - Initialize Supabase, Auth, Sync services
- `lib/app/app.dart` - Provide Auth/Sync services, use AuthWrapper
- `lib/main.dart` - Pass new services to app
- `lib/data/db/library_db.dart` - Queue library changes for sync
- `lib/data/db/history_db.dart` - Queue progress changes for sync
- `lib/features/settings/settings_tab.dart` - Account & sync status UI

## Next Steps (Optional Enhancements)

1. **Persistent pending changes** - Save pending queue to Hive for survival across app restarts
2. **Real-time sync** - Enable Supabase Realtime for instant cross-device updates
3. **Background sync** - Use WorkManager/BackgroundFetch for periodic sync
4. **Conflict UI** - Show conflicts when local and remote differ significantly
5. **Export/Import** - Backup/restore local data as JSON