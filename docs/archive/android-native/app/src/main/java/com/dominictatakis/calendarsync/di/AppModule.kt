package com.dominictatakis.calendarsync.di

import com.dominictatakis.calendarsync.data.repository.AndroidCalendarRepository
import com.dominictatakis.calendarsync.data.repository.GoogleCalendarRepository
import com.dominictatakis.calendarsync.data.repository.SupabaseRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideSupabaseRepository(): SupabaseRepository = SupabaseRepository()

    @Provides
    @Singleton
    fun provideGoogleCalendarRepository(): GoogleCalendarRepository = GoogleCalendarRepository()

    @Provides
    @Singleton
    fun provideAndroidCalendarRepository(): AndroidCalendarRepository = AndroidCalendarRepository()
}
