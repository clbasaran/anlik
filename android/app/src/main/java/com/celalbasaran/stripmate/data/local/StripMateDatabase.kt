package com.celalbasaran.stripmate.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [
        UserEntity::class,
        FriendEntity::class,
        StripEntity::class
    ],
    version = 2,
    // Schema JSON lives under app/schemas/ once migrations start being
    // authored — required so Room can verify migrations match expected DDL.
    // The directory is registered in build.gradle.kts under `room { schemaDirectory(...) }`.
    exportSchema = true
)
abstract class StripMateDatabase : RoomDatabase() {
    abstract fun stripMateDao(): StripMateDao

    companion object {
        const val DATABASE_NAME = "stripmate_db"
    }
}
