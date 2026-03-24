package com.celalbasaran.stripmate.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [
        UserEntity::class,
        FriendEntity::class,
        StripEntity::class
    ],
    version = 1,
    exportSchema = false
)
abstract class StripMateDatabase : RoomDatabase() {
    abstract fun stripMateDao(): StripMateDao

    companion object {
        const val DATABASE_NAME = "stripmate_db"
    }
}
