package eye.phone;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    private static final String TAG = "MainActivity";

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        handleIntent();
        Log.i(TAG,"on create");
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIntent();
        Log.i(TAG, "o new intent");
    }

    private void handleIntent() {
        Intent appLinkIntent = getIntent();
        String appLinkAction = appLinkIntent.getAction();
        Uri appLinkData = appLinkIntent.getData();
        if (appLinkData != null) {
            String camId = appLinkData.getLastPathSegment();
            addCam(camId);
        }
    }


    private void addCam(String camId) {

    }
}
