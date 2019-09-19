package org.apache.cordova.firebase;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.NotificationCompat;
import android.util.Log;
import android.app.Notification;
import android.text.TextUtils;
import android.content.ContentResolver;
import android.graphics.Color;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.sql.Timestamp;
import java.util.Iterator;
import java.util.Map;
import java.util.Random;

public class FirebasePluginMessagingService extends FirebaseMessagingService {

    private static final String TAG = "FirebasePlugin";
    private SharedPreferences prefs;
    /**
     * Get a string from resources without importing the .R package
     *
     * @param name Resource Name
     * @return Resource
     */
    private String getStringResource(String name) {
        return this.getString(
                this.getResources().getIdentifier(
                        name, "string", this.getPackageName()
                )
        );
    }

    /**
     * Called when message is received.
     *
     * @param remoteMessage Object representing the message received from Firebase Cloud Messaging.
     */
    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        
        prefs = this.getApplicationContext().getSharedPreferences(Constants.SharedPrefs.Notifications,Context.MODE_PRIVATE);
        // [START_EXCLUDE]
        // There are two types of messages data messages and notification messages. Data messages are handled
        // here in onMessageReceived whether the app is in the foreground or background. Data messages are the type
        // traditionally used with GCM. Notification messages are only received here in onMessageReceived when the app
        // is in the foreground. When the app is in the background an automatically generated notification is displayed.
        // When the user taps on the notification they are returned to the app. Messages containing both notification
        // and data payloads are treated as notification messages. The Firebase console always sends notification
        // messages. For more see: https://firebase.google.com/docs/cloud-messaging/concept-options
        // [END_EXCLUDE]

        // Pass the message to the receiver manager so any registered receivers can decide to handle it
        boolean wasHandled = FirebasePluginMessageReceiverManager.onMessageReceived(remoteMessage);
        if (wasHandled) {
            Log.d(TAG, "Message was handled by a registered receiver");

            // Don't process the message in this method.
            return;
        }

        // TODO(developer): Handle FCM messages here.
        // Not getting messages here? See why this may be: https://goo.gl/39bRNJ
        String title = "";
        String text = "";
        String id = "";
        String sound = "";
        String lights = "";
        Map<String, String> dataMap = remoteMessage.getData();
        Log.d(TAG,dataMap.toString());
        try{
          JSONObject data = new JSONObject(dataMap.get("data"));
          Log.d(TAG,data.toString());
        if (remoteMessage.getNotification() != null) {
            title = remoteMessage.getNotification().getTitle();
            text = remoteMessage.getNotification().getBody();
            id = remoteMessage.getMessageId();
        } else if (data != null) {
            title = (data.has("title")) ? data.getString("title"): null;
            Log.d(TAG,title);
            text = (data.has("text")) ? data.getString("text") :  new String();
            id = (data.has("id")) ? data.getString("id") : null;
            sound = (data.has("sound")) ? data.getString("sound") : null;
            lights = (data.has("lights")) ? data.getString("lights") : null; //String containing hex ARGB color, miliseconds on, miliseconds off, example: '#FFFF00FF,1000,3000'
            if (TextUtils.isEmpty(text)) {
                text = (data.has("body")) ? data.getString("body") :null;
            }
            Log.d(TAG,text);
            //Save all mc...
            SharedPreferences.Editor editor = prefs.edit();
            String mcsJsonString = prefs.getString(Constants.SharedPrefs.MCS,null);
            JSONArray mcs = (mcsJsonString != null) ? new JSONArray(mcsJsonString): new JSONArray();
            if(data.has("payreq")){
              //Notificación del mensaje de cobro
              JSONObject mcPayReq = data.getJSONObject("payreq");
              JSONObject mc = (mcPayReq.has("infoCif")) ? mcPayReq.getJSONObject("infoCif")
                : null;
              boolean previusPayReqSaved = false;
              if(mc != null){
                for(int i = 0;i < mcs.length(); i++){
                  if(mcs.getJSONObject(i).getString("id").equals(mc.getString("id"))){
                    previusPayReqSaved = true;
                    break;
                  }
                }
              }

              if(!previusPayReqSaved){
                mc.put("isPayReq", true);
                mcs.put(mc);
                Log.d(TAG,mcs.toString());
                editor.putString(Constants.SharedPrefs.MCS,mcs.toString());
                editor.apply();
              }else{
                Log.d(TAG,"Previamente salvado: " + mcs.toString());
              }
            }else if(data.has("info")) {
              Log.d(TAG,"Actualización de status");
              //Estatus del mensaje de cobro
              JSONObject mcPayReq = data.getJSONObject("info");
              JSONObject mc = (mcPayReq.has("infoCif")) ? mcPayReq.getJSONObject("infoCif")
                : null;
              boolean previusPayReqSaved = false;
                if(mc != null){
                  for(int i = 0;i < mcs.length(); i++){
                    if(mcs.getJSONObject(i).getString("id").equals(mc.getString("id"))){
                      mc.put("isPayReq", false);
                      mcs.put(i, mc);
                      Log.d(TAG,"msg previous saved!");
                      Log.d(TAG, mcs.toString());
                      editor.putString(Constants.SharedPrefs.MCS,mcs.toString());
                      editor.apply();
                      previusPayReqSaved = true;
                      break;
                    }
                  }
                  if(!previusPayReqSaved){
                    mc.put("isPayReq", false);
                    mcs.put(mc);
                    Log.d(TAG,mcs.toString());
                    editor.putString(Constants.SharedPrefs.MCS,mcs.toString());
                    editor.apply();
                  }
                }
            }
          //Save all notifications...
          editor = prefs.edit();
          long currentTime =  System.currentTimeMillis();
          data.put("hnr",currentTime);
          String notificationsJsonString = prefs.getString(Constants.SharedPrefs.AllNotifications,null);
          JSONArray all_notifications = (notificationsJsonString != null) ? new JSONArray(notificationsJsonString): new JSONArray();
          all_notifications.put(data);
          Log.d(TAG,all_notifications.toString());
          editor.putString(Constants.SharedPrefs.AllNotifications,all_notifications.toString());
          editor.apply();
        }

        if (TextUtils.isEmpty(id)) {
            Random rand = new Random();
            int n = rand.nextInt(50) + 1;
            id = Integer.toString(n);
        }


        Log.d(TAG, "From: " + remoteMessage.getFrom());
        Log.d(TAG, "Notification Message id: " + id);
        Log.d(TAG, "Notification Message Title: " + title);
        Log.d(TAG, "Notification Message Body/Text: " + text);
        Log.d(TAG, "Notification Message Sound: " + sound);
        Log.d(TAG, "Notification Message Lights: " + lights);
        // TODO: Add option to developer to configure if show notification when app on foreground
        if (!TextUtils.isEmpty(text) || !TextUtils.isEmpty(title) || (data != null)) {
          Log.d(TAG,"eNTRO A ENVIAR NOTIFICACION");
            boolean showNotification = (FirebasePlugin.inBackground() || !FirebasePlugin.hasNotificationsCallback()) && (!TextUtils.isEmpty(text) || !TextUtils.isEmpty(title));
            sendNotification(id, title, text, data, showNotification, sound, lights);
        }
        }catch(JSONException e){

        }
    }

    private void sendNotification(String id, String title, String messageBody, JSONObject data, boolean showNotification, String sound, String lights) {
      Log.d(TAG,"ENTRO A ENVIAR NOTIFICACION" + data.toString());
        Bundle bundle = new Bundle();
        try {
          Iterator<String> keysIterator = data.keys();
          while (keysIterator.hasNext()) {
            String key = keysIterator.next();
            Log.d(TAG,"key" + key);
            String value = data.get(key).toString();
            Log.d(TAG,"value" + value);
            bundle.putString(key,value);
          }
        }catch (Exception ex){
            Log.d(TAG,ex.getMessage());
        }
      Log.d(TAG,"Envia? "+Boolean.toString(showNotification));
        if (showNotification) {
            Intent intent = new Intent(this, OnNotificationOpenReceiver.class);
            intent.putExtras(bundle);
            PendingIntent pendingIntent = PendingIntent.getBroadcast(this, id.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT);

            String channelId = this.getStringResource("default_notification_channel_id");
            String channelName = this.getStringResource("default_notification_channel_name");
            Uri defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);

            NotificationCompat.Builder notificationBuilder = new NotificationCompat.Builder(this, channelId);
            notificationBuilder
                    .setContentTitle(title)
                    .setContentText(messageBody)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setStyle(new NotificationCompat.BigTextStyle().bigText(messageBody))
                    .setAutoCancel(true)
                    .setSound(defaultSoundUri)
                    .setContentIntent(pendingIntent)
                    .setPriority(NotificationCompat.PRIORITY_MAX);

            int resID = getResources().getIdentifier("notification_icon", "drawable", getPackageName());
            if (resID != 0) {
                notificationBuilder.setSmallIcon(resID);
            } else {
                notificationBuilder.setSmallIcon(getApplicationInfo().icon);
            }

            if (sound != null) {
                Log.d(TAG, "sound before path is: " + sound);
                Uri soundPath = Uri.parse(ContentResolver.SCHEME_ANDROID_RESOURCE + "://" + getPackageName() + "/raw/" + sound);
                Log.d(TAG, "Parsed sound is: " + soundPath.toString());
                notificationBuilder.setSound(soundPath);
            } else {
                Log.d(TAG, "Sound was null ");
            }

            if (lights != null) {
                try {
                    String[] lightsComponents = lights.replaceAll("\\s", "").split(",");
                    if (lightsComponents.length == 3) {
                        int lightArgb = Color.parseColor(lightsComponents[0]);
                        int lightOnMs = Integer.parseInt(lightsComponents[1]);
                        int lightOffMs = Integer.parseInt(lightsComponents[2]);

                        notificationBuilder.setLights(lightArgb, lightOnMs, lightOffMs);
                    }
                } catch (Exception e) {
                }
            }

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                int accentID = getResources().getIdentifier("accent", "color", getPackageName());
                notificationBuilder.setColor(getResources().getColor(accentID, null));

            }

            Notification notification = notificationBuilder.build();
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                int iconID = android.R.id.icon;
                int notiID = getResources().getIdentifier("notification_big", "drawable", getPackageName());
                if (notification.contentView != null) {
                    notification.contentView.setImageViewResource(iconID, notiID);
                }
            }
            NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

            // Since android Oreo notification channel is needed.
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                NotificationChannel channel = new NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH);
                notificationManager.createNotificationChannel(channel);
            }

            notificationManager.notify(id.hashCode(), notification);
        } else {
            bundle.putBoolean("tap", false);
            bundle.putString("title", title);
            bundle.putString("body", messageBody);
            FirebasePlugin.sendNotification(bundle, this.getApplicationContext());
        }
    }
}
