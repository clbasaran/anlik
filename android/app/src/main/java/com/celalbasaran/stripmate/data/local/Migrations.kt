package com.celalbasaran.stripmate.data.local

import androidx.room.migration.Migration

/**
 * Room migrations for StripMate. Add a new entry here whenever the DB
 * version bumps — Room calls these in order to upgrade an existing user's
 * on-device cache without losing their offline-stored strips/friends.
 *
 * Why this matters:
 * Until now the database used `fallbackToDestructiveMigration()` which wipes
 * the entire local DB on any schema change. SwiftData on iOS now mirrors the
 * cloud, but Android also stores recent cache entries — losing those forces
 * a re-fetch and shows an empty timeline mid-session. Real migrations keep
 * the experience continuous.
 *
 * How to add one:
 * 1. Bump `version` in `@Database` (e.g. 2 → 3).
 * 2. Add a `MIGRATION_X_Y` here describing the schema delta in raw SQL.
 * 3. Append it to `ALL_MIGRATIONS` below.
 * 4. Confirm AppModule's database builder uses `addMigrations(*ALL_MIGRATIONS)`.
 *
 * For purely additive changes (new column with default, new table), the SQL
 * is usually a single ALTER TABLE / CREATE TABLE. For destructive changes
 * (rename, drop, type change), you typically rebuild the table and copy data
 * — Room's documentation has the canonical recipe.
 */
internal val ALL_MIGRATIONS: Array<Migration> = arrayOf(
    // No migrations yet — the database is currently at version 2 and that's
    // the baseline going forward. The next bump (2 → 3) gets its first entry.
)
