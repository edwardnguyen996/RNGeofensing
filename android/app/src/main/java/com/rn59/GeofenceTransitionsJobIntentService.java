/*
 * Copyright 2017 Google Inc. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.rn59;

import android.annotation.SuppressLint;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.location.Location;
import android.media.AudioAttributes;
import android.preference.PreferenceManager;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.core.app.JobIntentService;
import androidx.core.app.NotificationCompat;
import androidx.core.app.TaskStackBuilder;

import android.os.PowerManager;
import android.text.TextUtils;
import android.util.Log;

import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingEvent;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;

import org.json.JSONObject;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Random;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

/**
 * Listener for geofence transition changes.
 *
 * Receives geofence transition events from Location Services in the form of an Intent containing
 * the transition type and geofence id(s) that triggered the transition. Creates a notification
 * as the output.
 */
public class GeofenceTransitionsJobIntentService extends JobIntentService {

    private static final int JOB_ID = 573;

    private static final String TAG = "GeofenceTransitionsIS";

    private static final String CHANNEL_ID = "relocare";

    private static final String LAST_DETECTED_COUNTRY_KEY = "LAST_DETECTED_COUNTRY_KEY";

    FusedLocationProviderClient mFusedLocationClient;

    final static String OpenAppFromLocalNotificationActionName = "OPEN_APP_FROM_LOCAL_NOTIFICATION";

    String countryNames[] = new String[] { "Denmark", "Austria", "Belgium", "Bulgaria", "Croatia", "Republic of Cyprus",
            "Czech Republic", "Estonia", "Finland", "France", "Germany", "Greece", "Hungary", "Ireland", "Italy", "Latvia",
            "Lithuania", "Luxembourg", "Netherlands", "Poland", "Portugal", "Romania", "Slovakia", "Slovenia", "Spain",
            "Sweden", "United Kingdom", };

    String availableGeoApiUserNames[] = new String[] { "pzcapworks", "relocare", "relocare2", "relocare3", "relocare4",
            "relocare5" };

    /**
     * Convenience method for enqueuing work in to this service.
     */
    public static void enqueueWork(Context context, Intent intent) {
        enqueueWork(context, GeofenceTransitionsJobIntentService.class, JOB_ID, intent);
    }

    /**
     * Handles incoming intents.
     * @param intent sent by Location Services. This Intent is provided to Location
     *               Services (inside a PendingIntent) when addGeofences() is called.
     */
    @SuppressLint("MissingPermission")
    @Override
    protected void onHandleWork(Intent intent) {
        GeofencingEvent geofencingEvent = GeofencingEvent.fromIntent(intent);
        if (geofencingEvent.hasError()) {
            String errorMessage = GeofenceErrorMessages.getErrorString(this,
                    geofencingEvent.getErrorCode());
            Log.e(TAG, errorMessage);
            return;
        }

        mFusedLocationClient = LocationServices.getFusedLocationProviderClient(getApplicationContext());

        // Get the transition type.
        int geofenceTransition = geofencingEvent.getGeofenceTransition();

        // Test that the reported transition was of interest.
        if (geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER ||
                geofenceTransition == Geofence.GEOFENCE_TRANSITION_EXIT) {

            // Get the geofences that were triggered. A single event can trigger multiple geofences.
            List<Geofence> triggeringGeofences = geofencingEvent.getTriggeringGeofences();

            // Get the transition details as a String.
            String geofenceTransitionDetails = getGeofenceTransitionDetails(geofenceTransition,
                    triggeringGeofences);

            Random randomGeoApiUser = new Random();
            int randomGeoApiUsernameIndex = randomGeoApiUser.nextInt(availableGeoApiUserNames.length);
            String geoApiUsername = availableGeoApiUserNames[randomGeoApiUsernameIndex];
            Log.d("Geo username", geoApiUsername);

            OkHttpClient client = new OkHttpClient();

            mFusedLocationClient.getLastLocation().addOnCompleteListener(
                new OnCompleteListener<Location>() {
                    @Override
                    public void onComplete(@NonNull Task<Location> task) {
                        Location location = task.getResult();
                        if (location != null) {
                            Log.d("CURRENT LAT", String.valueOf(location.getLatitude()));
                            Log.d("CURRENT LNG", String.valueOf(location.getLongitude()));

                            String url = "http://api.geonames.org/countryCodeJSON?lat=" + location.getLatitude() + "&lng="
                                    + location.getLongitude() + "&username=" + geoApiUsername;
                            Request request = new Request.Builder().url(url).build();
                            client.newCall(request).enqueue(new Callback() {
                                @Override
                                public void onFailure(Call call, IOException e) {
                                    e.printStackTrace();
                                }

                                @Override
                                public void onResponse(Call call, Response response) throws IOException {
                                    if (response.isSuccessful()) {
                                        try {
                                            final String countryResponse = response.body().string().toString();
                                            JSONObject countryAsJSON = new JSONObject(countryResponse);
                                            Log.d("Country", countryResponse);
                                            String countryName = countryAsJSON.getString("countryName");
                                            String countryCode = countryAsJSON.getString("countryCode");

                                            String lastDetectedCountryName = PreferenceManager
                                                    .getDefaultSharedPreferences(getApplicationContext())
                                                    .getString(LAST_DETECTED_COUNTRY_KEY, "NULL");

                                            if (countryName != null && !countryName.isEmpty() && !countryName.equals(lastDetectedCountryName)) {
                                                boolean contains = Arrays.asList(countryNames).contains(countryName);
                                                if (contains) {
                                                    PreferenceManager
                                                            .getDefaultSharedPreferences(getApplicationContext())
                                                            .edit()
                                                            .putString(LAST_DETECTED_COUNTRY_KEY, countryName).apply();
                                                    String flag = convertCountryCodeToFlag(countryCode);
                                                    PowerManager pm = (PowerManager) getApplicationContext().getSystemService(Context.POWER_SERVICE);
                                                    boolean isScreenOn = Build.VERSION.SDK_INT >= 20 ? pm.isInteractive() : pm.isScreenOn(); // check if
                                                    // screen
                                                    // is on
                                                    if (!isScreenOn) {
                                                        PowerManager.WakeLock wl = pm.newWakeLock(
                                                                PowerManager.SCREEN_DIM_WAKE_LOCK | PowerManager.ACQUIRE_CAUSES_WAKEUP,
                                                                "relocare:notificationLock");
                                                        wl.acquire(10000); // set your time in milliseconds
                                                    }
                                                    pushNotification("You are entering " + countryName + " " + flag,
                                                            "If this is a business trip, tap to confirm.");

                                                    MainActivity.getInstance().addGeofencesButtonHandler();
                                                }
                                                else {
                                                    String flag = convertCountryCodeToFlag(countryCode);
                                                    pushNotification("You are entering " + countryName + " " + flag,
                                                            "If this is a business trip, tap to confirm.");

                                                    MainActivity.getInstance().addGeofencesButtonHandler();
                                                }
                                            }
                                        } catch (Exception e) {
                                            e.printStackTrace();
                                        }
                                    }
                                }
                            });
                            Log.i(TAG, geofenceTransitionDetails);
                        }
                    }
                }
            );
        } else {
            // Log the error.
            Log.e(TAG, getString(R.string.geofence_transition_invalid_type, geofenceTransition));
        }
    }

    private String convertCountryCodeToFlag(final String countryCode) {
        int flagOffset = 0x1F1E6;
        int asciiOffset = 0x41;

        int firstChar = Character.codePointAt(countryCode, 0) - asciiOffset + flagOffset;
        int secondChar = Character.codePointAt(countryCode, 1) - asciiOffset + flagOffset;

        String flag = new String(Character.toChars(firstChar)) + new String(Character.toChars(secondChar));
        return flag;
    }

    /**
     * Gets transition details and returns them as a formatted string.
     *
     * @param geofenceTransition    The ID of the geofence transition.
     * @param triggeringGeofences   The geofence(s) triggered.
     * @return                      The transition details formatted as String.
     */
    private String getGeofenceTransitionDetails(
            int geofenceTransition,
            List<Geofence> triggeringGeofences) {

        String geofenceTransitionString = getTransitionString(geofenceTransition);

        // Get the Ids of each geofence that was triggered.
        ArrayList<String> triggeringGeofencesIdsList = new ArrayList<>();
        for (Geofence geofence : triggeringGeofences) {
            triggeringGeofencesIdsList.add(geofence.getRequestId());
        }
        String triggeringGeofencesIdsString = TextUtils.join(", ",  triggeringGeofencesIdsList);

        return geofenceTransitionString + ": " + triggeringGeofencesIdsString;
    }

    public void pushNotification(final String title, final String description) {

        NotificationChannel mChannel;
        NotificationManager mNotificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            mChannel = new NotificationChannel(CHANNEL_ID, "Social Security App",
                    NotificationManager.IMPORTANCE_HIGH);
            mChannel.setLightColor(0xD901518e);
            mChannel.enableLights(true);
            mChannel.setDescription("Description");
            AudioAttributes audioAttributes = new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build();
            if (mNotificationManager != null) {
                mNotificationManager.createNotificationChannel(mChannel);
            }
        }
        Context context = getApplicationContext();
        Intent notificationIntent = new Intent(context, MainActivity.class);
        notificationIntent.setAction(OpenAppFromLocalNotificationActionName);
        notificationIntent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent intent = PendingIntent.getActivity(context, 0, notificationIntent, 0);
        NotificationCompat.Builder mBuilder = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_launcher).setContentTitle(title).setContentText(description)
                .setContentIntent(intent).setColor(0xD901518e).setAutoCancel(true).setChannelId(CHANNEL_ID);
        mNotificationManager.cancel(9999);
        mNotificationManager.notify(9999, mBuilder.build());
    }

    /**
     * Posts a notification in the notification bar when a transition is detected.
     * If the user clicks the notification, control goes to the MainActivity.
     */
    private void sendNotification(String notificationDetails) {
        // Get an instance of the Notification manager
        NotificationManager mNotificationManager =
                (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

        // Android O requires a Notification Channel.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            CharSequence name = getString(R.string.app_name);
            // Create the channel for the notification
            NotificationChannel mChannel =
                    new NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_DEFAULT);

            // Set the Notification Channel for the Notification Manager.
            mNotificationManager.createNotificationChannel(mChannel);
        }

        // Create an explicit content Intent that starts the main Activity.
        Intent notificationIntent = new Intent(getApplicationContext(), MainActivity.class);

        // Construct a task stack.
        TaskStackBuilder stackBuilder = TaskStackBuilder.create(this);

        // Add the main Activity to the task stack as the parent.
        stackBuilder.addParentStack(MainActivity.class);

        // Push the content Intent onto the stack.
        stackBuilder.addNextIntent(notificationIntent);

        // Get a PendingIntent containing the entire back stack.
        PendingIntent notificationPendingIntent =
                stackBuilder.getPendingIntent(0, PendingIntent.FLAG_UPDATE_CURRENT);

        // Get a notification builder that's compatible with platform versions >= 4
        NotificationCompat.Builder builder = new NotificationCompat.Builder(this);

        // Define the notification settings.
        builder.setSmallIcon(R.drawable.ic_launcher)
                // In a real app, you may want to use a library like Volley
                // to decode the Bitmap.
                .setLargeIcon(BitmapFactory.decodeResource(getResources(),
                        R.drawable.ic_launcher))
                .setColor(Color.RED)
                .setContentTitle(notificationDetails)
                .setContentText(getString(R.string.geofence_transition_notification_text))
                .setContentIntent(notificationPendingIntent);

        // Set the Channel ID for Android O.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setChannelId(CHANNEL_ID); // Channel ID
        }

        // Dismiss notification once the user touches it.
        builder.setAutoCancel(true);

        // Issue the notification
        mNotificationManager.notify(9999, builder.build());
    }

    /**
     * Maps geofence transition types to their human-readable equivalents.
     *
     * @param transitionType    A transition type constant defined in Geofence
     * @return                  A String indicating the type of transition
     */
    private String getTransitionString(int transitionType) {
        switch (transitionType) {
            case Geofence.GEOFENCE_TRANSITION_ENTER:
                return getString(R.string.geofence_transition_entered);
            case Geofence.GEOFENCE_TRANSITION_EXIT:
                return getString(R.string.geofence_transition_exited);
            default:
                return getString(R.string.unknown_geofence_transition);
        }
    }
}
