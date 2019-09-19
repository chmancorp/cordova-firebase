package org.apache.cordova.firebase;


import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;
import android.util.Base64;
import android.util.Log;
import android.widget.Toast;

import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.iid.FirebaseInstanceId;
import com.google.firebase.messaging.FirebaseMessaging;

import org.apache.commons.codec.DecoderException;
import org.apache.commons.codec.binary.Hex;
import org.apache.commons.codec.digest.DigestUtils;
import org.apache.cordova.CallbackContext;

import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.security.InvalidAlgorithmParameterException;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.List;

import javax.crypto.BadPaddingException;
import javax.crypto.Cipher;
import javax.crypto.IllegalBlockSizeException;
import javax.crypto.NoSuchPaddingException;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;

import org.apache.cordova.firebase.FirebasePlugin;

public class FirebaseConfig {
    private String androidID = "764d2cb7da3280eb";//AndroidIDPrivada
    private String token = null;
    private FirebaseApp myApp;
    private int numIntent = 0;
    private Activity activity;
    FirebasePlugin FirebasePlugin;
    public FirebaseConfig(Activity activity, FirebasePlugin FirebasePlugin){
        this.FirebasePlugin = FirebasePlugin;
        this.activity = activity;
    }

    public void generateIdN(String gId){        
        configurarFirebaseAppPrivada();
        configurarFirebaseAppBanxico(gId);
    }

    public String getKeySource(String codR,String idH,String nc){
        String sha512Codr = new String(Hex.encodeHex(DigestUtils.sha512(codR)));
        String keySource = new String(Hex.encodeHex(DigestUtils.sha512(sha512Codr+ idH + nc )));
        return keySource;
    }

    public String decrypGId(String aesKey,String aesiv,String gId){
        String gIdHex = new String(Hex.encodeHex(Base64.decode(gId,Base64.DEFAULT)));
        try {
            IvParameterSpec iv = new IvParameterSpec(Hex.decodeHex(aesiv.toCharArray()));
            SecretKeySpec sKeySpec = new SecretKeySpec(Hex.decodeHex(aesKey.toCharArray()),"AES");
            Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5PADDING");
            cipher.init(Cipher.DECRYPT_MODE,sKeySpec,iv);
            byte[] original = cipher.doFinal(Hex.decodeHex(gIdHex.toCharArray()));
            String decryption = new String(original, "UTF-8");
            return decryption;
        } catch (NoSuchAlgorithmException e) {
            e.printStackTrace();
        } catch (NoSuchPaddingException e) {
            e.printStackTrace();
        } catch (DecoderException e) {
            e.printStackTrace();
        } catch (InvalidAlgorithmParameterException e) {
            e.printStackTrace();
        } catch (InvalidKeyException e) {
            e.printStackTrace();
        } catch (BadPaddingException e) {
            e.printStackTrace();
        } catch (IllegalBlockSizeException e) {
            e.printStackTrace();
        } catch (UnsupportedEncodingException e) {
            e.printStackTrace();
        }
        return new String();
    }
    public void generateSha512Hex(){

    }
    private void configurarFirebaseAppPrivada()
    {
        Log.d("Msj: ", "configurarFirebaseAppPrivada");
        try {
            String cGoogleID = "172567974334"; //IDProyectoPrivado
            setInitializeAppPrivada(cGoogleID, androidID);
            FirebasePlugin.cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    try {
                        String token = FirebaseInstanceId.getInstance().getToken(cGoogleID,
                                FirebaseMessaging.INSTANCE_ID_SCOPE);
                        Log.d("*TokenPrivada: " , token + " ");
                    } catch (Exception e) {
                        e.printStackTrace();
                    }

                }
            });
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void configurarFirebaseAppBanxico(String cGoogleID)
    {
        Log.d("Msj: ", "configurarFirebaseAppBanxico");
        try {
            //String cGoogleID = "201247069219"; //IDProyectoBanxico
            setInitializeAppBanxico(cGoogleID, androidID);
            FirebasePlugin.cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    try {
                        String token = FirebaseInstanceId.getInstance().getToken(cGoogleID,
                                FirebaseMessaging.INSTANCE_ID_SCOPE);
                        FirebasePlugin.returnToken(token);
                        Log.d("*TokenBanxico: " , token + " ");
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
            });
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void setInitializeAppPrivada(String cGoogleID, String androidID)
    {
        Log.d("Privada: ", "cGoogleID: " + cGoogleID + " androidID:" + androidID);
        FirebaseOptions.Builder builder = new FirebaseOptions.Builder()
                .setApplicationId("1:"+ cGoogleID +":android:" + androidID);
        List<FirebaseApp> firebaseApps = new ArrayList<FirebaseApp>(FirebaseApp.getApps(activity));
        for (FirebaseApp app: firebaseApps) {
            if (app.getName().equals("privada")){
               return;

            }
        }
        myApp = FirebaseApp.initializeApp(activity, builder.build(), "privada");
        Log.d("Msj: ", "configurado:" + myApp.getName());
    }

    private void setInitializeAppBanxico(String cGoogleID, String androidID)
    {
        Log.d("Banxico: ", "cGoogleID: " + cGoogleID + " androidID:" + androidID);
        FirebaseOptions.Builder builder = new FirebaseOptions.Builder()
                .setApplicationId("1:"+ cGoogleID +":android:" + androidID);
        List<FirebaseApp> firebaseApps = new ArrayList<FirebaseApp>(FirebaseApp.getApps(activity));
        for (FirebaseApp app: firebaseApps) {
            if (app.getName().equals("banxico")){
               return;

            }
        }
        myApp = FirebaseApp.initializeApp(activity, builder.build(), "banxico");
        Log.d("Msj: ", "configurado:" + myApp.getName());
    }

    private class TokenPrivada extends AsyncTask<String, Void, Void> {
        @Override
        protected Void doInBackground(String... params) {
            try {
                token = FirebaseInstanceId.getInstance().getToken(params[0],
                        FirebaseMessaging.INSTANCE_ID_SCOPE);
            } catch (IOException e) {
                e.printStackTrace();
            }
            Log.d("*TokenPrivada: " , token + " ");
            /*new Handler(Looper.getMainLooper()).post(new Runnable(){
                @Override
                public void run() {
                   // txtTokenPrivada.setText("Token privada:\n" + token);
                }
            });*/
            return null;
        }
    }
    private class TokenBanxico extends AsyncTask<String, Void, Void>{
        FirebasePlugin FirebasePlugin;
        public TokenBanxico(FirebasePlugin FirebasePlugin){
            this.FirebasePlugin = FirebasePlugin;
        }
        @Override
        protected Void doInBackground(String... params) {
            try {
                token = FirebaseInstanceId.getInstance().getToken(params[0],
                        FirebaseMessaging.INSTANCE_ID_SCOPE);
            } catch (IOException e) {
                e.printStackTrace();
            }
            FirebasePlugin.returnToken(token);
            Log.d("*TokenBanxico: " , token + " ");

            /*new Handler(Looper.getMainLooper()).post(new Runnable(){
                @Override
                public void run() {
                    //txtTokenBanxico.setText("Token Banxico:\n" + token);
                }
            });*/
            return null;
        }
    }

    private BroadcastReceiver mMessageReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            Toast.makeText(activity.getBaseContext(), "Recibi notificacion: " + ++numIntent ,
                    Toast.LENGTH_SHORT).show();
        }
    };
}
