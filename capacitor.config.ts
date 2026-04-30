import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.apnotes.ocr',
  appName: 'AP Notes Pro',
  webDir: 'dist',
  server: {
    androidScheme: 'https'
  }
};

export default config;
