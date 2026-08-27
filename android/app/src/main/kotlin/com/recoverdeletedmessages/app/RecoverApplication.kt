package com.recoverdeletedmessages.app

import android.app.Application
import android.util.Log

/**
 * KeepAliveService is a "nice to have" (extra insurance against OEM battery
 * managers killing the app in the background), not core functionality --
 * message capture works via NotificationListener regardless of whether it's
 * running. But if Android's mandatory 5-second startForeground() window is
 * missed, the system delivers android.app.RemoteServiceException as an
 * *uncaught* exception on the main thread, which kills the entire app by
 * default -- including on slow/low-end devices where a debug build's JIT
 * cold-start alone can burn through that window before any of our own code
 * gets a real turn on the CPU. No amount of "start it earlier" or "make our
 * code faster" can fully close that race, since the clock is OS-controlled
 * and starts the instant startForegroundService() is called. Downgrading
 * losing this one specific race to "the keep-alive service just doesn't
 * start this time" instead of "the whole app is unusable" is the correct
 * tradeoff for a service whose only job is background-kill insurance.
 */
class RecoverApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            if (isMissedStartForeground(throwable)) {
                Log.w("Recover", "Missed startForeground() window for KeepAliveService -- ignoring, not fatal", throwable)
                return@setDefaultUncaughtExceptionHandler
            }
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }

    private fun isMissedStartForeground(t: Throwable): Boolean {
        val name = t.javaClass.name
        val isRemoteServiceException = name == "android.app.RemoteServiceException" ||
            name == "android.app.RemoteServiceException\$ForegroundServiceDidNotStartInTimeException"
        return isRemoteServiceException && t.message?.contains("startForeground") == true
    }
}
